function lstm_sol(block)
% Bloque de Simulink que le dice al EMS cuanto sol va a haber en las 24 horas
% siguientes. Lo que sale de la red no se entrega tal cual: primero se recorta
% para que nunca supere la irradiancia que habria con el cielo despejado, que es
% el techo fisico, y luego se mezcla con lo que daria suponer que el cielo sigue
% igual de limpio que las ultimas 24 horas, con mas peso a la red en las primeras
% horas. Necesita que init_OASIS.m haya dejado la serie de cielo claro en el
% workspace; si falta, avisa una vez y entrega la prediccion cruda.

setup(block);
end

function setup(block)
block.NumInputPorts  = 2;
block.NumOutputPorts = 1;

block.InputPort(1).Dimensions        = 8;
block.InputPort(1).DirectFeedthrough = true;
block.InputPort(2).Dimensions        = 1;
block.InputPort(2).DirectFeedthrough = true;

block.OutputPort(1).Dimensions = 24;
block.SampleTimes = [3600 0];

block.RegBlockMethod('InitializeConditions', @InitConditions);
block.RegBlockMethod('Outputs', @Outputs);
end

function InitConditions(block)
global lstm_net lstm_norm lstm_buffer lstm_ultima_hora lstm_cache
global lstm_clr_t lstm_clr_v lstm_w lstm_ktmax lstm_post_ok lstm_aviso_post
global lstm_oraculo lstm_or_t lstm_or_v

loaded       = load(fullfile(fileparts(mfilename('fullpath')), '..', 'codigo', 'modelos', 'lstm_solar_sevilla.mat'));
lstm_net     = loaded.lstm_net;
lstm_norm    = loaded.norm_params;
lstm_ultima_hora = -1;
lstm_cache       = zeros(24, 1, 'single');

% Precalentamiento del buffer con las 48 h previas al inicio
lstm_buffer = zeros(8, 48, 'single');
try
    ts_sim = evalin('base', 'features_solar');

    idx_pre  = ts_sim.Time < 0;
    data_pre = squeeze(ts_sim.Data(:, :, idx_pre));  % [8 x N_pre]
    n_pre    = size(data_pre, 2);

    if n_pre >= 48
        lstm_buffer = single(data_pre(:, end-47:end));
    elseif n_pre > 0
        lstm_buffer(:, end-n_pre+1:end) = single(data_pre);
        warning('[LSTM-SOL] Pre-buffer parcial: solo %d/48h', n_pre);
    else
        warning('[LSTM-SOL] Sin datos de pre-buffer.');
    end
catch ME
    warning('[LSTM-SOL] Error pre-buffer: %s', ME.message);
end

% Datos del posprocesado: envolvente de cielo claro y pesos de la mezcla
lstm_aviso_post = false;
lstm_post_ok    = false;
lstm_clr_t = [];
lstm_clr_v = [];
lstm_w     = ones(1, 24);
lstm_ktmax = 1.00;

% Modo oraculo: en vez de predecir, entrega la irradiancia real de las 24 h
% siguientes, lo que da el techo de lo que puede aportar cualquier prevision
lstm_oraculo = false; lstm_or_t = []; lstm_or_v = [];
try
    if evalin('base', 'exist(''ORACULO'', ''var'')') && evalin('base', 'ORACULO')
        ts_or = evalin('base', 'features_solar_ext');
        lstm_or_t = double(ts_or.Time(:));
        % la fila 1 es la irradiancia normalizada: al deshacerlo queda en la
        % misma escala que emite el bloque en modo normal
        d = squeeze(ts_or.Data(1, 1, :));
        lstm_or_v = double(d(:)) * double(lstm_norm.max_A - lstm_norm.min_A) + double(lstm_norm.min_A);
        lstm_oraculo = numel(lstm_or_t) > 24;
    end
catch ME
    warning('[LSTM-SOL] No se pudo activar el modo oraculo: %s', ME.message);
    lstm_oraculo = false;
end
if lstm_oraculo
    fprintf(['\n*** [LSTM-SOL] MODO ORACULO: se entrega la irradiancia real de las ' ...
        '24 h siguientes, no una prediccion. ***\n']);
    return
end

hay_clr = false;
try
    ts_clr     = evalin('base', 'clrsky_hour');
    lstm_clr_t = double(ts_clr.Time(:));
    lstm_clr_v = double(ts_clr.Data(:));
    hay_clr    = numel(lstm_clr_t) > 24;
catch
    hay_clr = false;
end

hay_w = isfield(loaded, 'w_combi_sol') && numel(loaded.w_combi_sol) == 24;
if hay_w
    lstm_w = double(loaded.w_combi_sol(:))';
end
if isfield(loaded, 'KT_MAX_COMBI')
    lstm_ktmax = double(loaded.KT_MAX_COMBI);
end

lstm_post_ok = hay_clr && hay_w;

if lstm_post_ok
    fprintf(['[LSTM-SOL] Posprocesado activo: envolvente de cielo claro ' ...
        '(k_max = %.2f) + combinacion con pesos de validacion.\n'], lstm_ktmax);
else
    motivo = '';
    if ~hay_clr, motivo = [motivo 'falta clrsky_hour en el workspace base (regenera datos_OASIS.mat con preparar_workspace_simulink.m); ']; end
    if ~hay_w,   motivo = [motivo 'el .mat del modelo no trae w_combi_sol (ejecuta Modelo_LSTM_NASA.m con SOLO_EVALUAR = true); ']; end
    warning(['[LSTM-SOL] Se emite la prediccion CRUDA de la red, sin proyeccion ' ...
        'ni combinacion: %s'], motivo);
end
end

function Outputs(block)
global lstm_net lstm_norm lstm_buffer lstm_ultima_hora lstm_cache
global lstm_clr_t lstm_clr_v lstm_w lstm_ktmax lstm_post_ok lstm_aviso_post
global lstm_oraculo lstm_or_t lstm_or_v

features_8  = single(block.InputPort(1).Data);
t           = double(block.InputPort(2).Data);

hora_actual = floor(t / 3600);

if lstm_oraculo
    if hora_actual ~= lstm_ultima_hora
        t_fut = (hora_actual + (1:24)) * 3600;
        y_or  = interp1(lstm_or_t, lstm_or_v, t_fut, 'linear', NaN);
        y_or(~isfinite(y_or)) = 0;          % fuera de datos: sin sol
        lstm_cache = single(max(0, y_or(:)));
        lstm_ultima_hora = hora_actual;
    end
    block.OutputPort(1).Data = double(lstm_cache);
    return
end

if hora_actual ~= lstm_ultima_hora
    % desplaza el buffer e inserta la muestra de esta hora
    lstm_buffer = [lstm_buffer(:, 2:end), features_8];

    % la red predice las 24 horas siguientes
    Y_norm = predict(lstm_net, {lstm_buffer});
    y_lstm = max(single(0), Y_norm * single(lstm_norm.max_A - lstm_norm.min_A) + single(lstm_norm.min_A));

    forma  = size(y_lstm);
    y_out  = double(y_lstm(:))';   % 1x24, h+1 .. h+24

    if lstm_post_ok
        y_out = posproceso(y_out, hora_actual);
    end

    lstm_cache = single(reshape(y_out, forma));
    lstm_ultima_hora = hora_actual;
end

block.OutputPort(1).Data = double(lstm_cache);
end

% =====================================================================
function y = posproceso(y_lstm, hora_actual)
% Recorta la prediccion al techo de cielo claro y la mezcla con la persistencia
% del indice de claridad de las ultimas 24 h
global lstm_norm lstm_buffer lstm_clr_t lstm_clr_v lstm_w lstm_ktmax lstm_aviso_post

y = y_lstm;

% irradiancia de cielo claro de las 24 horas que se predicen
t_fut   = (hora_actual + (1:24)) * 3600;
clr_fut = interp1(lstm_clr_t, lstm_clr_v, t_fut, 'linear', NaN);

% indice de claridad de las ultimas 24 h: lo que ha entrado frente al techo
a_n     = double(lstm_buffer(1, end-23:end));
allsky  = a_n * double(lstm_norm.max_A - lstm_norm.min_A) + double(lstm_norm.min_A);
t_pas   = (hora_actual - 23 : hora_actual) * 3600;
clr_pas = interp1(lstm_clr_t, lstm_clr_v, t_pas, 'linear', NaN);

kt = NaN;
if all(isfinite(clr_pas))
    kt = sum(allsky) / max(sum(clr_pas), 1e-9);
    kt = min(max(kt, 0), 1.2);
end

ok = isfinite(clr_fut) & isfinite(kt);
if ~any(ok)
    if ~lstm_aviso_post
        warning(['[LSTM-SOL] Sin CLRSKY para el horizonte en t = %g h; se emite la ' ...
            'prediccion cruda. Amplia el recorte de clrsky_hour en init_OASIS.m.'], hora_actual);
        lstm_aviso_post = true;
    end
    return
end

% 1) recorte al techo de cielo claro
kt_hat = min(max(y_lstm ./ max(clr_fut, 1e-9), 0), lstm_ktmax);
y_proj = kt_hat .* clr_fut;
y_proj(clr_fut <= 10) = 0;          % noche: la envolvente ya es cero

% 2) mezcla con la persistencia del indice de claridad
y_ccp  = kt * clr_fut;
y_comb = lstm_w .* y_proj + (1 - lstm_w) .* y_ccp;

y(ok) = max(0, y_comb(ok));         % los horizontes sin CLRSKY quedan crudos
end
