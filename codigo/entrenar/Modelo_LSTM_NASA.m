% Entrena la red que dice cuanta irradiancia va a haber en las 24 horas
% siguientes, usando solo la meteorologia horaria de la NASA en Sevilla. Parte el
% historico en tres tramos por orden cronologico para entrenar, ajustar y probar,
% entrena la red y luego la juzga frente a dos referencias sencillas: repetir lo
% de ayer, y suponer que el cielo sigue igual de limpio que las ultimas 24 horas.
% A partir de ahi recorta la prediccion al techo de cielo claro, decide cuantas
% horas del vector le conviene mirar al EMS y calcula los pesos con los que se
% mezclan red y referencia, que se guardan junto al modelo.
clc; clear;
ruta_base = fileparts(mfilename('fullpath'));
ruta_datos = fullfile(ruta_base, '..', 'data');
ruta_modelos = fullfile(ruta_base, '..', 'modelos');

% con true no entrena: carga la red guardada y solo rehace metricas y figuras,
% para no cambiar las cifras de la memoria con otra inicializacion aleatoria
SOLO_EVALUAR = true;

%% PASO 1: lectura del fichero de la NASA
fid = fopen(fullfile(ruta_datos, 'NASA', 'NASA_07_26.csv'), 'r');
n_header = 0;
while true
    linea = fgetl(fid);
    n_header = n_header + 1;
    if contains(linea, 'YEAR,MO,DY,HR')
        break
    end
end
fclose(fid);

nasa = readtable(fullfile(ruta_datos, 'NASA', 'NASA_07_26.csv'), ...
    'NumHeaderLines', n_header - 1);
nasa.Properties.VariableNames = ...
    {'YEAR','MO','DY','HR','RH2M','PS','ALLSKY','CLRSKY'};

fprintf('Filas cargadas: %d\n', height(nasa));


%% PASO 2: fechas y variables ciclicas de hora y dia del ano
dt       = datetime(nasa.YEAR, nasa.MO, nasa.DY, nasa.HR, 0, 0);
hora     = hour(dt);
dia_anno = day(dt, 'dayofyear');

hora_sin = sin(2*pi*hora/24);
hora_cos = cos(2*pi*hora/24);
dia_sin  = sin(2*pi*dia_anno/365);
dia_cos  = cos(2*pi*dia_anno/365);

fprintf('Años disponibles: %s\n', num2str(unique(year(dt))'));


%% PASO 3: indice de nubosidad
cloud_idx = zeros(height(nasa), 1);
idx_sol   = nasa.CLRSKY > 10;
cloud_idx(idx_sol) = 1 - (nasa.ALLSKY(idx_sol) ./ nasa.CLRSKY(idx_sol));
cloud_idx = max(0, min(1, cloud_idx));


%% PASO 4: limpieza de huecos y valores invalidos
idx_valido = nasa.RH2M   > -998 & ...
    nasa.PS     > -998 & ...
    nasa.ALLSKY > -998 & ...
    nasa.CLRSKY > -998 & ...
    ~isnan(nasa.ALLSKY);

ALLSKY    = nasa.ALLSKY(idx_valido);
CLRSKY    = nasa.CLRSKY(idx_valido);
RH2M      = nasa.RH2M(idx_valido);
PS        = nasa.PS(idx_valido);
CLD       = cloud_idx(idx_valido);
h_sin     = hora_sin(idx_valido);
h_cos     = hora_cos(idx_valido);
d_sin     = dia_sin(idx_valido);
d_cos     = dia_cos(idx_valido);

dt_valido = dt(idx_valido);   % fechas de las filas usadas (eje LST de NASA)

fprintf('Filas válidas: %d / %d\n', sum(idx_valido), height(nasa));


%% PASO 5: normalizacion de las entradas a [0, 1]
min_A = min(ALLSKY);  max_A = max(ALLSKY);
min_RH = min(RH2M);   max_RH = max(RH2M);
min_PS = min(PS);     max_PS = max(PS);

ALLSKY_n = (ALLSKY - min_A) / (max_A - min_A);
RH2M_n   = (RH2M   - min_RH) / (max_RH - min_RH);
PS_n     = (PS     - min_PS) / (max_PS - min_PS);

norm_params.min_A  = min_A;  norm_params.max_A  = max_A;
norm_params.min_RH = min_RH; norm_params.max_RH = max_RH;
norm_params.min_PS = min_PS; norm_params.max_PS = max_PS;

fprintf('ALLSKY rango: [0, %.1f] Wh/m²\n', max_A);


%% PASO 6: secuencias de entrada y objetivo de 24 horas
ventana  = 48;    % 48h de historia
horizon  = 24;    % predice 24h hacia adelante

features = [ALLSKY_n, RH2M_n, PS_n, CLD, h_sin, h_cos, d_sin, d_cos];
n_feat   = size(features, 2);

n_muestras = length(ALLSKY_n) - ventana - horizon + 1;
X = cell(n_muestras, 1);
Y = zeros(n_muestras, horizon);

for i = 1:n_muestras
    X{i} = features(i:i+ventana-1, :)';          % [8 x 48]
    Y(i, :) = ALLSKY_n(i+ventana : i+ventana+horizon-1);  % [1 x 24]
end

fprintf('Secuencias generadas: %d (ventana=%dh, horizonte=%dh)\n', ...
    n_muestras, ventana, horizon);


%% PASO 7: reparto cronologico en entrenamiento, validacion y test
n       = n_muestras;
n_train = floor(0.80 * n);
n_val   = floor(0.90 * n);

X_train = X(1:n_train);        Y_train = Y(1:n_train, :);
X_val   = X(n_train+1:n_val);  Y_val   = Y(n_train+1:n_val, :);
X_test  = X(n_val+1:end);      Y_test  = Y(n_val+1:end, :);

fprintf('Train: %d | Val: %d | Test: %d\n', ...
    n_train, n_val-n_train, n-n_val);

% fecha en que empieza el horizonte de cada muestra, para poder comprobar que
% 2025 cae dentro del conjunto de test
fechas_muestra = dt_valido((1:n_muestras) + ventana);
fprintf('Rango Train: %s -> %s\n', datestr(fechas_muestra(1)), datestr(fechas_muestra(n_train)));
fprintf('Rango Val  : %s -> %s\n', datestr(fechas_muestra(n_train+1)), datestr(fechas_muestra(n_val)));
fprintf('Rango Test : %s -> %s\n', datestr(fechas_muestra(n_val+1)), datestr(fechas_muestra(end)));
fechas_test_sol = fechas_muestra(n_val+1:end);
if year(fechas_test_sol(1)) > 2025 || year(fechas_test_sol(end)) < 2025
    warning(['[OASIS] 2025 NO esta dentro del conjunto de test de la LSTM solar: ' ...
        'las previsiones de la campana de simulacion no serian out-of-sample.']);
else
    fprintf('2025 esta dentro del conjunto de test: las previsiones de la campana son out-of-sample.\n');
end

% dias que luego se simulan
DIAS_CAMPANA = {'02-07-2025', '11-02-2025', '13-07-2025', '17-09-2025'};


%% PASO 8: arquitectura de la red
layers = [
    sequenceInputLayer(n_feat)

    lstmLayer(128, 'OutputMode', 'sequence')
    dropoutLayer(0.2)

    lstmLayer(64,  'OutputMode', 'last')
    dropoutLayer(0.2)

    fullyConnectedLayer(64)
    reluLayer
    fullyConnectedLayer(horizon)
    reluLayer
    regressionLayer
    ];

parallel.gpu.enableCUDAForwardCompatibility(true)

iter_por_epoca = ceil(n_train / 128);
fprintf('Iteraciones por época: %d\n', iter_por_epoca);

options = trainingOptions('adam', ...
    'MaxEpochs',              300,               ...
    'MiniBatchSize',          64,                ...
    'InitialLearnRate',       0.001,             ...
    'ExecutionEnvironment',   'gpu',             ...
    'LearnRateSchedule',      'piecewise',       ...
    'LearnRateDropFactor',     0.3,              ...
    'LearnRateDropPeriod',     80,               ...
    'GradientThreshold',       1,                ...
    'ValidationData',         {X_val, Y_val},    ...
    'ValidationFrequency',    iter_por_epoca,    ...
    'ValidationPatience',      20,               ...
    'Plots',                  'training-progress', ...
    'Verbose',                 false);


%% PASO 9: entrenamiento
if SOLO_EVALUAR
    ruta_net = fullfile(ruta_modelos, 'lstm_solar_sevilla.mat');
    if ~exist(ruta_net, 'file')
        error('SOLO_EVALUAR = true pero no existe %s.', ruta_net);
    end
    cargado = load(ruta_net);
    net = cargado.lstm_net;
    t_entreno = 0;
    fprintf('\nSOLO_EVALUAR: red cargada de %s (no se entrena).\n', ruta_net);
    % los parametros de normalizacion se recalculan aqui: si no coinciden con
    % los guardados, la red recibiria las entradas en otra escala
    if isfield(cargado, 'norm_params')
        np_guardado = cargado.norm_params;
        dif = max(abs([np_guardado.min_A - min_A, np_guardado.max_A - max_A]));
        if dif > 1e-6
            warning(['[LSTM-SOL] Los parametros de normalizacion recalculados no ' ...
                'coinciden con los guardados (dif. %.3g). Los datos de entrada han ' ...
                'cambiado desde el entrenamiento: las metricas no seran comparables.'], dif);
        else
            fprintf('Parametros de normalizacion coinciden con los del modelo guardado.\n');
        end
    end
else
    fprintf('\nEntrenando LSTM solar (predicción 24h) con NASA POWER...\n');
    tic
    net = trainNetwork(X_train, Y_train, layers, options);
    t_entreno = toc;
    fprintf('Tiempo de entrenamiento: %.1f minutos\n', t_entreno/60);
end


%% PASO 10: evaluacion
Y_pred_norm = predict(net, X_test);  % [n_test x 24]
Y_pred_real = Y_pred_norm * (max_A - min_A) + min_A;
Y_test_real = Y_test      * (max_A - min_A) + min_A;

% error sobre todos los horizontes juntos
RMSE_g  = sqrt(mean((Y_pred_real(:) - Y_test_real(:)).^2));
MAE_g   = mean(abs(Y_pred_real(:) - Y_test_real(:)));
R2_g    = 1 - sum((Y_test_real(:)-Y_pred_real(:)).^2) / ...
    sum((Y_test_real(:)-mean(Y_test_real(:))).^2);

fprintf('\n=== MÉTRICAS GLOBALES (24h) ===\n');
fprintf('RMSE: %.2f Wh/m²  MAE: %.2f Wh/m²  R²: %.4f\n', RMSE_g, MAE_g, R2_g);

% error por horizonte
horizontes = [1, 6, 12, 24];
fprintf('\n--- Métricas por horizonte ---\n');
fprintf('Horizonte | RMSE Wh/m² | MAE Wh/m² | R²\n');
fprintf('----------|------------|-----------|--------\n');
for hh = horizontes
    rmse_hh = sqrt(mean((Y_pred_real(:,hh) - Y_test_real(:,hh)).^2));
    mae_hh  = mean(abs(Y_pred_real(:,hh) - Y_test_real(:,hh)));
    r2_hh   = 1 - sum((Y_test_real(:,hh)-Y_pred_real(:,hh)).^2) / ...
        sum((Y_test_real(:,hh)-mean(Y_test_real(:,hh))).^2);
    fprintf('   h+%2d   |  %7.2f   |  %6.2f   | %.4f\n', hh, rmse_hh, mae_hh, r2_hh);
end


%% PASO 10b: comparacion con dos referencias, separando dia y noche
% las referencias son repetir lo de ayer y aplicar a la curva de cielo claro
% futura el indice de claridad de las ultimas 24 h
% las horas de noche se miden aparte: son la mitad del total y las acierta
% cualquiera, asi que incluirlas divide el error por dos

idx_test_glob = (n_val+1) : n_muestras;
nT = numel(idx_test_glob);
P_lag24 = zeros(nT, horizon);
P_ccp   = zeros(nT, horizon);
CLR_fut = zeros(nT, horizon);
for j = 1:nT
    i = idx_test_glob(j);
    ult_A = ALLSKY(i+ventana-24 : i+ventana-1);
    ult_C = CLRSKY(i+ventana-24 : i+ventana-1);
    P_lag24(j,:) = ult_A(:)';
    kt = sum(ult_A) / max(sum(ult_C), 1e-9);
    kt = min(max(kt, 0), 1.2);
    CLR_fut(j,:) = CLRSKY(i+ventana : i+ventana+horizon-1)';
    P_ccp(j,:)   = kt * CLR_fut(j,:);
end

es_dia = CLR_fut > 10;                       % mascara de horas con sol
pct_noche = 100 * (1 - mean(es_dia(:)));
irrad_media_dia = mean(Y_test_real(es_dia));

mae_ = @(P) mean(abs(P(:) - Y_test_real(:)));
mae_dia_ = @(P) mean(abs(P(es_dia) - Y_test_real(es_dia)));
r2_ = @(P) 1 - sum((P(:)-Y_test_real(:)).^2) / sum((Y_test_real(:)-mean(Y_test_real(:))).^2);

MAE_lstm_dia   = mae_dia_(Y_pred_real);
MAE_lag24      = mae_(P_lag24);      MAE_lag24_dia = mae_dia_(P_lag24);
MAE_ccp        = mae_(P_ccp);        MAE_ccp_dia   = mae_dia_(P_ccp);
R2_lag24       = r2_(P_lag24);       R2_ccp        = r2_(P_ccp);
R2_cicloDiario = r2_(0.72 * CLR_fut);   % ni siquiera mira el tiempo que hizo

skill_vs_lag24 = 100 * (MAE_lag24 - MAE_g) / MAE_lag24;
skill_vs_ccp   = 100 * (MAE_ccp   - MAE_g) / MAE_ccp;
nMAE_dia_lstm  = 100 * MAE_lstm_dia / irrad_media_dia;

% curva completa del error frente al horizonte
mae_by_horizon_lstm  = mean(abs(Y_pred_real - Y_test_real), 1);
mae_by_horizon_lag24 = mean(abs(P_lag24 - Y_test_real), 1);
mae_by_horizon_ccp   = mean(abs(P_ccp - Y_test_real), 1);

fprintf('\n=== LINEAS BASE (mismas muestras de test) ===\n');
fprintf('Horas de noche en el objetivo: %.1f %% | irradiancia media diurna: %.0f Wh/m2\n', ...
    pct_noche, irrad_media_dia);
fprintf('%-32s %10s %10s %9s\n', '', 'MAE glob', 'MAE dia', 'R2');
fprintf('%-32s %10.2f %10.2f %9.4f\n', 'LSTM', MAE_g, MAE_lstm_dia, R2_g);
fprintf('%-32s %10.2f %10.2f %9.4f\n', 'Naive persistencia lag-24', MAE_lag24, MAE_lag24_dia, R2_lag24);
fprintf('%-32s %10.2f %10.2f %9.4f\n', 'Naive cielo claro (kt de ayer)', MAE_ccp, MAE_ccp_dia, R2_ccp);
fprintf('%-32s %10s %10s %9.4f\n', 'Solo el ciclo dia/noche', '-', '-', R2_cicloDiario);
fprintf('Skill vs lag-24: %+.1f %% | vs cielo claro: %+.1f %%\n', skill_vs_lag24, skill_vs_ccp);
fprintf('nMAE diurno del LSTM: %.1f %% de la irradiancia media diurna\n', nMAE_dia_lstm);
if skill_vs_ccp < 0
    fprintf(2, ['>> El modelo NO bate a la persistencia de cielo claro en el agregado. ' ...
        'Mira el skill por horizonte antes de concluir: puede ganar en las primeras horas, ' ...
        'que son las que consume el EMS (N_PV_H = 3).\n']);
end
fprintf('%-4s %9s %9s %12s\n', 'h', 'LSTM', 'lag-24', 'cielo claro');
for hh = 1:horizon
    fprintf('h+%-2d %9.2f %9.2f %12.2f\n', hh, mae_by_horizon_lstm(hh), ...
        mae_by_horizon_lag24(hh), mae_by_horizon_ccp(hh));
end

%% PASO 10c: recorte de la prediccion al techo de cielo claro
% la red predice irradiancia bruta y nada le impide pasarse del techo fisico del
% dia; aqui se deduce el indice de claridad implicito, se acota y se reconstruye
% la prediccion, todo sin reentrenar. Necesita el paso 10b ejecutado antes.

% reconstruye lo que hace falta del paso anterior, por si esta celda se ejecuta
% suelta
if ~exist('CLR_fut', 'var') || ~exist('es_dia', 'var') || ~exist('mae_dia_', 'var')
    req   = {'ALLSKY','CLRSKY','ventana','horizon','n_val','n_muestras', ...
             'Y_test_real','Y_pred_real'};
    % exist() dentro de una funcion anonima no ve el workspace del script
    falta = {};
    for q = 1:numel(req)
        if ~exist(req{q}, 'var'), falta{end+1} = req{q}; end %#ok<SAGROW>
    end
    if ~isempty(falta)
        error(['[PASO 10c] Faltan variables de pasos anteriores: %s.\n' ...
               'Ejecuta el script entero (F5), o al menos hasta el PASO 10, ' ...
               'antes de lanzar esta seccion por separado.'], strjoin(falta, ', '));
    end
    fprintf('[PASO 10c] El PASO 10b no se habia ejecutado: reconstruyendo lineas base.\n');

    idx_test_glob = (n_val+1) : n_muestras;
    nT      = numel(idx_test_glob);
    P_lag24 = zeros(nT, horizon);
    P_ccp   = zeros(nT, horizon);
    CLR_fut = zeros(nT, horizon);
    for j = 1:nT
        i = idx_test_glob(j);
        ult_A = ALLSKY(i+ventana-24 : i+ventana-1);
        ult_C = CLRSKY(i+ventana-24 : i+ventana-1);
        P_lag24(j,:) = ult_A(:)';
        kt = min(max(sum(ult_A) / max(sum(ult_C), 1e-9), 0), 1.2);
        CLR_fut(j,:) = CLRSKY(i+ventana : i+ventana+horizon-1)';
        P_ccp(j,:)   = kt * CLR_fut(j,:);
    end

    es_dia          = CLR_fut > 10;
    pct_noche       = 100 * (1 - mean(es_dia(:)));
    irrad_media_dia = mean(Y_test_real(es_dia));

    mae_     = @(P) mean(abs(P(:) - Y_test_real(:)));
    mae_dia_ = @(P) mean(abs(P(es_dia) - Y_test_real(es_dia)));
    r2_      = @(P) 1 - sum((P(:)-Y_test_real(:)).^2) / ...
                        sum((Y_test_real(:)-mean(Y_test_real(:))).^2);

    if ~exist('MAE_g', 'var'),  MAE_g  = mae_(Y_pred_real); end
    if ~exist('R2_g', 'var'),   R2_g   = r2_(Y_pred_real);  end
    MAE_lstm_dia   = mae_dia_(Y_pred_real);
    MAE_lag24      = mae_(P_lag24);
    MAE_ccp        = mae_(P_ccp);
    skill_vs_lag24 = 100 * (MAE_lag24 - MAE_g) / MAE_lag24;
    skill_vs_ccp   = 100 * (MAE_ccp   - MAE_g) / MAE_ccp;
    nMAE_dia_lstm  = 100 * MAE_lstm_dia / irrad_media_dia;

    mae_by_horizon_lstm  = mean(abs(Y_pred_real - Y_test_real), 1);
    mae_by_horizon_lag24 = mean(abs(P_lag24     - Y_test_real), 1);
    mae_by_horizon_ccp   = mean(abs(P_ccp       - Y_test_real), 1);
end

KT_MAX_LISTA = [1.00 1.05 1.10 1.20];   % techo del indice de cielo claro a barrer
KT_MAX_REF   = 1.10;                    % el que se reporta en detalle
if ~any(abs(KT_MAX_LISTA - KT_MAX_REF) < 1e-9)
    KT_MAX_LISTA = sort([KT_MAX_LISTA, KT_MAX_REF]);
end

% cuanto se sale la red del techo de cielo claro
env_ref   = KT_MAX_REF * CLR_fut;
viola     = es_dia & (Y_pred_real > env_ref);
exceso    = Y_pred_real - env_ref;
pct_viola = 100 * sum(viola(:)) / max(sum(es_dia(:)), 1);

fprintf('\n=== PROYECCION SOBRE LA ENVOLVENTE DE CIELO CLARO ===\n');
fprintf('Predicciones diurnas por encima de %.2f x CLRSKY: %.2f %% ', KT_MAX_REF, pct_viola);
if any(viola(:))
    fprintf('(exceso medio %.1f Wh/m2, maximo %.1f)\n', ...
        mean(exceso(viola)), max(exceso(viola)));
else
    fprintf('(ninguna)\n');
end
fprintf('Predicciones negativas: %d (la reluLayer de salida deberia impedirlas)\n', ...
    sum(Y_pred_real(:) < 0));

% barrido del techo admisible; primero se reporta el efecto de poner a cero las
% horas de noche, para no atribuirselo al recorte
Y_noche0 = Y_pred_real;  Y_noche0(~es_dia) = 0;

fprintf('\n%-16s %10s %10s %9s %12s\n', '', 'MAE glob', 'MAE dia', 'R2', 'skill ccp');
fprintf('%-16s %10.2f %10.2f %9.4f %11.1f %%\n', 'sin proyectar', MAE_g, MAE_lstm_dia, R2_g, skill_vs_ccp);
fprintf('%-16s %10.2f %10.2f %9.4f %11.1f %%\n', 'solo noche a 0', mae_(Y_noche0), mae_dia_(Y_noche0), ...
    r2_(Y_noche0), 100 * (MAE_ccp - mae_(Y_noche0)) / MAE_ccp);

Y_proj_ref = [];
for kmax = KT_MAX_LISTA
    kt_hat = Y_pred_real ./ max(CLR_fut, 1e-9);
    kt_hat = min(max(kt_hat, 0), kmax);
    Y_proj = kt_hat .* CLR_fut;
    Y_proj(~es_dia) = 0;                     % de noche la respuesta es 0 y CLRSKY lo dice

    mae_p     = mae_(Y_proj);
    mae_p_dia = mae_dia_(Y_proj);
    r2_p      = r2_(Y_proj);
    skill_p   = 100 * (MAE_ccp - mae_p) / MAE_ccp;

    fprintf('%-16s %10.2f %10.2f %9.4f %11.1f %%\n', ...
        sprintf('+ envolvente %.2f', kmax), mae_p, mae_p_dia, r2_p, skill_p);
    if abs(kmax - KT_MAX_REF) < 1e-9
        Y_proj_ref = Y_proj;
        MAE_proj = mae_p; MAE_proj_dia = mae_p_dia;
        R2_proj  = r2_p;  skill_proj_ccp = skill_p;
    end
end

% efecto por horizonte y donde se cruzan las dos curvas
mae_by_horizon_proj = mean(abs(Y_proj_ref - Y_test_real), 1);

cruce = @(v) find(v > mae_by_horizon_ccp, 1, 'first');   % primer h en que pierde
h_cruce_antes   = cruce(mae_by_horizon_lstm);
h_cruce_despues = cruce(mae_by_horizon_proj);

fprintf('\n%-4s %10s %10s %12s %10s\n', 'h', 'LSTM', 'proyect.', 'cielo claro', 'mejora');
for hh = 1:horizon
    fprintf('h+%-2d %10.2f %10.2f %12.2f %9.1f %%\n', hh, ...
        mae_by_horizon_lstm(hh), mae_by_horizon_proj(hh), mae_by_horizon_ccp(hh), ...
        100 * (mae_by_horizon_lstm(hh) - mae_by_horizon_proj(hh)) / mae_by_horizon_lstm(hh));
end

% el tramo que de verdad consume el EMS
N_PV_H = 3;
sk_antes   = 100 * (mean(mae_by_horizon_ccp(1:N_PV_H)) - mean(mae_by_horizon_lstm(1:N_PV_H))) ...
    / mean(mae_by_horizon_ccp(1:N_PV_H));
sk_despues = 100 * (mean(mae_by_horizon_ccp(1:N_PV_H)) - mean(mae_by_horizon_proj(1:N_PV_H))) ...
    / mean(mae_by_horizon_ccp(1:N_PV_H));

fprintf('\n--- Lectura ---\n');
fprintf('Tramo que consume el EMS (h+1..h+%d): skill vs cielo claro %+.1f %% -> %+.1f %%\n', ...
    N_PV_H, sk_antes, sk_despues);
if isempty(h_cruce_antes)
    fprintf('Punto de cruce con la linea base: el LSTM no perdia en ningun horizonte.\n');
elseif isempty(h_cruce_despues)
    fprintf('Punto de cruce: h+%d -> ya no pierde en ningun horizonte.\n', h_cruce_antes);
else
    fprintf('Punto de cruce con la linea base: h+%d -> h+%d\n', h_cruce_antes, h_cruce_despues);
end

MAE_noche0_dia = mae_dia_(Y_noche0);
if MAE_proj_dia < MAE_noche0_dia * 0.98
    fprintf('>> El recorte mejora el error diurno un %.1f %%.\n', ...
        100 * (MAE_noche0_dia - MAE_proj_dia) / MAE_noche0_dia);
elseif MAE_proj_dia > MAE_noche0_dia * 1.02
    fprintf(['>> El recorte empeora el error diurno: revisa KT_MAX, un techo bajo se\n' ...
        '   come picos legitimos de irradiancia.\n']);
else
    fprintf(['>> El recorte no cambia el error: la red ya respeta la envolvente y lo que\n' ...
        '   falla a horizonte largo es la incertidumbre del tiempo.\n']);
end


%% PASO 10d: cuantas horas del vector debe mirar el EMS, decidido en validacion
% la decision se toma aqui y no en test, que queda solo para confirmarla

% reconstruye lo que hace falta, por si esta celda se ejecuta suelta
req   = {'net','X_val','Y_val','ALLSKY','CLRSKY','ventana','horizon', ...
         'n_train','n_val','max_A','min_A'};
falta = {};
for q = 1:numel(req)
    if ~exist(req{q}, 'var'), falta{end+1} = req{q}; end %#ok<SAGROW>
end
if ~isempty(falta)
    error(['[PASO 10d] Faltan variables de pasos anteriores: %s.\n' ...
           'Ejecuta el script entero (F5) antes de lanzar esta seccion suelta.'], ...
           strjoin(falta, ', '));
end

Y_val_pred_n = predict(net, X_val);
Y_val_pred   = Y_val_pred_n * (max_A - min_A) + min_A;
Y_val_real   = Y_val         * (max_A - min_A) + min_A;

% misma referencia que en test
idx_val_glob = (n_train+1) : n_val;
nV = numel(idx_val_glob);
P_ccp_val   = zeros(nV, horizon);
CLR_fut_val = zeros(nV, horizon);
for j = 1:nV
    i = idx_val_glob(j);
    ult_A = ALLSKY(i+ventana-24 : i+ventana-1);
    ult_C = CLRSKY(i+ventana-24 : i+ventana-1);
    kt = sum(ult_A) / max(sum(ult_C), 1e-9);
    kt = min(max(kt, 0), 1.2);
    CLR_fut_val(j,:) = CLRSKY(i+ventana : i+ventana+horizon-1)';
    P_ccp_val(j,:)   = kt * CLR_fut_val(j,:);
end

mae_h_lstm_val = mean(abs(Y_val_pred - Y_val_real), 1);
mae_h_ccp_val  = mean(abs(P_ccp_val  - Y_val_real), 1);

fprintf('\n=== ELECCION DE N_PV_H SOBRE VALIDACION ===\n');
fprintf('Muestras de validacion: %d\n', nV);
fprintf('%-6s %10s %12s %10s %14s\n', 'N', 'MAE LSTM', 'MAE c.claro', 'skill', 'decision');
mejor_skill = -Inf; N_PV_H_val = 1;
for N = 1:12
    m_l = mean(mae_h_lstm_val(1:N));
    m_c = mean(mae_h_ccp_val(1:N));
    sk  = 100 * (m_c - m_l) / m_c;
    if sk > mejor_skill, mejor_skill = sk; N_PV_H_val = N; end
    fprintf('%-6d %10.2f %12.2f %9.1f %%\n', N, m_l, m_c, sk);
end

fprintf('\n>> N_PV_H optimo sobre VALIDACION: %d (skill %+.1f %%)\n', N_PV_H_val, mejor_skill);
fprintf('   Confirmalo ahora en test y usa ese valor en los tres EMS.\n');
if exist('N_PV_H', 'var') && N_PV_H_val ~= N_PV_H
    fprintf(2, ['   OJO: no coincide con el N_PV_H = %d que usa el EMS. Si validacion\n' ...
        '   dice otra cosa que test, manda validacion.\n'], N_PV_H);
end

%% PASO 10e: mezcla de la red con la persistencia de cielo claro
% en vez de elegir una de las dos se mezclan hora a hora, con pesos ajustados
% sobre validacion; la red gana en las primeras horas y pierde en las ultimas

req = {'net','X_val','Y_val','ALLSKY','CLRSKY','ventana','horizon', ...
       'n_train','n_val','n_muestras','max_A','min_A','Y_test_real'};
falta = {};
for q = 1:numel(req)
    if ~exist(req{q}, 'var'), falta{end+1} = req{q}; end %#ok<SAGROW>
end
if ~isempty(falta)
    error('[PASO 10e] Faltan variables de pasos anteriores: %s.', strjoin(falta, ', '));
end

KT_MAX_COMBI = 1.00;   % el techo que gano el barrido del PASO 10c

% predicciones y referencia sobre validacion
if ~exist('Y_val_pred', 'var')
    Y_val_pred = predict(net, X_val) * (max_A - min_A) + min_A;
    Y_val_real = Y_val               * (max_A - min_A) + min_A;
end
if ~exist('CLR_fut_val', 'var') || ~exist('P_ccp_val', 'var')
    idx_val_glob = (n_train+1) : n_val;
    nV2 = numel(idx_val_glob);
    P_ccp_val   = zeros(nV2, horizon);
    CLR_fut_val = zeros(nV2, horizon);
    for j = 1:nV2
        i = idx_val_glob(j);
        ult_A = ALLSKY(i+ventana-24 : i+ventana-1);
        ult_C = CLRSKY(i+ventana-24 : i+ventana-1);
        kt = min(max(sum(ult_A) / max(sum(ult_C), 1e-9), 0), 1.2);
        CLR_fut_val(j,:) = CLRSKY(i+ventana : i+ventana+horizon-1)';
        P_ccp_val(j,:)   = kt * CLR_fut_val(j,:);
    end
end

% se recorta tambien la de validacion, para que las dos entren igual a la mezcla
kt_val = min(max(Y_val_pred ./ max(CLR_fut_val, 1e-9), 0), KT_MAX_COMBI);
Y_val_proj = kt_val .* CLR_fut_val;
Y_val_proj(CLR_fut_val <= 10) = 0;

% ajuste de los pesos por barrido sobre validacion
rejilla = 0:0.02:1;
w_combi_sol = ones(1, horizon);
for h = 1:horizon
    mejor = inf; w_h = 1;
    for w = rejilla
        e = mean(abs(w*Y_val_proj(:,h) + (1-w)*P_ccp_val(:,h) - Y_val_real(:,h)));
        if e < mejor, mejor = e; w_h = w; end
    end
    w_combi_sol(h) = w_h;
end

% aplicacion a test con esos pesos
kt_test = min(max(Y_pred_real ./ max(CLR_fut, 1e-9), 0), KT_MAX_COMBI);
Y_test_proj = kt_test .* CLR_fut;
Y_test_proj(~es_dia) = 0;

Y_combi = zeros(size(Y_pred_real));
for h = 1:horizon
    Y_combi(:,h) = w_combi_sol(h)*Y_test_proj(:,h) + (1-w_combi_sol(h))*P_ccp(:,h);
end

MAE_combi_sol      = mae_(Y_combi);
MAE_combi_sol_dia  = mae_dia_(Y_combi);
R2_combi_sol       = r2_(Y_combi);
skill_combi_sol    = 100 * (MAE_ccp - MAE_combi_sol) / MAE_ccp;
mae_by_horizon_combi_sol = mean(abs(Y_combi - Y_test_real), 1);
mae_by_horizon_proj_combi = mean(abs(Y_test_proj - Y_test_real), 1);  % misma KT_MAX que la combinacion

fprintf('\n=== COMBINACION LSTM + PERSISTENCIA DE CIELO CLARO ===\n');
fprintf('Pesos w(h) ajustados en validacion (1 = solo LSTM, 0 = solo cielo claro):\n  ');
fprintf('%5.2f', w_combi_sol); fprintf('\n');

fprintf('\n%-26s %10s %10s %9s %12s\n', '', 'MAE glob', 'MAE dia', 'R2', 'skill ccp');
fprintf('%-26s %10.2f %10.2f %9.4f %11.1f %%\n', 'LSTM sola', MAE_g, MAE_lstm_dia, R2_g, skill_vs_ccp);
if exist('MAE_proj', 'var')
    fprintf('%-26s %10.2f %10.2f %9.4f %11.1f %%\n', 'LSTM proyectada', MAE_proj, MAE_proj_dia, R2_proj, skill_proj_ccp);
end
fprintf('%-26s %10.2f %10.2f %9.4f %11.1f %%\n', 'Cielo claro (linea base)', MAE_ccp, mae_dia_(P_ccp), r2_(P_ccp), 0);
fprintf('%-26s %10.2f %10.2f %9.4f %11.1f %%\n', 'COMBINADA', MAE_combi_sol, MAE_combi_sol_dia, R2_combi_sol, skill_combi_sol);

fprintf(['\nLa mezcla parte de la senal ya recortada (k_max = %.2f), asi que la columna\n' ...
    'a comparar es "proyect." y no "LSTM".\n'], KT_MAX_COMBI);
fprintf('\n%-4s %9s %10s %12s %11s %8s\n', 'h', 'LSTM', 'proyect.', 'cielo claro', 'combinada', 'w(h)');
for hh = [1 2 3 4 6 12 18 24]
    fprintf('h+%-2d %9.2f %10.2f %12.2f %11.2f %8.2f\n', hh, mae_by_horizon_lstm(hh), ...
        mae_by_horizon_proj_combi(hh), mae_by_horizon_ccp(hh), ...
        mae_by_horizon_combi_sol(hh), w_combi_sol(hh));
end

peor_h = max(mae_by_horizon_combi_sol - min(mae_by_horizon_proj_combi, mae_by_horizon_ccp));
fprintf('\n--- Lectura ---\n');
fprintf('Skill de la combinada vs cielo claro: %+.1f %% (la LSTM sola: %+.1f %%)\n', ...
    skill_combi_sol, skill_vs_ccp);
fprintf('En el peor horizonte, la combinada queda %.2f Wh/m2 por encima de la mejor\n', peor_h);
fprintf('de las dos senales por separado (0 = nunca es peor que ambas).\n');
if skill_combi_sol > 0
    fprintf(['>> La senal combinada BATE a la linea base en el agregado de 24 h, cosa que\n' ...
        '   la LSTM sola no hace. Es la que deberia consumir el EMS, y habilita usar el\n' ...
        '   horizonte largo para decisiones que hoy no se toman.\n']);
else
    fprintf(['>> Ni siquiera combinada bate a la linea base en el agregado. Quedate con\n' ...
        '   N_PV_H corto y con la LSTM solo en las primeras horas.\n']);
end

%% PASO 11: graficas
% una semana de predicciones a una hora vista
figure('Position', [100 100 1200 400]);
dias = 7*24;
plot(1:dias, Y_test_real(1:dias, 1), 'b-',  'LineWidth', 1.5, ...
    'DisplayName', 'Real');
hold on
plot(1:dias, Y_pred_real(1:dias, 1), 'r--', 'LineWidth', 1.5, ...
    'DisplayName', 'Predicción LSTM (h+1)');
xlabel('Hora'); ylabel('Irradiancia ALLSKY [Wh/m²]');
title('Predicción LSTM vs Real — h+1 (una semana)');
legend('Location','best'); grid on;

% un dia completo, con todos los horizontes
figure('Position', [100 550 1200 500]);
hora_idx = 1:24;
plot(hora_idx, Y_test_real(1, :), 'b-o',  'LineWidth', 1.5, ...
    'DisplayName', 'Real');
hold on
plot(hora_idx, Y_pred_real(1, :), 'r--s', 'LineWidth', 1.5, ...
    'DisplayName', 'Predicción LSTM');
xlabel('Horizonte (h+)'); ylabel('ALLSKY [Wh/m²]');
title('Predicción 24h — Día de test');
legend('Location','best'); grid on;


%% PASO 11b: prediccion en los dias que se simulan luego
% se busca la muestra de test cuyo horizonte empieza a las 00:00 de ese dia
% ojo: aqui las 00:00 son hora solar, no hora local; los relojes se unen despues
% en preparar_workspace_simulink.m
mae_dias_campana = nan(1, numel(DIAS_CAMPANA));
fprintf('\n=== Prediccion de irradiancia en los dias de la campana ===\n');
figure('Name', 'Prediccion solar en los dias de la campana', 'Position', [100 100 900 800]);
for k = 1:numel(DIAS_CAMPANA)
    d0 = datetime(DIAS_CAMPANA{k}, 'InputFormat', 'dd-MM-yyyy');
    j = find(fechas_test_sol == d0, 1);
    if isempty(j)
        fprintf('  %s: no hay muestra de test que empiece a las 00:00\n', DIAS_CAMPANA{k});
        continue;
    end
    mae_dias_campana(k) = mean(abs(Y_pred_real(j,:) - Y_test_real(j,:)));
    mae_ccp_dia_k = mean(abs(P_ccp(j,:) - Y_test_real(j,:)));
    fprintf('  %s: MAE LSTM = %6.2f | cielo claro = %6.2f Wh/m2 | irradiancia del dia = %.0f\n', ...
        DIAS_CAMPANA{k}, mae_dias_campana(k), mae_ccp_dia_k, sum(Y_test_real(j,:)));

    subplot(numel(DIAS_CAMPANA), 1, k)
    plot(0:23, Y_test_real(j,:), 'b-o', 'LineWidth', 1.5, 'DisplayName', 'Real'); hold on
    plot(0:23, Y_pred_real(j,:), 'r--s', 'LineWidth', 1.5, 'DisplayName', 'LSTM');
    hold off; grid on; xlim([0 23]);
    ylabel('ALLSKY [Wh/m^2]');
    title(sprintf('%s - MAE %.1f Wh/m^2', DIAS_CAMPANA{k}, mae_dias_campana(k)));
    if k == 1, legend('Location','best'); end
    if k == numel(DIAS_CAMPANA), xlabel('Hora del dia'); end
end

%% PASO 12: guardado del modelo
if SOLO_EVALUAR
    fprintf('\nSOLO_EVALUAR: no se sobrescribe lstm_solar_sevilla.mat.\n');
else
    lstm_net = net;
    save(fullfile(ruta_modelos, 'lstm_solar_sevilla.mat'), 'lstm_net', 'norm_params');
    fprintf('\nModelo guardado: lstm_solar_sevilla.mat\n');
end

%% PASO 12a: pesos de la mezcla, guardados en el mismo .mat que la red
% asi el bloque de Simulink no los lleva escritos a mano; se anaden con append,
% de forma que esto no toca la red y funciona tambien sin reentrenar
ruta_mat_sol = fullfile(ruta_modelos, 'lstm_solar_sevilla.mat');
if exist('w_combi_sol', 'var') && exist('KT_MAX_COMBI', 'var') && exist(ruta_mat_sol, 'file')
    save(ruta_mat_sol, 'w_combi_sol', 'KT_MAX_COMBI', '-append');
    fprintf(['\nPesos de la combinacion anadidos a lstm_solar_sevilla.mat ' ...
        '(w_combi_sol, KT_MAX_COMBI = %.2f).\n'], KT_MAX_COMBI);
    fprintf('La S-Function lstm_sol.m los cargara automaticamente.\n');
else
    fprintf(['\nAVISO: no se han guardado los pesos de la combinacion ' ...
        '(falta w_combi_sol: ejecuta el PASO 10e).\n']);
end

%% PASO 12b: registro de metricas en CSV
sello = datestr(now, 'yyyymmdd_HHMMSS');
carpeta_res = fullfile(ruta_base, '..', 'resultados');
if ~exist(carpeta_res, 'dir'), mkdir(carpeta_res); end

metricas = struct();
metricas.sello        = sello;
metricas.ventana      = ventana;
metricas.horizon      = horizon;
metricas.n_feat       = n_feat;
metricas.n_train      = n_train;
metricas.n_val        = n_val - n_train;
metricas.n_test       = n_muestras - n_val;
metricas.rango_test   = {datestr(fechas_test_sol(1)), datestr(fechas_test_sol(end))};
metricas.RMSE_global  = RMSE_g;
metricas.MAE_global   = MAE_g;
metricas.R2_global    = R2_g;
metricas.MAE_dia            = MAE_lstm_dia;
metricas.nMAE_dia_pct       = nMAE_dia_lstm;
metricas.pct_noche          = pct_noche;
metricas.irrad_media_dia    = irrad_media_dia;
metricas.MAE_lag24          = MAE_lag24;
metricas.MAE_lag24_dia      = MAE_lag24_dia;
metricas.MAE_ccp            = MAE_ccp;
metricas.MAE_ccp_dia        = MAE_ccp_dia;
metricas.R2_lag24           = R2_lag24;
metricas.R2_ccp             = R2_ccp;
metricas.R2_cicloDiario     = R2_cicloDiario;
metricas.skill_vs_lag24_pct = skill_vs_lag24;
metricas.skill_vs_ccp_pct   = skill_vs_ccp;
metricas.mae_by_horizon_lstm  = mae_by_horizon_lstm;
metricas.mae_by_horizon_lag24 = mae_by_horizon_lag24;
metricas.mae_by_horizon_ccp   = mae_by_horizon_ccp;
metricas.mae_h1a3_lstm        = mean(mae_by_horizon_lstm(1:3));
metricas.mae_h1a3_ccp         = mean(mae_by_horizon_ccp(1:3));
metricas.skill_h1a3_vs_ccp_pct = 100 * (metricas.mae_h1a3_ccp - metricas.mae_h1a3_lstm) / metricas.mae_h1a3_ccp;
% resultados del recorte al techo de cielo claro, que si no se pierden al cerrar
if exist('MAE_proj', 'var')
    metricas.KT_MAX_REF          = KT_MAX_REF;
    metricas.pct_viola_envolvente = pct_viola;
    metricas.MAE_noche0_dia      = MAE_noche0_dia;
    metricas.MAE_proj            = MAE_proj;
    metricas.MAE_proj_dia        = MAE_proj_dia;
    metricas.R2_proj             = R2_proj;
    metricas.skill_proj_ccp_pct  = skill_proj_ccp;
    metricas.mae_by_horizon_proj = mae_by_horizon_proj;
    metricas.h_cruce_antes       = h_cruce_antes;
    metricas.h_cruce_despues     = h_cruce_despues;
    metricas.skill_h1a3_proj_pct = sk_despues;
    metricas.mejora_proj_dia_pct = 100 * (MAE_noche0_dia - MAE_proj_dia) / MAE_noche0_dia;
end
if exist('N_PV_H_val', 'var')
    metricas.N_PV_H_val          = N_PV_H_val;
    metricas.skill_N_PV_H_val    = mejor_skill;
end

if exist('MAE_combi_sol', 'var')
    metricas.MAE_combi          = MAE_combi_sol;
    metricas.MAE_combi_dia      = MAE_combi_sol_dia;
    metricas.R2_combi           = R2_combi_sol;
    metricas.skill_combi_ccp    = skill_combi_sol;
    metricas.w_combi_sol        = w_combi_sol;
    metricas.mae_by_horizon_combi = mae_by_horizon_combi_sol;
end

metricas.dias_campana = DIAS_CAMPANA;
metricas.mae_dias_campana = mae_dias_campana;
metricas.t_entreno_min = t_entreno/60;
metricas.solo_evaluar  = SOLO_EVALUAR;
for hh = [1 6 12 24]
    metricas.(sprintf('RMSE_h%d', hh)) = sqrt(mean((Y_pred_real(:,hh) - Y_test_real(:,hh)).^2));
    metricas.(sprintf('MAE_h%d', hh))  = mean(abs(Y_pred_real(:,hh) - Y_test_real(:,hh)));
end
save(fullfile(carpeta_res, sprintf('metricas_lstm_solar_%s.mat', sello)), 'metricas');

fila = table(string(sello), MAE_g, RMSE_g, R2_g, MAE_lstm_dia, nMAE_dia_lstm, ...
    metricas.MAE_h1, metricas.MAE_h24, ...
    MAE_lag24, MAE_ccp, skill_vs_lag24, skill_vs_ccp, ...
    metricas.mae_h1a3_lstm, metricas.skill_h1a3_vs_ccp_pct, ...
    mae_dias_campana(1), mae_dias_campana(2), mae_dias_campana(3), mae_dias_campana(4), ...
    'VariableNames', {'sello','MAE_global','RMSE_global','R2_global','MAE_dia','nMAE_dia_pct', ...
    'MAE_h1','MAE_h24','MAE_lag24','MAE_ccp','skill_vs_lag24_pct','skill_vs_ccp_pct', ...
    'MAE_h1a3','skill_h1a3_vs_ccp_pct', ...
    'MAE_02jul','MAE_11feb','MAE_13jul','MAE_17sep'});

% estas columnas van a NaN si esas secciones no se ejecutaron, para que el CSV
% mantenga siempre las mismas
c_MAE_proj_dia = NaN; c_mejora_proj = NaN; c_skill_h1a3_proj = NaN;
c_pct_viola = NaN; c_cruce_antes = NaN; c_cruce_despues = NaN; c_N_PV_H_val = NaN;

if exist('MAE_proj_dia', 'var') && exist('MAE_noche0_dia', 'var')
    c_MAE_proj_dia = MAE_proj_dia;
    c_mejora_proj  = 100 * (MAE_noche0_dia - MAE_proj_dia) / MAE_noche0_dia;
end
if exist('sk_despues', 'var'), c_skill_h1a3_proj = sk_despues; end
if exist('pct_viola',  'var'), c_pct_viola       = pct_viola;  end
if exist('h_cruce_antes', 'var') && ~isempty(h_cruce_antes)
    c_cruce_antes = h_cruce_antes(1);
end
if exist('h_cruce_despues', 'var') && ~isempty(h_cruce_despues)
    c_cruce_despues = h_cruce_despues(1);
end
if exist('N_PV_H_val', 'var'), c_N_PV_H_val = N_PV_H_val; end
c_MAE_combi = NaN; c_skill_combi = NaN;
if exist('MAE_combi_sol', 'var')
    c_MAE_combi   = MAE_combi_sol;
    c_skill_combi = skill_combi_sol;
end

fila.MAE_proj_dia        = c_MAE_proj_dia;
fila.mejora_proj_dia_pct = c_mejora_proj;
fila.skill_h1a3_proj_pct = c_skill_h1a3_proj;
fila.pct_viola_envol     = c_pct_viola;
fila.h_cruce_antes       = c_cruce_antes;
fila.h_cruce_despues     = c_cruce_despues;
fila.N_PV_H_val          = c_N_PV_H_val;
fila.MAE_combi           = c_MAE_combi;
fila.skill_combi_ccp_pct = c_skill_combi;

ruta_registro = fullfile(carpeta_res, 'registro_lstm_solar.csv');
anadir_al_registro(ruta_registro, fila);

%% PASO 12c: exportacion de las figuras a memoria/img
carpeta_img = fullfile(ruta_base, '..', '..', 'memoria', 'img');
if exist(carpeta_img, 'dir')
    figs = findobj('Type', 'figure');
    for i = 1:numel(figs)
        nom = matlab.lang.makeValidName(get(figs(i), 'Name'));
        if isempty(nom), nom = sprintf('fig%d', i); end
        ruta_png = fullfile(carpeta_img, sprintf('lstm_solar_%s.png', nom));
        try
            exportgraphics(figs(i), ruta_png, 'Resolution', 200);
        catch
            print(figs(i), ruta_png, '-dpng', '-r200');
        end
    end
    fprintf('Figuras exportadas a %s\n', carpeta_img);
end
fprintf('Features: ALLSKY, RH2M, PS, cloud_idx, hora_sin/cos, dia_sin/cos\n');
fprintf('Ventana: 48h | Horizonte: 24h | Slope: 34° | Sevilla\n');
