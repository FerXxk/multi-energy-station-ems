% Entrena la red que predice el precio de la luz de las 24 horas siguientes a
% partir de los precios de la ultima semana, del calendario y de tres variables
% meteorologicas. Entrena con los anos 2021 a 2024 y deja 2025 entero como test,
% que es el ano que luego se simula, de modo que todas las previsiones de la
% campana son sobre datos que la red no ha visto. Ademas de las metricas
% habituales hace tres cosas que importan para el resto del trabajo: compara con
% repetir el precio de ayer, ajusta los pesos con los que se mezclan red y
% referencia hora a hora, y mide el error tal y como lo vera Simulink, donde la
% red se realimenta con sus propias predicciones y el error se acumula a lo largo
% del dia.

ruta_base = fileparts(mfilename('fullpath'));
ruta_datos = fullfile(ruta_base, '..', 'data');
ruta_entsoe = fullfile(ruta_datos, 'entsoe');
ruta_nasa   = fullfile(ruta_datos, 'NASA');
ruta_modelos = fullfile(ruta_base, '..', 'modelos');

% cuadra la hora de la NASA con la de los precios; tiene que coincidir con el
% mismo interruptor de preparar_workspace_simulink.m
CORREGIR_ZONA_HORARIA = true;

% dias que luego se simulan, todos dentro del conjunto de test
DIAS_CAMPANA = {'02-07-2025', '11-02-2025', '13-07-2025', '17-09-2025'};

% la validacion cruzada entrena cuatro redes mas y solo sirve para medir la
% variabilidad: a false mientras se itera, a true en la ejecucion definitiva
HACER_CV = true;

% reentrena con validacion incluida, ya justo las epocas que encontro la parada
% temprana; asi 2024, que es el ano mas parecido a 2025, entra en el entrenamiento
REFIT_CON_VAL = true;

% mueve la validacion a los ultimos meses de 2024 en vez del ano entero, para que
% la parada temprana se mida sobre el regimen de mercado actual
SPLIT_VAL_RECIENTE = false;

% mezcla la salida de la red con el precio del dia anterior, hora a hora, con
% pesos ajustados sobre validacion: la red gana al principio y pierde al final
COMBINAR_CON_NAIVE = true;

% con true no entrena ni sobrescribe el modelo: carga la red guardada y solo
% rehace metricas y figuras, para no invalidar las cifras de la memoria ni el
% modelo que usa la campana
SOLO_EVALUAR = true;
if SOLO_EVALUAR
    HACER_CV      = false;   % la CV reentrena 4 veces
    REFIT_CON_VAL = false;   % el refit tambien reentrena
end

%% 1. Precios horarios, del CSV unificado de ENTSO-E
T_price = readtable(fullfile(ruta_entsoe, 'datos_entsoe_unificado_2021_2025.csv'));
fechas_price = datetime(T_price.timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
precio = T_price.precio;

%% 2. Meteorologia de la NASA
% irradiancia, humedad y presion
opts1 = detectImportOptions(fullfile(ruta_nasa, 'NASA_07_26.csv'));
opts1.DataLines = [15 Inf];
T_nasa1 = readtable(fullfile(ruta_nasa, 'NASA_07_26.csv'), opts1);
T_nasa1.Properties.VariableNames = {'YEAR','MO','DY','HR','RH2M','PS','ALLSKY','CLRSKY'};

% temperatura y viento
opts2 = detectImportOptions(fullfile(ruta_nasa, 'NASA_07_25_WIND_TEMP.csv'));
opts2.DataLines = [13 Inf];
T_nasa2 = readtable(fullfile(ruta_nasa, 'NASA_07_25_WIND_TEMP.csv'), opts2);
T_nasa2.Properties.VariableNames = {'YEAR','MO','DY','HR','T2M','WS10M','WS50M'};

% fechas horarias de la NASA
fechas_nasa1 = datetime(T_nasa1.YEAR, T_nasa1.MO, T_nasa1.DY, T_nasa1.HR, 0, 0);
fechas_nasa2 = datetime(T_nasa2.YEAR, T_nasa2.MO, T_nasa2.DY, T_nasa2.HR, 0, 0);

if CORREGIR_ZONA_HORARIA
    z1 = datetime(fechas_nasa1, 'TimeZone', 'UTC');  z1.TimeZone = 'Europe/Madrid';
    z2 = datetime(fechas_nasa2, 'TimeZone', 'UTC');  z2.TimeZone = 'Europe/Madrid';
    fechas_nasa1 = fechas_nasa1 + tzoffset(z1);
    fechas_nasa2 = fechas_nasa2 + tzoffset(z2);
    fprintf('Correccion de zona horaria NASA -> Europe/Madrid APLICADA.\n');
end

% los -999 son huecos: se interpolan
T_nasa1.ALLSKY(T_nasa1.ALLSKY == -999) = NaN;
T_nasa1.CLRSKY(T_nasa1.CLRSKY == -999) = NaN;
T_nasa1.RH2M(T_nasa1.RH2M   == -999) = NaN;
T_nasa1.PS(T_nasa1.PS       == -999) = NaN;
T_nasa1.ALLSKY = fillmissing(T_nasa1.ALLSKY, 'linear');
T_nasa1.CLRSKY = fillmissing(T_nasa1.CLRSKY, 'linear');
T_nasa1.RH2M   = fillmissing(T_nasa1.RH2M,   'linear');
T_nasa1.PS     = fillmissing(T_nasa1.PS,      'linear');

T_nasa2.T2M(T_nasa2.T2M == -999) = NaN;
T_nasa2.WS10M(T_nasa2.WS10M == -999) = NaN;
T_nasa2.WS50M(T_nasa2.WS50M == -999) = NaN;
T_nasa2.T2M   = fillmissing(T_nasa2.T2M,   'linear');
T_nasa2.WS10M = fillmissing(T_nasa2.WS10M, 'linear');
T_nasa2.WS50M = fillmissing(T_nasa2.WS50M, 'linear');

%% 3. Cruce de las dos fuentes por hora
% horas que existen en las dos series
[~, idx_nasa1] = ismember(fechas_price, fechas_nasa1);
[~, idx_nasa2] = ismember(fechas_price, fechas_nasa2);
validos = (idx_nasa1 > 0) & (idx_nasa2 > 0);

% meteorologia ya alineada con el precio
ALLSKY = T_nasa1.ALLSKY(idx_nasa1(validos));
CLRSKY = T_nasa1.CLRSKY(idx_nasa1(validos));
RH2M   = T_nasa1.RH2M(idx_nasa1(validos));
PS     = T_nasa1.PS(idx_nasa1(validos));

T2M    = T_nasa2.T2M(idx_nasa2(validos));
WS10M  = T_nasa2.WS10M(idx_nasa2(validos));
WS50M  = T_nasa2.WS50M(idx_nasa2(validos));

precio = precio(validos);
fechas_validas = fechas_price(validos);

%% 4. Variables de calendario
% la hora, el dia de la semana y el mes explican buena parte del precio
n      = sum(validos);
horas  = mod((0:n-1)', 24);                    % 0..23
dias_semana = weekday(fechas_validas);         % 1 (domingo) a 7 (sábado)
meses  = month(fechas_validas);

hora_sin  = sin(2*pi*horas/24);               % codificación cíclica
hora_cos  = cos(2*pi*horas/24);
dia_sin   = sin(2*pi*dias_semana/7);
dia_cos   = cos(2*pi*dias_semana/7);
mes_sin   = sin(2*pi*meses/12);
mes_cos   = cos(2*pi*meses/12);

% precio de hace 24 y de hace 168 horas
precio_lag24  = [mean(precio)*ones(24,1);  precio(1:end-24)];
precio_lag48  = [mean(precio)*ones(48,1);  precio(1:end-48)];
precio_lag168 = [mean(precio)*ones(168,1); precio(1:end-168)];

precio_lag24(1:24)   = precio(1);
precio_lag48(1:48)   = precio(1);
precio_lag168(1:168) = precio(1);

fv_instalada = zeros(n, 1);
anos_vec = year(fechas_validas);
fv_instalada(anos_vec == 2021) = 15.0;
fv_instalada(anos_vec == 2022) = 18.5;
fv_instalada(anos_vec == 2023) = 23.0;
fv_instalada(anos_vec == 2024) = 30.0;
fv_instalada(anos_vec == 2025) = 36.0;
fv_norm    = (fv_instalada - 15) / (36 - 15);
fv_allsky  = ALLSKY .* fv_norm;

%% 5. Matriz con las catorce entradas
nFeatures = 14;
F = [precio, ALLSKY, T2M, WS50M, ...                        % 4 físicas
    hora_sin, hora_cos, dia_sin, dia_cos, mes_sin, mes_cos, ... % 6 temporales
    precio_lag24, precio_lag168, ...                         % 2 lags
    fv_norm, fv_allsky];                                    % 2 estructura mercado

%% 6. Normalizacion, cada entrada por separado
mu_F    = mean(F);
sigma_F = std(F);
FN      = (F - mu_F) ./ sigma_F;

% se guardan los del precio para poder deshacerla luego
mu_p    = mu_F(1);
sigma_p = sigma_F(1);

%% 7. Secuencias de una semana de historia y 24 horas de objetivo
lookback = 168;   % 7 días de historia
horizon  = 24;    % predice 24h

nSamples = n - lookback - horizon + 1;
X = zeros(nFeatures, lookback, nSamples);
Y = zeros(horizon,   nSamples);

for i = 1:nSamples
    X(:,:,i) = FN(i : i+lookback-1, :)';     % [features x timesteps]
    Y(:,i)   = FN(i+lookback : i+lookback+horizon-1, 1);  % solo precio
end

%% 8. Reparto por anos: entrenamiento hasta 2023, validacion 2024, test 2025
fechas_target = fechas_validas((1:nSamples) + lookback);
anos_target = year(fechas_target);

% los tres conjuntos no se solapan: si validacion cayera dentro de entrenamiento,
% la parada temprana vigilaria datos que la red ya se ha aprendido
if SPLIT_VAL_RECIENTE
    corte_val = datetime(2024,10,1);
    idxTrain = fechas_target >= datetime(2021,1,1) & fechas_target <  corte_val;
    idxVal   = fechas_target >= corte_val & fechas_target < datetime(2025,1,1);
    idxTest  = fechas_target >= datetime(2025,1,1);
else
    idxTrain = anos_target >= 2021 & anos_target < 2024;
    idxVal   = anos_target == 2024;
    idxTest  = anos_target >= 2025;
end
fprintf('Muestras totales: %d (Train: %d, Val: %d, Test: %d)\n', ...
    nSamples, sum(idxTrain), sum(idxVal), sum(idxTest));

% comprobacion de que los tres conjuntos son disjuntos
if any(idxTrain & idxVal) || any(idxTrain & idxTest) || any(idxVal & idxTest)
    error(['[LSTM-PRECIO] Los conjuntos train/val/test se solapan. ' ...
        'Con solape, el early stopping y la CV no significan nada.']);
end
fprintf('Split verificado disjunto:\n  train %s -> %s (%d)\n  val   %s -> %s (%d)\n  test  %s -> %s (%d)\n', ...
    datestr(min(fechas_target(idxTrain)),'dd-mmm-yyyy'), datestr(max(fechas_target(idxTrain)),'dd-mmm-yyyy'), sum(idxTrain), ...
    datestr(min(fechas_target(idxVal)),'dd-mmm-yyyy'),   datestr(max(fechas_target(idxVal)),'dd-mmm-yyyy'),   sum(idxVal), ...
    datestr(min(fechas_target(idxTest)),'dd-mmm-yyyy'),  datestr(max(fechas_target(idxTest)),'dd-mmm-yyyy'),  sum(idxTest));

XTrain = X(:,:, idxTrain);
YTrain = Y(:,   idxTrain);
XVal   = X(:,:, idxVal);
YVal   = Y(:,   idxVal);
XTest  = X(:,:, idxTest);
YTest  = Y(:,   idxTest);

% formato de celdas que espera la red
toCell = @(M) squeeze(num2cell(M, [1 2]));
XTrainC = toCell(XTrain);
XValC   = toCell(XVal);
XTestC  = toCell(XTest);

%% 9. Arquitectura de la red, deliberadamente pequena
layers = [
    sequenceInputLayer(nFeatures)
    lstmLayer(128, 'OutputMode', 'sequence')
    dropoutLayer(0.3)
    lstmLayer(64, 'OutputMode', 'last')
    dropoutLayer(0.3)
    fullyConnectedLayer(64)
    reluLayer()
    fullyConnectedLayer(horizon)
    regressionLayer()
    ];

%% 10. Entrenamiento

parallel.gpu.enableCUDAForwardCompatibility(true)

% iteraciones por epoca, para poder validar una vez por epoca
iter_por_epoca = max(1, floor(numel(XTrainC) / 64));

% se valida una vez por epoca y con paso de aprendizaje pequeno: con paso grande
% y validando mas a menudo, la primera mejora ruidosa se tomaba por el minimo y
% el entrenamiento se cortaba en la tercera epoca
args_train = {
    'MaxEpochs',            200, ...
    'MiniBatchSize',        64, ...
    'InitialLearnRate',     2e-4, ...
    'LearnRateSchedule',    'piecewise', ...
    'LearnRateDropFactor',  0.5, ...
    'LearnRateDropPeriod',  25, ...
    'ValidationData',       {XValC, YVal'}, ...
    'ValidationFrequency',  iter_por_epoca, ...
    'ValidationPatience',   15, ...
    'L2Regularization',     1e-4, ...
    'GradientThreshold',    1, ...
    'Shuffle',              'every-epoch', ...
    'Plots',                'training-progress', ...
    'ExecutionEnvironment', 'gpu', ...
    'Verbose',              false};

%% 10a. Parada opcional antes de entrenar
% definiendo PARAR_TRAS_PREP otro script puede reutilizar esta preparacion de
% datos sin duplicarla ni entrenar nada
if exist('PARAR_TRAS_PREP', 'var') && PARAR_TRAS_PREP
    fprintf(['\n[PREP] Parada solicitada tras la preparacion de datos. ' ...
        'Disponibles X/Y, los indices de split, XTrainC/XValC/XTestC, ' ...
        'layers y args_train.\n']);
    return
end

% se pide la red del mejor punto de validacion y no la de la ultima iteracion;
% la opcion no existe en versiones antiguas de MATLAB, de ahi el try/catch
try
    trainOpts = trainingOptions('adam', args_train{:}, ...
        'OutputNetwork', 'best-validation-loss');
    usa_best_net = true;
catch
    trainOpts = trainingOptions('adam', args_train{:});
    usa_best_net = false;
    warning(['[LSTM-PRECIO] Esta version de MATLAB no admite OutputNetwork: ' ...
        'se devuelve la red de la ultima iteracion, no la mejor en validacion.']);
end

if SOLO_EVALUAR
    ruta_net = fullfile(ruta_modelos, 'lstm_precio_luz.mat');
    if ~exist(ruta_net, 'file')
        error('SOLO_EVALUAR = true pero no existe %s.', ruta_net);
    end
    cargado = load(ruta_net);
    net = cargado.net;
    info_train = struct('TrainingLoss', NaN);
    fprintf('\nSOLO_EVALUAR: red cargada de %s (no se entrena).\n', ruta_net);
    % los parametros de normalizacion se recalculan aqui: si no coinciden con
    % los guardados, la red recibiria las entradas en otra escala
    if isfield(cargado, 'norm_params') && isfield(cargado.norm_params, 'mu_p')
        dif = max(abs([cargado.norm_params.mu_p - mu_p, ...
                       cargado.norm_params.sigma_p - sigma_p]));
        if dif > 1e-6
            warning(['[LSTM-PRECIO] Los parametros de normalizacion recalculados no ' ...
                'coinciden con los guardados (dif. %.3g): los datos de entrada han ' ...
                'cambiado desde el entrenamiento.'], dif);
        else
            fprintf('Parametros de normalizacion coinciden con los del modelo guardado.\n');
        end
    end
else
    [net, info_train] = trainNetwork(XTrainC, YTrain', layers, trainOpts);
end

% epocas realmente usadas, que son las que repetira el reentrenamiento
if SOLO_EVALUAR
    n_iter = NaN; epocas_usadas = NaN; epoca_mejor = NaN;
else
    n_iter = numel(info_train.TrainingLoss);
    epocas_usadas = ceil(n_iter / iter_por_epoca);
    epoca_mejor = epocas_usadas;
end
if ~SOLO_EVALUAR
    try
        if isfield(info_train, 'OutputNetworkIteration') && ~isempty(info_train.OutputNetworkIteration)
            epoca_mejor = max(1, ceil(info_train.OutputNetworkIteration / iter_por_epoca));
        end
    catch
    end
    fprintf('Entrenamiento: %d iteraciones = %d epocas de las 200 permitidas', n_iter, epocas_usadas);
    if epocas_usadas < 200
        fprintf(' (early stopping SI actuo)\n');
    else
        fprintf(' (llego al maximo: el early stopping NO actuo)\n');
    end
    fprintf('Mejor red en la epoca %d\n', epoca_mejor);
    if epoca_mejor <= 2
        fprintf(2, ['>> El mejor punto cae en la epoca %d: la red esta casi sin ' ...
            'entrenar. Revisa la tasa de aprendizaje y la cadencia de validacion.\n'], ...
            epoca_mejor);
    end
end

%% 10b. Reentrenamiento con validacion incluida, justo esas epocas
if REFIT_CON_VAL
    % se evalua antes la red de la primera etapa, para poder compararlas
    YPred_pre = predict(net, XTestC)' * sigma_p + mu_p;
    YPred_pre = max(YPred_pre, -20);

    fprintf('\n== Refit sobre 2021-2024 con %d epocas (sin early stopping) ==\n', epoca_mejor);
    idxRefit = idxTrain | idxVal;
    XRefitC  = toCell(X(:,:, idxRefit));
    YRefit   = Y(:, idxRefit);

    args_refit = args_train;
    % se quita la validacion y se fijan las epocas
    quitar = {'ValidationData','ValidationFrequency','ValidationPatience'};
    for q = 1:numel(quitar)
        k = find(strcmp(args_refit, quitar{q}), 1);
        if ~isempty(k), args_refit([k k+1]) = []; end
    end
    k = find(strcmp(args_refit, 'MaxEpochs'), 1);
    args_refit{k+1} = epoca_mejor;

    refitOpts = trainingOptions('adam', args_refit{:});
    net = trainNetwork(XRefitC, YRefit', layers, refitOpts);
    fprintf('Refit terminado: %d muestras de entrenamiento (antes %d)\n', ...
        sum(idxRefit), sum(idxTrain));
else
    YPred_pre = [];
end

%% 11. Evaluacion
fprintf('\n══ Evaluando en Test Set ══\n');
YPredN = predict(net, XTestC)';
YPred  = YPredN * sigma_p + mu_p;
YReal  = YTest' * sigma_p + mu_p;

% referencias sencillas contra las que comparar
Y_lag24 = YTest' * sigma_p + mu_p;  % naive lag-24 = precio real (no hay lag-24 en YTest)
MAE_naive24 = 0;  % placeholder — se calcula abajo con precio real
RMSE_naive24 = 0;

% las mismas, ya en euros por MWh
precio_lag24_test = zeros(horizon, sum(idxTest));
precio_real_test = zeros(horizon, sum(idxTest));
sample_idx_test = find(idxTest);
for j = 1:length(sample_idx_test)
    ii = sample_idx_test(j);
    if ii+lookback+horizon-1 <= n
        precio_real_test(:, j) = precio(ii+lookback:ii+lookback+horizon-1);
        precio_lag24_test(:, j) = precio_lag24(ii+lookback:ii+lookback+horizon-1);
    end
end
YReal = precio_real_test;
YPred = max(YPred, -20);

MAE_naive24 = mean(abs(precio_lag24_test(:) - YReal(:)), 'all');
RMSE_naive24 = sqrt(mean((precio_lag24_test(:) - YReal(:)).^2, 'all'));

% repetir el precio de hace una semana
precio_lag168_test = zeros(horizon, sum(idxTest));
for j = 1:length(sample_idx_test)
    ii = sample_idx_test(j);
    if ii+lookback+horizon-1 <= n
        precio_lag168_test(:, j) = precio_lag168(ii+lookback:ii+lookback+horizon-1);
    end
end
MAE_naive168 = mean(abs(precio_lag168_test(:) - YReal(:)), 'all');
RMSE_naive168 = sqrt(mean((precio_lag168_test(:) - YReal(:)).^2, 'all'));

%% 11b. Metricas sin recortar la prediccion
MAE = mean(abs(YPred(:) - YReal(:)), 'all');
RMSE = sqrt(mean((YPred(:) - YReal(:)).^2, 'all'));
sMAPE = mean(2*abs(YPred(:) - YReal(:)) ./ (abs(YPred(:)) + abs(YReal(:))), 'all') * 100;

mask_f = YReal > 5;
MAE_f = mean(abs(YPred(mask_f) - YReal(mask_f)), 'all');
RMSE_f = sqrt(mean((YPred(mask_f) - YReal(mask_f)).^2, 'all'));
sMAPE_f = mean(2*abs(YPred(mask_f) - YReal(mask_f)) ./ (abs(YPred(mask_f)) + abs(YReal(mask_f))), 'all') * 100;

%% 11c. Metricas recortando la prediccion al rango observado
YPred_c = max(YPred, -20);
MAE_c = mean(abs(YPred_c(:) - YReal(:)), 'all');
RMSE_c = sqrt(mean((YPred_c(:) - YReal(:)).^2, 'all'));
sMAPE_c = mean(2*abs(YPred_c(:) - YReal(:)) ./ (abs(YPred_c(:)) + abs(YReal(:))), 'all') * 100;

MAE_fc = mean(abs(YPred_c(mask_f) - YReal(mask_f)), 'all');
RMSE_fc = sqrt(mean((YPred_c(mask_f) - YReal(mask_f)).^2, 'all'));
sMAPE_fc = mean(2*abs(YPred_c(mask_f) - YReal(mask_f)) ./ (abs(YPred_c(mask_f)) + abs(YReal(mask_f))), 'all') * 100;

%% 11d. Error segun lo lejos que se mire
mae_by_horizon = zeros(1, horizon);
mae_n24_by_horizon = zeros(1, horizon);
mae_n168_by_horizon = zeros(1, horizon);
for h = 1:horizon
    mae_by_horizon(h) = mean(abs(YPred(h,:) - YReal(h,:)));
    mae_n24_by_horizon(h) = mean(abs(precio_lag24_test(h,:) - YReal(h,:)));
    mae_n168_by_horizon(h) = mean(abs(precio_lag168_test(h,:) - YReal(h,:)));
end

fprintf('\n══ Comparacion de modelos ══\n')
fprintf('  Naive lag-24:    MAE = %.3f  RMSE = %.3f\n', MAE_naive24, RMSE_naive24)
fprintf('  Naive lag-168:   MAE = %.3f  RMSE = %.3f\n', MAE_naive168, RMSE_naive168)
fprintf('  LSTM (sin clamp): MAE = %.3f  RMSE = %.3f  sMAPE = %.2f%%\n', MAE, RMSE, sMAPE)
fprintf('  LSTM (con clamp): MAE = %.3f  RMSE = %.3f  sMAPE = %.2f%%\n', MAE_c, RMSE_c, sMAPE_c)

fprintf('\n══ Test SIN clamp (diagnostico) ══\n')
fprintf('MAE = %.3f | RMSE = %.3f | sMAPE = %.2f%%\n', MAE, RMSE, sMAPE)
fprintf('\n══ Test CON clamp (desplegado) ══\n')
fprintf('MAE = %.3f | RMSE = %.3f | sMAPE = %.2f%%\n', MAE_c, RMSE_c, sMAPE_c)
fprintf('\n══ Filtrado (precio > 5) — CON clamp ══\n')
fprintf('MAE = %.3f | RMSE = %.3f | sMAPE = %.2f%%\n', MAE_fc, RMSE_fc, sMAPE_fc)

fprintf('\n══ Error por horizon ══\n')
fprintf('  h=01: %.3f | h=06: %.3f | h=12: %.3f | h=18: %.3f | h=24: %.3f\n', ...
    mae_by_horizon(1), mae_by_horizon(6), mae_by_horizon(12), ...
    mae_by_horizon(18), mae_by_horizon(24));
fprintf('  Ratio h24/h01: %.3f\n', mae_by_horizon(24)/mae_by_horizon(1));

%% 11e. Mezcla con el precio del dia anterior, con pesos ajustados en validacion
% la red gana en las primeras horas y pierde despues, asi que en vez de elegir
% una de las dos se mezclan hora a hora; los pesos nunca se ajustan sobre test
MAE_combi = NaN; skill_combi = NaN; w_combi = nan(1, horizon);
mae_by_horizon_combi = nan(1, horizon);

if COMBINAR_CON_NAIVE
    fprintf('\n== Combinacion LSTM + persistencia 24 h ==\n');

    % predicciones y referencias sobre validacion
    YPred_val = predict(net, XValC)';
    YPred_val = max(YPred_val * sigma_p + mu_p, -20);

    sample_idx_val = find(idxVal);
    nV = numel(sample_idx_val);
    YReal_val  = zeros(horizon, nV);
    Ynaive_val = zeros(horizon, nV);
    for j = 1:nV
        ii = sample_idx_val(j);
        if ii+lookback+horizon-1 <= n
            YReal_val(:, j)  = precio(ii+lookback : ii+lookback+horizon-1);
            Ynaive_val(:, j) = precio_lag24(ii+lookback : ii+lookback+horizon-1);
        end
    end

    % ajuste de los pesos por barrido, hora a hora
    rejilla = 0:0.02:1;
    for h = 1:horizon
        mejor = inf; w_h = 1;
        for w = rejilla
            e = mean(abs(w*YPred_val(h,:) + (1-w)*Ynaive_val(h,:) - YReal_val(h,:)));
            if e < mejor, mejor = e; w_h = w; end
        end
        w_combi(h) = w_h;
    end

    % aplicacion a test con esos pesos
    YComb = zeros(size(YPred_c));
    for h = 1:horizon
        YComb(h,:) = w_combi(h)*YPred_c(h,:) + (1-w_combi(h))*precio_lag24_test(h,:);
        mae_by_horizon_combi(h) = mean(abs(YComb(h,:) - YReal(h,:)));
    end
    MAE_combi   = mean(abs(YComb(:) - YReal(:)), 'all');
    RMSE_combi  = sqrt(mean((YComb(:) - YReal(:)).^2, 'all'));
    skill_combi = 100 * (MAE_naive24 - MAE_combi) / MAE_naive24;

    fprintf('  Pesos w(h) ajustados en validacion (1 = solo LSTM, 0 = solo ingenuo):\n');
    fprintf('   '); fprintf('%5.2f', w_combi); fprintf('\n');
    fprintf('  MAE test: LSTM %.3f | ingenuo %.3f | COMBINADA %.3f\n', ...
        MAE_c, MAE_naive24, MAE_combi);
    fprintf('  Skill de la combinacion vs ingenuo: %+.2f %%\n', skill_combi);
    fprintf('  Skill de la combinacion vs LSTM sola: %+.2f %%\n', ...
        100*(MAE_c - MAE_combi)/MAE_c);
    fprintf('  %-4s %8s %8s %10s\n', 'h', 'LSTM', 'ingenuo', 'combinada');
    for h = [1 2 3 6 12 24]
        fprintf('  h+%-2d %8.2f %8.2f %10.2f\n', h, mae_by_horizon(h), ...
            mae_n24_by_horizon(h), mae_by_horizon_combi(h));
    end
    if skill_combi > 0
        fprintf('  >> La senal combinada SI bate al ingenuo. Es la que deberia consumir el EMS.\n');
    end
end

%% 11f. Error tal y como se comporta de verdad dentro de Simulink
% las metricas anteriores dan a la red una ventana de precios reales, pero el
% bloque de Simulink no tiene ese dato y se realimenta con sus propias
% predicciones, asi que el error se acumula a lo largo del dia. Aqui se emula ese
% lazo fuera de Simulink para poder dar los dos errores por separado.

% avisa con nombres concretos si esta celda se ejecuta suelta y faltan variables
req   = {'FN','net','lookback','horizon','idxTest','fechas_target', ...
         'mu_p','sigma_p','MAE_naive24','MAE_naive168','MAE_c'};
falta = {};
for q = 1:numel(req)
    if ~exist(req{q}, 'var'), falta{end+1} = req{q}; end %#ok<SAGROW>
end
if ~isempty(falta)
    error(['[11f] Faltan variables de pasos anteriores: %s.\n' ...
           'Ejecuta el script entero (F5) antes de lanzar esta seccion suelta.'], ...
           strjoin(falta, ', '));
end

COL_PRECIO = 1; COL_LAG24 = 11; COL_LAG168 = 12;

% dias de test cuyo horizonte empieza a las 00:00, que es como arranca cada
% simulacion
h_target   = hour(fechas_target);
idx_dias   = find(idxTest(:)' & h_target(:)' == 0);

MAX_DIAS_LC = 120;                       % cota para que no tarde una eternidad
if numel(idx_dias) > MAX_DIAS_LC
    paso     = ceil(numel(idx_dias) / MAX_DIAS_LC);
    idx_dias = idx_dias(1:paso:end);
end
nD = numel(idx_dias);

Y_lc = zeros(nD, horizon);               % prediccion en lazo cerrado
Y_la = zeros(nD, horizon);               % prediccion en lazo abierto (referencia)
Y_rl = zeros(nD, horizon);               % precio real

fprintf('\n=== LAZO CERRADO: emulando la realimentacion de lstm_precios.m ===\n');
fprintf('Dias de test evaluados: %d (horizonte %d h)\n', nD, horizon);

for d = 1:nD
    i0 = idx_dias(d);

    % referencia: una sola pasada con la ventana de precios reales
    Wla = FN(i0 : i0+lookback-1, :)';
    yla = predict(net, {Wla});  yla = yla(:)';      % [1 x horizon], sea cual sea la orientacion
    Y_la(d,:) = max(yla * sigma_p + mu_p, -20);
    Y_rl(d,:) = FN(i0+lookback : i0+lookback+horizon-1, COL_PRECIO)' * sigma_p + mu_p;

    % ahora hora a hora, realimentando la red con su propia prediccion
    hist_n = FN(i0 : i0+lookback-1, COL_PRECIO);   % historico de precio normalizado
    for k = 1:horizon
        fila_ini = i0 + k - 1;
        W = FN(fila_ini : fila_ini+lookback-1, :)';   % exogenas y temporales reales

        % se rehace todo lo que depende del historico de precio
        W(COL_PRECIO, :) = hist_n';
        for t = 1:lookback
            j24  = t - 24;
            j168 = t - 168;
            if j24 > 0
                W(COL_LAG24, t) = hist_n(j24);
            end
            if j168 > 0
                W(COL_LAG168, t) = hist_n(j168);
            end
        end

        y = predict(net, {W});  y = y(:)';
        y1 = max(y(1) * sigma_p + mu_p, -20);        % mismo clamp que la S-Function
        Y_lc(d,k) = y1;

        hist_n = [hist_n(2:end); (y1 - mu_p) / sigma_p];   % se realimenta
    end
end

mae_lc = mean(abs(Y_lc - Y_rl), 'all');
mae_la = mean(abs(Y_la - Y_rl), 'all');
mae_lc_h = mean(abs(Y_lc - Y_rl), 1);
mae_la_h = mean(abs(Y_la - Y_rl), 1);

fprintf('\n%-26s %10s %10s\n', '', 'MAE', 'vs lazo abierto');
fprintf('%-26s %10.3f %10s\n', 'Lazo abierto (test)', mae_la, '--');
fprintf('%-26s %10.3f %9.1f %%\n', 'Lazo cerrado (Simulink)', mae_lc, ...
    100 * (mae_lc - mae_la) / mae_la);

fprintf('\n%-4s %10s %10s %12s\n', 'h', 'l. abierto', 'l. cerrado', 'degradacion');
for hh = [1 3 6 12 18 24]
    fprintf('h+%-2d %10.3f %10.3f %11.1f %%\n', hh, mae_la_h(hh), mae_lc_h(hh), ...
        100 * (mae_lc_h(hh) - mae_la_h(hh)) / mae_la_h(hh));
end

fprintf('\n--- Lectura ---\n');
if mae_lc > mae_la * 1.10
    fprintf(['>> Realimentar con la propia prediccion degrada el error un %.1f %%: al EMS\n' ...
        '   le llega una prevision peor de la que el modelo sabe dar.\n'], ...
        100 * (mae_lc - mae_la) / mae_la);
else
    fprintf('>> Realimentar apenas degrada el error (%.1f %%).\n', ...
        100 * (mae_lc - mae_la) / mae_la);
end
fprintf('MAE con precios reales %.2f | realimentando %.2f EUR/MWh\n', mae_la, mae_lc);

% mejora frente a las referencias, en el mismo formato que el modelo solar
skill_lstm_n24  = 100 * (MAE_naive24  - MAE_c) / MAE_naive24;
skill_lstm_n168 = 100 * (MAE_naive168 - MAE_c) / MAE_naive168;
fprintf('\n=== SKILL (formato de la tabla de la memoria) ===\n');
fprintf('%-24s %10s %12s\n', 'Modelo', 'MAE', 'skill');
fprintf('%-24s %10.3f %12s\n', 'Persistencia lag-24', MAE_naive24, '--');
fprintf('%-24s %10.3f %11.1f %%\n', 'Persistencia lag-168', MAE_naive168, ...
    100 * (MAE_naive24 - MAE_naive168) / MAE_naive24);
fprintf('%-24s %10.3f %11.1f %%\n', 'LSTM (lazo abierto)', MAE_c, skill_lstm_n24);
fprintf('%-24s %10.3f %11.1f %%\n', 'LSTM (lazo cerrado)', mae_lc, ...
    100 * (MAE_naive24 - mae_lc) / MAE_naive24);

%% 12. Diagnostico
fprintf('\n══ Diagnostico ══\n')
fprintf('Real — mean: %.1f, std: %.1f, min: %.1f, max: %.1f\n', mean(YReal,'all'), std(YReal,[],'all'), min(YReal,[],'all'), max(YReal,[],'all'))
fprintf('Pred — mean: %.1f, std: %.1f, min: %.1f, max: %.1f\n', mean(YPred,'all'), std(YPred,[],'all'), min(YPred,[],'all'), max(YPred,[],'all'))
fprintf('Ratio std(pred/real): %.3f\n', std(YPred,[],'all')/std(YReal,[],'all'))
fprintf('Clamped: %d de %d (< -20)\n', sum(YPred(:) < -20), numel(YPred))

%% 13. Importancia de cada entrada
fprintf('\n══ Feature Importance (permutacion) ══\n')
base_MAE = mean(abs(YPred(:) - YReal(:)), 'all');
feature_names = {'ALLSKY','T2M','WS50M','hora_sin','hora_cos','dia_sin','dia_cos','mes_sin','mes_cos','lag24','lag168','fv_norm','fv_allsky'};
n_perms = 5;
importancia = zeros(nFeatures-1, 1);

for f = 2:nFeatures
    imp_acum = 0;
    for rep = 1:n_perms
        XPerm = XTest;
        perm_idx = randperm(size(XTest, 3));
        XPerm(f,:,:) = XTest(f,:,perm_idx);
        XPerm_cell = squeeze(num2cell(XPerm, [1, 2]));
        YPermN = predict(net, XPerm_cell)';
        YPerm = YPermN * sigma_p + mu_p;
        YPerm = max(YPerm, -20);
        imp_acum = imp_acum + mean(abs(YPerm(:) - YReal(:)), 'all') - base_MAE;
    end
    importancia(f-1) = imp_acum / n_perms;
    fprintf('  %-12s: +%.3f EUR/MWh\n', feature_names{f-1}, importancia(f-1));
end

%% 14. Prediccion del dia siguiente
ultimasF = FN(end-lookback+1:end, :)';
ultimasF_cell = squeeze(num2cell(ultimasF, [1, 2]));
predN = predict(net, ultimasF_cell)';
predReal = predN * sigma_p + mu_p;

fprintf('\nPrediccion proximas 24h (EUR/MWh):\n')
for h = 1:24
    fprintf('H%02d: %.2f\n', h, predReal(h));
end

%% 15. Graficas
figure('Name','Modelo_LTSM_Precio_Luz — Prediccion vs Real')
subplot(2,1,1)
plot(1:24, YReal(:,1), 'b-o', 'DisplayName','Real')
hold on
plot(1:24, YPred(:,1), 'r--s', 'DisplayName','Prediccion')
xlabel('Hora'); ylabel('EUR/MWh')
title('Prediccion LSTM — Dia de test #1')
legend; grid on

subplot(2,1,2)
scatter(YReal(:), YPred(:), 5, 'filled')
hold on
plot([min(YReal(:)) max(YReal(:))], [min(YReal(:)) max(YReal(:))], 'r-')
xlabel('Real'); ylabel('Predicho')
title('Correlacion Real vs Predicho'); grid on

%% 15b. Error frente al horizonte
figure('Name','MAE por Horizon')
subplot(2,1,1)
plot(1:horizon, mae_by_horizon, 'r-o', 'LineWidth', 2, 'DisplayName', 'LSTM')
hold on
plot(1:horizon, mae_n24_by_horizon, 'b--^', 'LineWidth', 1.5, 'DisplayName', 'Naive lag-24')
plot(1:horizon, mae_n168_by_horizon, 'g:x', 'LineWidth', 1.5, 'DisplayName', 'Naive lag-168')
xlabel('Horizon'); ylabel('MAE (EUR/MWh)')
title('Error de PRECIO por horizon')
legend('Location','northwest'); grid on; xlim([1 horizon])

%% 15c. Ejemplo de tres dias
figure('Name','Ejemplo 3 dias')
dias_plot = [1, 50, 150];
for k = 1:length(dias_plot)
    d = dias_plot(k);
    if d > size(YPred, 2); continue; end
    subplot(length(dias_plot), 1, k)
    plot(1:24, YReal(:,d), 'k-o', 'LineWidth', 2, 'DisplayName', 'Real')
    hold on
    plot(1:24, YPred(:,d), 'r--s', 'LineWidth', 1.5, 'DisplayName', 'LSTM')
    plot(1:24, precio_lag24_test(:,d), 'b:x', 'LineWidth', 1, 'DisplayName', 'Naive')
    xlabel('Hora'); ylabel('EUR/MWh')
    title(sprintf('Dia #%d — MAE LSTM: %.1f, Naive: %.1f', ...
        d, mean(abs(YPred(:,d)-YReal(:,d))), mean(abs(precio_lag24_test(:,d)-YReal(:,d)))))
    legend('Location','best'); grid on
end

%% 15d. Prediccion en los dias que luego se simulan
% para cada dia se busca la muestra de test cuyo horizonte empieza a las 00:00,
% que es exactamente la prevision que veria el EMS ese dia
fechas_test = fechas_target(idxTest);
mae_dias_campana = nan(1, numel(DIAS_CAMPANA));
mae_dias_naive   = nan(1, numel(DIAS_CAMPANA));
col_dias_campana = nan(1, numel(DIAS_CAMPANA));

fprintf('\n== Prediccion en los dias de la campana ==\n');
figure('Name','Prediccion en los dias de la campana')
for k = 1:numel(DIAS_CAMPANA)
    d0 = datetime(DIAS_CAMPANA{k}, 'InputFormat', 'dd-MM-yyyy');
    j = find(fechas_test == d0, 1);
    if isempty(j)
        fprintf('  %s: no hay muestra de test que empiece a las 00:00\n', DIAS_CAMPANA{k});
        continue;
    end
    col_dias_campana(k) = j;
    mae_dias_campana(k) = mean(abs(YPred_c(:,j) - YReal(:,j)));
    mae_dias_naive(k)   = mean(abs(precio_lag24_test(:,j) - YReal(:,j)));
    fprintf('  %s: MAE LSTM = %6.2f | MAE naive-24 = %6.2f | mejora = %+5.1f %%\n', ...
        DIAS_CAMPANA{k}, mae_dias_campana(k), mae_dias_naive(k), ...
        100*(mae_dias_naive(k) - mae_dias_campana(k))/mae_dias_naive(k));

    subplot(numel(DIAS_CAMPANA), 1, k)
    plot(0:23, YReal(:,j), 'k-o', 'LineWidth', 2, 'DisplayName', 'Real'); hold on
    plot(0:23, YPred_c(:,j), 'r--s', 'LineWidth', 1.5, 'DisplayName', 'LSTM')
    plot(0:23, precio_lag24_test(:,j), 'b:x', 'LineWidth', 1, 'DisplayName', 'Naive lag-24')
    hold off; grid on; xlim([0 23]);
    ylabel('EUR/MWh')
    title(sprintf('%s - MAE LSTM %.1f vs naive %.1f EUR/MWh', ...
        DIAS_CAMPANA{k}, mae_dias_campana(k), mae_dias_naive(k)))
    if k == 1, legend('Location','best'); end
    if k == numel(DIAS_CAMPANA), xlabel('Hora del dia'); end
end

%% 16. Validacion cruzada por trimestres, avanzando en el tiempo
% cada trimestre se evalua entrenando solo con lo anterior, nunca con lo que vino
% despues, y se descartan las muestras justo previas porque comparten ventana
if ~HACER_CV
    fprintf('\n══ Walk-Forward Blocked CV: OMITIDA (HACER_CV = false) ══\n')
    cv_mae = nan(1, 4);
else
    fprintf('\n══ Walk-Forward Blocked CV (ventana expansiva + embargo) ══\n')
    nValSamples = sum(idxVal);
    nFolds = 4;
    foldSize = floor(nValSamples / nFolds);
    cv_mae = zeros(1, nFolds);
    EMBARGO = lookback + horizon;   % muestras descartadas antes del bloque de test

    for fold = 1:nFolds
        foldStart = 1 + (fold-1) * foldSize;
        foldEnd = min(fold * foldSize, nValSamples);

        idxFold = false(nSamples, 1);
        valPositions = find(idxVal);
        idxFold(valPositions(foldStart:foldEnd)) = true;

        % solo se entrena con lo anterior al bloque que se evalua
        idxAnteriores = false(nSamples, 1);
        if foldStart > 1
            idxAnteriores(valPositions(1:foldStart-1)) = true;
        end
        idxFoldTrain = idxTrain | idxAnteriores;

        % se descartan las muestras justo anteriores, que comparten ventana
        primera_test = valPositions(foldStart);
        ini_embargo = max(1, primera_test - EMBARGO);
        idxFoldTrain(ini_embargo:primera_test-1) = false;

        XFoldTrain = X(:,:,idxFoldTrain);
        YFoldTrain = Y(:,idxFoldTrain);
        XFoldTest = X(:,:,idxFold);
        YFoldTest = Y(:,idxFold);

        XFoldTrain_cell = squeeze(num2cell(XFoldTrain, [1, 2]));
        XFoldTest_cell = squeeze(num2cell(XFoldTest, [1, 2]));

        % se entrena igual que el modelo desplegado, o el error no seria comparable
        cvOptions = trainingOptions('adam', ...
            'MaxEpochs', max(5, epoca_mejor), ...
            'MiniBatchSize', 64, ...
            'InitialLearnRate', 2e-4, ...
            'GradientThreshold', 1, ...
            'L2Regularization', 1e-4, ...
            'Shuffle', 'every-epoch', ...
            'Verbose', false);

        [netFold, ~] = trainNetwork(XFoldTrain_cell, YFoldTrain', layers, cvOptions);

        YPredFold = predict(netFold, XFoldTest_cell)';
        YPredFold = YPredFold * sigma_p + mu_p;

        sample_idx_f = find(idxFold);
        Y_real_f = zeros(horizon, length(sample_idx_f));
        for j = 1:length(sample_idx_f)
            ii = sample_idx_f(j);
            if ii+lookback+horizon-1 <= n
                Y_real_f(:, j) = precio(ii+lookback:ii+lookback+horizon-1);
            end
        end
        YPredFold = max(YPredFold, -20);

        cv_mae(fold) = mean(abs(YPredFold(:) - Y_real_f(:)), 'all');
        fprintf('  Fold %d: entrena %d, evalua %d muestras, MAE = %.3f\n', ...
            fold, sum(idxFoldTrain), foldEnd-foldStart+1, cv_mae(fold));
    end
    fprintf('  MAE CV: %.3f +/- %.3f\n', mean(cv_mae), std(cv_mae));
end   % HACER_CV

%% 17. Guardado del modelo
norm_params.mu_F    = mu_F;
norm_params.sigma_F = sigma_F;
norm_params.mu_p    = mu_p;
norm_params.sigma_p = sigma_p;

if SOLO_EVALUAR
    fprintf('\nSOLO_EVALUAR: no se sobrescribe lstm_precio_luz.mat.\n')
else
    save(fullfile(ruta_modelos, 'lstm_precio_luz.mat'), 'net', 'norm_params');
    fprintf('\nModelo guardado — listo para Simulink\n')
end

%% 16b. Pesos de la mezcla, guardados en el mismo .mat que la red
% se anaden sin tocar la red, asi que funciona tambien sin reentrenar
ruta_mat_pr = fullfile(ruta_modelos, 'lstm_precio_luz.mat');
if exist('w_combi', 'var') && all(isfinite(w_combi)) && exist(ruta_mat_pr, 'file')
    w_combi_precio = w_combi;   %#ok<NASGU>  nombre explicito dentro del .mat
    save(ruta_mat_pr, 'w_combi_precio', '-append');
    fprintf(['\nPesos de la combinacion anadidos a lstm_precio_luz.mat ' ...
        '(w_combi_precio).\n']);
    fprintf('La S-Function lstm_precios.m los cargara automaticamente.\n');
else
    fprintf(['\nAVISO: no se han guardado los pesos de la combinacion ' ...
        '(falta w_combi: pon COMBINAR_CON_NAIVE = true y ejecuta la seccion 11e).\n']);
end

%% 17b. Registro de las metricas en un CSV acumulativo
% asi se pueden comparar dos entrenamientos sin copiar texto a mano
sello = datestr(now, 'yyyymmdd_HHMMSS');
carpeta_res = fullfile(ruta_base, '..', 'resultados');
if ~exist(carpeta_res, 'dir'), mkdir(carpeta_res); end

metricas = struct();
metricas.sello                 = sello;
metricas.corregir_zona_horaria = CORREGIR_ZONA_HORARIA;
metricas.lookback              = lookback;
metricas.horizon               = horizon;
metricas.nFeatures             = nFeatures;
metricas.n_train               = sum(idxTrain);
metricas.n_val                 = sum(idxVal);
metricas.n_test                = sum(idxTest);
metricas.split = sprintf('train %s..%s / val %s..%s / test %s..%s', ...
    datestr(min(fechas_target(idxTrain)),'dd-mmm-yyyy'), datestr(max(fechas_target(idxTrain)),'dd-mmm-yyyy'), ...
    datestr(min(fechas_target(idxVal)),'dd-mmm-yyyy'),   datestr(max(fechas_target(idxVal)),'dd-mmm-yyyy'), ...
    datestr(min(fechas_target(idxTest)),'dd-mmm-yyyy'),  datestr(max(fechas_target(idxTest)),'dd-mmm-yyyy'));
metricas.val_disjunto_de_train = ~any(idxTrain & idxVal);
metricas.cv_hecha              = HACER_CV;
metricas.cv_walkforward        = true;
metricas.epocas_usadas         = epocas_usadas;
metricas.epoca_mejor           = epoca_mejor;
metricas.usa_best_net          = usa_best_net;
metricas.refit_con_val         = REFIT_CON_VAL;
metricas.iter_por_epoca        = iter_por_epoca;
metricas.split_val_reciente    = SPLIT_VAL_RECIENTE;
metricas.combinar_con_naive    = COMBINAR_CON_NAIVE;
metricas.MAE_combi             = MAE_combi;
metricas.skill_combi_pct       = skill_combi;
metricas.w_combi               = w_combi;
metricas.mae_by_horizon_combi  = mae_by_horizon_combi;
if REFIT_CON_VAL && ~isempty(YPred_pre)
    metricas.MAE_sin_refit = mean(abs(YPred_pre(:) - YReal(:)), 'all');
    fprintf('MAE en test: %.3f solo con 2021-2023 -> %.3f tras el refit con 2024\n', ...
        metricas.MAE_sin_refit, MAE_c);
else
    metricas.MAE_sin_refit = NaN;
end
metricas.MAE                   = MAE;
metricas.RMSE                  = RMSE;
metricas.sMAPE                 = sMAPE;
metricas.MAE_clamp             = MAE_c;
metricas.RMSE_clamp            = RMSE_c;
metricas.sMAPE_clamp           = sMAPE_c;
metricas.MAE_naive24           = MAE_naive24;
metricas.RMSE_naive24          = RMSE_naive24;
metricas.MAE_naive168          = MAE_naive168;
metricas.skill_vs_naive24_pct  = 100*(MAE_naive24 - MAE_c)/MAE_naive24;
metricas.mae_by_horizon        = mae_by_horizon;
metricas.mae_n24_by_horizon    = mae_n24_by_horizon;
metricas.ratio_h24_h01         = mae_by_horizon(24)/mae_by_horizon(1);
metricas.ratio_std_pred_real   = std(YPred,[],'all')/std(YReal,[],'all');
metricas.n_clamped             = sum(YPred(:) < -20);
metricas.feature_names         = feature_names;
metricas.importancia           = importancia;
metricas.cv_mae                = cv_mae;
metricas.cv_mae_media          = mean(cv_mae);
metricas.dias_campana          = DIAS_CAMPANA;
metricas.mae_dias_campana      = mae_dias_campana;
metricas.mae_dias_naive        = mae_dias_naive;

save(fullfile(carpeta_res, sprintf('metricas_lstm_precio_%s.mat', sello)), 'metricas');

% importancia de las tres variables meteorologicas: si la correccion de hora
% estaba mal, al arreglarla estas tres deberian ganar peso
imp_meteo = importancia(1:3)';
fprintf('\nImportancia meteo (ALLSKY, T2M, WS50M): %.3f  %.3f  %.3f EUR/MWh\n', imp_meteo);

% error en los tramos que de verdad usa el EMS, no el promedio de las 24 horas
mae_h1     = mae_by_horizon(1);
mae_h1a6   = mean(mae_by_horizon(1:6));
skill_h1   = 100*(mae_n24_by_horizon(1) - mae_h1)   / mae_n24_by_horizon(1);
skill_h1a6 = 100*(mean(mae_n24_by_horizon(1:6)) - mae_h1a6) / mean(mae_n24_by_horizon(1:6));
metricas.mae_h1 = mae_h1;   metricas.mae_h1a6 = mae_h1a6;
metricas.skill_h1_pct = skill_h1;  metricas.skill_h1a6_pct = skill_h1a6;

fprintf('Skill vs naive-24: h+1 %+.1f %% | h+1..h+6 %+.1f %% | 24 h %+.1f %%\n', ...
    skill_h1, skill_h1a6, metricas.skill_vs_naive24_pct);

fila = table(string(sello), CORREGIR_ZONA_HORARIA, string(metricas.split), ...
    REFIT_CON_VAL, epocas_usadas, epoca_mejor, metricas.MAE_sin_refit, ...
    sum(idxTrain), sum(idxVal), ...
    MAE_c, RMSE_c, sMAPE_c, MAE_naive24, metricas.skill_vs_naive24_pct, ...
    mae_h1, skill_h1, mae_h1a6, skill_h1a6, mean(cv_mae), metricas.ratio_std_pred_real, ...
    MAE_combi, skill_combi, ...
    imp_meteo(1), imp_meteo(2), imp_meteo(3), ...
    mae_dias_campana(1), mae_dias_campana(2), mae_dias_campana(3), mae_dias_campana(4), ...
    'VariableNames', {'sello','zona_horaria_corregida','split', ...
    'refit_con_val','epocas_usadas','epoca_mejor','MAE_sin_refit','n_train','n_val', ...
    'MAE_clamp','RMSE_clamp','sMAPE_clamp','MAE_naive24','skill_vs_naive24_pct', ...
    'MAE_h1','skill_h1_pct','MAE_h1a6','skill_h1a6_pct','MAE_cv','ratio_std', ...
    'MAE_combi','skill_combi_pct', ...
    'imp_ALLSKY','imp_T2M','imp_WS50M', ...
    'MAE_02jul','MAE_11feb','MAE_13jul','MAE_17sep'});

ruta_registro = fullfile(carpeta_res, 'registro_lstm_precio.csv');
anadir_al_registro(ruta_registro, fila);

%% 17c. Exportacion de las figuras a memoria/img
carpeta_img = fullfile(ruta_base, '..', '..', 'memoria', 'img');
if exist(carpeta_img, 'dir')
    figs = findobj('Type', 'figure');
    for i = 1:numel(figs)
        nom = matlab.lang.makeValidName(get(figs(i), 'Name'));
        if isempty(nom), nom = sprintf('fig%d', i); end
        ruta_png = fullfile(carpeta_img, sprintf('lstm_precio_%s.png', nom));
        try
            exportgraphics(figs(i), ruta_png, 'Resolution', 200);
        catch
            print(figs(i), ruta_png, '-dpng', '-r200');
        end
    end
    fprintf('Figuras exportadas a %s\n', carpeta_img);
end
fprintf('  norm_params.campos: mu_F(1x%d), sigma_F(1x%d), mu_p, sigma_p\n', nFeatures, nFeatures)
fprintf('  S-Function reconstruye: 14 features (precio, ALLSKY, T2M, WS50M, hora/dia/mes, lags, fv)\n')
fprintf('  Entradas externas: ALLSKY, T2M, WS50M (3)\n')