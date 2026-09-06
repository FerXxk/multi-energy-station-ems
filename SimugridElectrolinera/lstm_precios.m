function lstm_precios(block)
% Bloque de Simulink que le dice al EMS por donde va a ir el precio de la luz.
% Una vez por hora entrega los 24 precios de las 24 horas siguientes, mezclando
% lo que sale de la red con el precio que hubo el dia anterior a esa misma hora:
% para las primeras horas pesa mas la red y para las ultimas pesa mas el dia
% anterior, con unos pesos que salieron de la validacion. Se puede pedir que en
% vez de predecir entregue el precio real (ORACULO = true), util como cota
% superior, o que use los precios que OMIE ya ha publicado para las horas que
% toque (MERCADO_DIARIO = 1, o 2 para rellenar el resto con el dia anterior).

setup(block);
end

function setup(block)
block.NumInputPorts  = 4;
block.NumOutputPorts = 1;

% Puerto 1: 3 features meteorologicas: ALLSKY, T2M, WS50M
block.InputPort(1).Dimensions        = 3;
block.InputPort(1).DirectFeedthrough = true;

% Puerto 2: Tiempo de la simulacion en segundos
block.InputPort(2).Dimensions        = 1;
block.InputPort(2).DirectFeedthrough = true;

% Puerto 3: dia del ano (1-365)
block.InputPort(3).Dimensions        = 1;
block.InputPort(3).DirectFeedthrough = true;

% Puerto 4: dia de la semana (1=dom, 7=sab)
block.InputPort(4).Dimensions        = 1;
block.InputPort(4).DirectFeedthrough = true;

block.OutputPort(1).Dimensions = 24;
block.SampleTimes = [3600 0];

block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
end

function InitConditions(block)
global pr_net pr_norm pr_buffer_weather pr_buffer_precio pr_ultima_hora pr_cache pr_pred_24
global pr_real_t pr_real_v pr_aviso_realim
global pr_w pr_combi_ok pr_aviso_combi
global pr_oraculo pr_or_t pr_or_v
global pr_md_modo pr_md_t pr_md_v pr_md_aviso

loaded   = load(fullfile(fileparts(mfilename('fullpath')), '..', 'codigo', 'modelos', 'lstm_precio_luz.mat'));
pr_net   = loaded.net;
pr_norm  = loaded.norm_params;

pr_ultima_hora = -1;
pr_cache       = single(50.0);
pr_pred_24     = single(50.0) * ones(1, 24);

% buffers de 168 h: tres variables meteorologicas y el precio
pr_buffer_weather = zeros(3, 168, 'single');  % [ALLSKY, T2M, WS50M]
pr_buffer_precio  = zeros(1, 168, 'single');

try
    ts_weather = evalin('base', 'features_precio');
    idx_pre_w  = ts_weather.Time < 0;
    data_pre_w = squeeze(ts_weather.Data(:, :, idx_pre_w));  % [3 x N_pre]
    n_w = size(data_pre_w, 2);

    if n_w >= 168
        pr_buffer_weather = single(data_pre_w(:, end-167:end));
    elseif n_w > 0
        pr_buffer_weather(:, end-n_w+1:end) = single(data_pre_w);
    end

    ts_pr = evalin('base', 'precio_real_hour');
    idx_pre_pr  = ts_pr.Time < 0;
    precio_pre  = ts_pr.Data(idx_pre_pr);
    n_pr = length(precio_pre);

    if n_pr >= 168
        pr_buffer_precio = single(precio_pre(end-167:end)');
    elseif n_pr > 0
        pr_buffer_precio(end-n_pr+1:end) = single(precio_pre');
    end

    % historico completo, para poder realimentar el buffer con el precio real
    pr_real_t = double(ts_pr.Time(:));
    pr_real_v = double(ts_pr.Data(:));

catch ME
    warning('[LSTM-PRECIO] Error cargando pre-buffer: %s', ME.message);
    pr_real_t = [];
    pr_real_v = [];
end
pr_aviso_realim = false;

pr_md_modo = 0; pr_md_t = []; pr_md_v = []; pr_md_aviso = false;   % antes del return del oraculo

% Modo oraculo: en vez de predecir, entrega el precio real de las 24 h siguientes
pr_oraculo = false; pr_or_t = []; pr_or_v = [];
try
    if evalin('base', 'exist(''ORACULO'', ''var'')') && evalin('base', 'ORACULO')
        ts_or = evalin('base', 'precio_real_ext');
        pr_or_t = double(ts_or.Time(:));
        pr_or_v = double(ts_or.Data(:));
        pr_oraculo = numel(pr_or_t) > 24;
    end
catch ME
    warning('[LSTM-PRECIO] No se pudo activar el modo oraculo: %s', ME.message);
    pr_oraculo = false;
end
if pr_oraculo
    fprintf(['\n*** [LSTM-PRECIO] MODO ORACULO: se entrega el precio real de las ' ...
        '24 h siguientes, no una prediccion. ***\n']);
    return
end

% Modo mercado diario: OMIE publica el precio de manana hacia las 13:00,
% asi que esas horas se entregan tal cual, sin predecir
try
    if evalin('base', 'exist(''MERCADO_DIARIO'', ''var'')')
        pr_md_modo = double(evalin('base', 'MERCADO_DIARIO'));
    end
catch
    pr_md_modo = 0;
end
if pr_md_modo > 0
    try
        ts_md   = evalin('base', 'precio_real_ext');   % llega 24 h mas alla del fin
        pr_md_t = double(ts_md.Time(:));
        pr_md_v = double(ts_md.Data(:));
    catch
        pr_md_t = pr_real_t; pr_md_v = pr_real_v;      % respaldo: serie del dia
    end
    if numel(pr_md_t) < 24
        warning('[LSTM-PRECIO] MERCADO_DIARIO pedido pero no hay serie de precio real: se desactiva.');
        pr_md_modo = 0;
    else
        if pr_md_modo == 2
            cola = 'persistencia de 24 h (SIN red neuronal)';
        else
            cola = 'prediccion combinada LSTM + persistencia';
        end
        fprintf(['\n*** [LSTM-PRECIO] MODO MERCADO DIARIO %d ACTIVO: precios ya publicados ' ...
            '(resto del dia; desde las 13:00 tambien D+1) = REALES; cola = %s. ***\n'], ...
            pr_md_modo, cola);
    end
end

% Pesos de la mezcla entre la red y el precio del dia anterior
pr_aviso_combi = false;
pr_w           = ones(1, 24);

hay_real = ~isempty(pr_real_t) && numel(pr_real_t) > 24;
hay_w    = isfield(loaded, 'w_combi_precio') && numel(loaded.w_combi_precio) == 24;
if hay_w
    pr_w = double(loaded.w_combi_precio(:))';
end
pr_combi_ok = hay_real && hay_w;

if pr_combi_ok
    fprintf(['[LSTM-PRECIO] Posprocesado activo: combinacion con la persistencia ' ...
        'de 24 h, pesos de validacion (%.2f en h+1, %.2f en h+24).\n'], pr_w(1), pr_w(24));
else
    motivo = '';
    if ~hay_real, motivo = [motivo 'no hay serie precio_real_hour utilizable; ']; end
    if ~hay_w,    motivo = [motivo 'el .mat del modelo no trae w_combi_precio (ejecuta Modelo_LTSM_Precio_Luz.m con SOLO_EVALUAR = true); ']; end
    warning(['[LSTM-PRECIO] Se emite la prediccion CRUDA de la red, sin combinar: %s'], motivo);
end
end

function Outputs(block)
global pr_net pr_norm pr_buffer_weather pr_buffer_precio pr_ultima_hora pr_cache pr_pred_24
global pr_real_t pr_real_v pr_aviso_realim
global pr_w pr_combi_ok pr_aviso_combi
global pr_oraculo pr_or_t pr_or_v
global pr_md_modo

% true: el buffer se realimenta con el precio real, que en operacion se conoce
% false: se realimenta con la propia prediccion
PR_REALIMENTAR_CON_REAL = true;

weather     = single(block.InputPort(1).Data);  % [3 x 1]: ALLSKY, T2M, WS50M
t           = double(block.InputPort(2).Data);
dia_anno    = double(block.InputPort(3).Data);
dia_semana  = double(block.InputPort(4).Data);

hora_actual = floor(t / 3600);

if pr_oraculo
    if hora_actual ~= pr_ultima_hora
        t_fut = (hora_actual + (1:24)) * 3600;
        p_or  = interp1(pr_or_t, pr_or_v, t_fut, 'linear', NaN);
        ult   = pr_or_v(end);
        p_or(~isfinite(p_or)) = ult;        % fuera de datos: se mantiene el ultimo
        pr_pred_24 = single(max(-20, p_or));
        pr_cache   = pr_pred_24(1);
        pr_ultima_hora = hora_actual;
    end
    block.OutputPort(1).Data = double(pr_pred_24);
    return
end

if hora_actual ~= pr_ultima_hora

    pr_buffer_weather = [pr_buffer_weather(:, 2:end), weather];

    nuevo_precio = pr_cache;                      % por defecto, la prediccion
    if PR_REALIMENTAR_CON_REAL && ~isempty(pr_real_t)
        % precio real de la hora que acaba de empezar
        t_hora = hora_actual * 3600;
        [dt, k] = min(abs(pr_real_t - t_hora));
        if dt <= 1800                             % tolerancia de media hora
            nuevo_precio = single(pr_real_v(k));
        elseif ~pr_aviso_realim
            warning(['[LSTM-PRECIO] Sin precio real para t = %g s; se realimenta ' ...
                'la prediccion. Comprueba el recorte de precio_real en init_OASIS.m.'], t_hora);
            pr_aviso_realim = true;
        end
    end
    pr_buffer_precio = [pr_buffer_precio(2:end), nuevo_precio];

    % monta la matriz de 14 entradas x 168 horas que espera la red
    % F = [precio, ALLSKY, T2M, WS50M, hora_sin, hora_cos,
    %      dia_sin, dia_cos, mes_sin, mes_cos,
    %      precio_lag24, precio_lag168, fv_norm, fv_allsky]
    X_lstm = zeros(14, 168, 'single');

    % fv_norm para 2025 = 1.0 (normalizado entre 15 y 36 GW)
    fv_norm_v = single(1.0);

    for step = 1:168
        % Precio (normalizado)
        p_val = pr_buffer_precio(step);
        p_norm = (p_val - pr_norm.mu_F(1)) / pr_norm.sigma_F(1);

        % ALLSKY, T2M, WS50M del buffer meteorologico
        w_step = pr_buffer_weather(:, step);
        allsky_n = (w_step(1) - pr_norm.mu_F(2)) / pr_norm.sigma_F(2);
        t2m_n    = (w_step(2) - pr_norm.mu_F(3)) / pr_norm.sigma_F(3);
        ws50m_n  = (w_step(3) - pr_norm.mu_F(4)) / pr_norm.sigma_F(4);

        % Features temporales: hora del dia para este step del buffer
        hist_hour = hora_actual - 168 + step;
        h_dia = mod(hist_hour, 24);
        hora_sin_v = sin(2 * pi * h_dia / 24);
        hora_cos_v = cos(2 * pi * h_dia / 24);

        % Dia de la semana: retroceder (168-step) horas desde ahora
        dias_offset = floor((168 - step) / 24);
        dow = dia_semana - dias_offset;
        dow = mod(dow - 1, 7) + 1;  % mantner en 1..7
        dia_sin_v = sin(2 * pi * dow / 7);
        dia_cos_v = cos(2 * pi * dow / 7);

        % Mes: calcular desde dia_anno - offset dias
        dia_anno_hist = dia_anno - floor((168 - step) / 24);
        mes_hist = month(datetime(2025, 1, 1) + days(dia_anno_hist - 1));
        mes_sin_v = sin(2 * pi * mes_hist / 12);
        mes_cos_v = cos(2 * pi * mes_hist / 12);

        % Lags de precio
        idx_lag24  = max(1, step - 24);
        idx_lag168 = max(1, step - 168);
        lag24_n  = (pr_buffer_precio(idx_lag24)  - pr_norm.mu_F(11)) / pr_norm.sigma_F(11);
        lag168_n = (pr_buffer_precio(idx_lag168) - pr_norm.mu_F(12)) / pr_norm.sigma_F(12);

        % fv_allsky = ALLSKY * fv_norm
        fv_allsky_val = w_step(1) * fv_norm_v;
        fv_allsky_n = (fv_allsky_val - pr_norm.mu_F(14)) / pr_norm.sigma_F(14);

        X_lstm(:, step) = [
            p_norm; ...          % 1:  precio
            allsky_n; ...        % 2:  ALLSKY
            t2m_n; ...           % 3:  T2M
            ws50m_n; ...         % 4:  WS50M
            hora_sin_v; ...      % 5:  hora_sin
            hora_cos_v; ...      % 6:  hora_cos
            dia_sin_v; ...       % 7:  dia_sin
            dia_cos_v; ...       % 8:  dia_cos
            mes_sin_v; ...       % 9:  mes_sin
            mes_cos_v; ...       % 10: mes_cos
            lag24_n; ...         % 11: precio_lag24
            lag168_n; ...        % 12: precio_lag168
            fv_norm_v; ...       % 13: fv_norm
            fv_allsky_n ...      % 14: fv_allsky
        ];
    end

    X_lstm_cell = squeeze(num2cell(X_lstm, [1, 2]));
    Y_norm = predict(pr_net, X_lstm_cell)';

    % Prediccion directa de precio (no residual)
    Y_24 = single(Y_norm) * single(pr_norm.sigma_p) + single(pr_norm.mu_p);
    Y_24 = max(single(-20), Y_24);

    % se guarda la prediccion cruda, que es la escala con la que se entreno la red
    pr_cache = Y_24(1);

    Y_sal = Y_24;
    if pr_combi_ok
        Y_sal = combinar_con_naive(Y_24, hora_actual);
    end
    pr_pred_24 = Y_sal;

    % las horas ya publicadas por OMIE pasan a precio real
    if pr_md_modo > 0
        pr_pred_24 = aplicar_mercado_diario(pr_pred_24, hora_actual);
    end

    pr_ultima_hora = hora_actual;
end

block.OutputPort(1).Data = double(pr_pred_24);
end

% =====================================================================
function Y = combinar_con_naive(Y_24, hora_actual)
% Mezcla la prediccion de la red con el precio del dia anterior segun los pesos
% ajustados en validacion; la referencia se lee de la serie real, no del buffer
global pr_real_t pr_real_v pr_w pr_aviso_combi

Y = Y_24;

% predict() devuelve fila o columna segun la version: se trabaja en fila
forma = size(Y_24);
y_ini = double(Y_24(:))';                 % 1x24, h+1 .. h+24

% Objetivo del horizonte h: hora_actual + h. Persistencia: 24 h antes.
t_base = (hora_actual - 24 + (1:24)) * 3600;
p_base = interp1(pr_real_t, pr_real_v, t_base, 'linear', NaN);

ok = isfinite(p_base);
if ~any(ok)
    if ~pr_aviso_combi
        warning(['[LSTM-PRECIO] Sin precio real para la persistencia en t = %g h; ' ...
            'se emite la prediccion cruda.'], hora_actual);
        pr_aviso_combi = true;
    end
    return
end

y_comb     = pr_w .* y_ini + (1 - pr_w) .* p_base;
y_sal      = y_ini;                       % los horizontes sin base quedan crudos
y_sal(ok)  = max(-20, y_comb(ok));
Y          = single(reshape(y_sal, forma));
end

% =====================================================================
function Y = aplicar_mercado_diario(Y_24, hora_actual)
% Sustituye por el precio real las horas que OMIE ya ha publicado; con el modo 2
% el resto se rellena con el precio del dia anterior
global pr_md_modo pr_md_t pr_md_v pr_md_aviso pr_real_t pr_real_v

Y     = Y_24;
forma = size(Y_24);
y     = double(Y_24(:))';                 % 1x24

h_dia   = mod(hora_actual, 24);
dia_hoy = floor(hora_actual / 24);

for k = 1:24
    h_abs = hora_actual + k;
    d_k   = floor(h_abs / 24);
    publicado = (d_k == dia_hoy) || (h_dia >= 13 && d_k == dia_hoy + 1);
    if publicado
        p = interp1(pr_md_t, pr_md_v, h_abs * 3600, 'linear', NaN);
        if isfinite(p)
            y(k) = max(-20, p);
        elseif ~pr_md_aviso
            warning(['[LSTM-PRECIO] MERCADO_DIARIO: sin precio real publicado para ' ...
                't = %g h; se deja la prevision en ese horizonte.'], h_abs);
            pr_md_aviso = true;
        end
    elseif pr_md_modo == 2 && numel(pr_real_t) > 1
        p = interp1(pr_real_t, pr_real_v, (h_abs - 24) * 3600, 'linear', NaN);
        if isfinite(p), y(k) = max(-20, p); end
    end
end

Y = reshape(single(y), forma);
end
