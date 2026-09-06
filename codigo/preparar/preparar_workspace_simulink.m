% Deja en un solo fichero todas las senales de entrada del ano 2025 que necesita
% el modelo: precio de la luz de ENTSO-E, meteorologia de la NASA, las entradas
% ya normalizadas de las dos redes, la irradiancia de cielo claro y una version
% segundo a segundo de la irradiancia con ruido de nubes. Lo mas delicado que
% hace es cuadrar los relojes: los precios vienen en hora local espanola y la
% NASA entrega los suyos en hora solar, asi que sin corregir la irradiancia iba
% adelantada una o dos horas respecto al precio. Al final compara la hora del
% maximo de irradiancia con la de la generacion solar real para comprobar que la
% correccion ha quedado bien. El resultado se guarda como datos_OASIS.mat, que es
% lo que carga init_OASIS.m.
clc; clear; close all;

CORREGIR_ZONA_HORARIA = true;   % cuadra la hora de la NASA con la de los precios
SEMILLA_RUIDO_NUBES   = 42;     % reproducibilidad del ruido sintetico

ruta_base    = fileparts(mfilename('fullpath'));
ruta_datos   = fullfile(ruta_base, '..', 'data');
ruta_entsoe  = fullfile(ruta_datos, 'entsoe');
ruta_nasa    = fullfile(ruta_datos, 'NASA');
ruta_modelos = fullfile(ruta_base, '..', 'modelos');

% carpeta desde la que init_OASIS.m carga el .mat
ruta_destino = fullfile(ruta_base, '..', '..', 'SimugridElectrolinera', 'Datos');
if ~exist(ruta_destino, 'dir'), mkdir(ruta_destino); end

%% 1. Modelos y parametros de normalizacion
if exist(fullfile(ruta_modelos, 'lstm_solar_sevilla.mat'), 'file') && ...
   exist(fullfile(ruta_modelos, 'lstm_precio_luz.mat'), 'file')
    load(fullfile(ruta_modelos, 'lstm_solar_sevilla.mat'), 'norm_params');
    norm_solar = norm_params;

    load(fullfile(ruta_modelos, 'lstm_precio_luz.mat'), 'norm_params');
    norm_precio = norm_params;
    fprintf('Cargados parametros de normalizacion para Solar y Precio (14feat).\n');
else
    error('No se encuentran los modelos LSTM en codigo/modelos/. Ejecuta primero los scripts de entrenar/.');
end

%% 2. Lectura de los CSV de precio y de meteorologia
fprintf('Cargando fuentes de datos...\n');

archivo_precio = fullfile(ruta_entsoe, 'datos_entsoe_unificado_2021_2025.csv');
if ~exist(archivo_precio, 'file')
    error('No se encuentra %s. Ejecuta codigo/python/unificar_datos_entsoe.py.', archivo_precio);
end
T_precio = readtable(archivo_precio);
fechas_h = datetime(T_precio.timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');  % hora local Madrid

% irradiancia y nubosidad
archivo_solar = fullfile(ruta_nasa, 'NASA_07_26.csv');
opts1 = detectImportOptions(archivo_solar);
opts1.DataLines = [15 Inf];
T_nasa1 = readtable(archivo_solar, opts1);
T_nasa1.Properties.VariableNames = {'YEAR','MO','DY','HR','RH2M','PS','ALLSKY','CLRSKY'};

% viento y temperatura
archivo_viento = fullfile(ruta_nasa, 'NASA_07_25_WIND_TEMP.csv');
opts2 = detectImportOptions(archivo_viento);
opts2.DataLines = [13 Inf];
T_nasa2 = readtable(archivo_viento, opts2);
T_nasa2.Properties.VariableNames = {'YEAR','MO','DY','HR','T2M','WS10M','WS50M'};

% dos ejes de tiempo para la NASA: el de reloj local, con el que se cruza el
% precio, y el solar original, con el que se entreno la red
fechas_nasa1_raw = datetime(T_nasa1.YEAR, T_nasa1.MO, T_nasa1.DY, T_nasa1.HR, 0, 0);
fechas_nasa2_raw = datetime(T_nasa2.YEAR, T_nasa2.MO, T_nasa2.DY, T_nasa2.HR, 0, 0);

if CORREGIR_ZONA_HORARIA
    % las marcas de la NASA se leen como UTC y se pasan a hora de Madrid
    z1 = datetime(fechas_nasa1_raw, 'TimeZone', 'UTC');  z1.TimeZone = 'Europe/Madrid';
    z2 = datetime(fechas_nasa2_raw, 'TimeZone', 'UTC');  z2.TimeZone = 'Europe/Madrid';
    off1 = tzoffset(z1);
    off2 = tzoffset(z2);
    fechas_nasa1 = fechas_nasa1_raw + off1;   % LST -> hora local de reloj
    fechas_nasa2 = fechas_nasa2_raw + off2;
    fprintf('Correccion de zona horaria NASA (LST/UTC -> Europe/Madrid) APLICADA.\n');
else
    fechas_nasa1 = fechas_nasa1_raw;
    fechas_nasa2 = fechas_nasa2_raw;
    warning('[OASIS] CORREGIR_ZONA_HORARIA = false: irradiancia y precio quedan desfasados 1-2 h.');
end

T_nasa1.ALLSKY(T_nasa1.ALLSKY == -999) = NaN;
T_nasa1.CLRSKY(T_nasa1.CLRSKY == -999) = NaN;
T_nasa1.RH2M(T_nasa1.RH2M == -999) = NaN;
T_nasa1.PS(T_nasa1.PS == -999) = NaN;
T_nasa1.ALLSKY = fillmissing(T_nasa1.ALLSKY, 'linear');
T_nasa1.CLRSKY = fillmissing(T_nasa1.CLRSKY, 'linear');
T_nasa1.RH2M = fillmissing(T_nasa1.RH2M, 'linear');
T_nasa1.PS = fillmissing(T_nasa1.PS, 'linear');

T_nasa2.T2M(T_nasa2.T2M == -999) = NaN;
T_nasa2.WS10M(T_nasa2.WS10M == -999) = NaN;
T_nasa2.WS50M(T_nasa2.WS50M == -999) = NaN;
T_nasa2.T2M = fillmissing(T_nasa2.T2M, 'linear');
T_nasa2.WS10M = fillmissing(T_nasa2.WS10M, 'linear');
T_nasa2.WS50M = fillmissing(T_nasa2.WS50M, 'linear');

%% 3. Alineado de las series y filtro del ano 2025
fprintf('Alineando y filtrando datos de 2025...\n');

[~, idx_nasa1] = ismember(fechas_h, fechas_nasa1);
[~, idx_nasa2] = ismember(fechas_h, fechas_nasa2);
validos = (idx_nasa1 > 0) & (idx_nasa2 > 0) & (year(fechas_h) == 2025);

fechas_2025 = fechas_h(validos);              % eje hora local
ALLSKY = T_nasa1.ALLSKY(idx_nasa1(validos));
CLRSKY = T_nasa1.CLRSKY(idx_nasa1(validos));
RH2M   = T_nasa1.RH2M(idx_nasa1(validos));
PS     = T_nasa1.PS(idx_nasa1(validos));
T2M    = T_nasa2.T2M(idx_nasa2(validos));
WS50M  = T_nasa2.WS50M(idx_nasa2(validos));
HR_LST = T_nasa1.HR(idx_nasa1(validos));      % hora LST de cada muestra NASA

precio     = T_precio.precio(validos);
solar_real = T_precio.solar(validos);         % solo para el diagnostico de alineacion

num_horas = length(fechas_2025);
fprintf('Horas 2025: %d\n', num_horas);
if num_horas < 8000
    warning('[OASIS] Solo %d horas alineadas en 2025 (se esperaban ~8760). Revisa el cruce NASA/precio.', num_horas);
end

%% 4. Variables de calendario
% la hora de la red solar va en hora solar, igual que en el entrenamiento
h_sin = sin(2 * pi * HR_LST / 24);
h_cos = cos(2 * pi * HR_LST / 24);

% nubosidad, entrada de la red solar
CLD = zeros(num_horas, 1);
idx_sol = CLRSKY > 10;
CLD(idx_sol) = 1 - (ALLSKY(idx_sol) ./ CLRSKY(idx_sol));
CLD = max(0, min(1, CLD));

%% 5. Entradas de las dos redes

% las ocho entradas de la red solar, ya normalizadas
ALLSKY_n_solar = (ALLSKY - norm_solar.min_A) / (norm_solar.max_A - norm_solar.min_A);
RH2M_n_solar   = (RH2M - norm_solar.min_RH) / (norm_solar.max_RH - norm_solar.min_RH);
PS_n_solar     = (PS - norm_solar.min_PS) / (norm_solar.max_PS - norm_solar.min_PS);
d_sin_solar    = sin(2 * pi * day(fechas_2025, 'dayofyear') / 365.25);
d_cos_solar    = cos(2 * pi * day(fechas_2025, 'dayofyear') / 365.25);
solar_matrix   = [ALLSKY_n_solar, RH2M_n_solar, PS_n_solar, CLD, h_sin, h_cos, d_sin_solar, d_cos_solar];

% la red de precio recibe los valores en bruto y los normaliza ella misma
precio_matrix_ext = [ALLSKY, T2M, WS50M];

%% 6. Series en el formato que espera Simulink
tiempo_segundos = (0 : num_horas-1)' * 3600;

solar_features = timeseries(permute(solar_matrix, [2, 3, 1]), tiempo_segundos);
solar_features.Name = 'solar_features';

precio_features = timeseries(permute(precio_matrix_ext, [2, 3, 1]), tiempo_segundos);
precio_features.Name = 'precio_features';  % [3 x 1 x T]: ALLSKY, T2M, WS50M

precio_real = timeseries(precio, tiempo_segundos);
precio_real.Name = 'precio_real';

% irradiancia de cielo claro: la que habria con el cielo despejado. Solo depende
% de la geometria solar, asi que conocerla del futuro no rompe la causalidad
clrsky_real = timeseries(CLRSKY, tiempo_segundos);
clrsky_real.Name = 'clrsky_real';

% dia del ano y dia de la semana, entradas de la red de precio
dia_anno_ts = timeseries(day(fechas_2025, 'dayofyear'), tiempo_segundos);
dia_anno_ts.Name = 'dia_anno';

dia_semana_ts = timeseries(weekday(fechas_2025), tiempo_segundos);  % 1=dom, 7=sab
dia_semana_ts.Name = 'dia_semana';

% irradiancia segundo a segundo, con ruido de nubes anadido
disp('Interpolando irradiancia a segundo a segundo y generando ruido de nubes...');
rng(SEMILLA_RUIDO_NUBES, 'twister');

tiempo_1s = (0 : num_horas*3600 - 1)';
irrad_base_1s = interp1(tiempo_segundos, ALLSKY, tiempo_1s, 'linear');
irrad_base_1s = fillmissing(irrad_base_1s, 'constant', 0);

amplitud_ruido = 40;
ventana_nube = 300;
ruido_puro = randn(length(tiempo_1s), 1);
ruido_suave = filter(ones(1, ventana_nube)/ventana_nube, 1, ruido_puro);
std_ruido = std(ruido_suave);
if std_ruido > 0
    ruido_suave = ruido_suave / std_ruido;
end

ruido_lento = filter(ones(1, 7200)/7200, 1, rand(length(tiempo_1s), 1));
max_irrad = max(irrad_base_1s);
if max_irrad > 0
    factor_escala = amplitud_ruido * (irrad_base_1s / max_irrad) .* (0.5 + ruido_lento);
else
    factor_escala = zeros(length(tiempo_1s), 1);
end
irrad_real_data = irrad_base_1s + ruido_suave .* factor_escala;
irrad_real_data(irrad_real_data < 0) = 0;
irrad_real_data(isnan(irrad_real_data) | isinf(irrad_real_data)) = 0;

irrad_real = timeseries(irrad_real_data, tiempo_1s);
irrad_real.Name = 'irrad_real';

%% 7. Comprobacion de que los relojes han quedado cuadrados
% compara la hora del maximo de irradiancia con la del maximo de generacion
% solar real; corregido deben quedar a menos de una hora
try
    horas_dia = hour(fechas_2025);
    dias_diag = dateshift(fechas_2025, 'start', 'day');
    [dias_u, ~, g] = unique(dias_diag);
    n_dias = numel(dias_u);
    h_max_allsky = nan(n_dias, 1);
    h_max_solar  = nan(n_dias, 1);
    for k = 1:n_dias
        ix = find(g == k);
        [~, ia] = max(ALLSKY(ix));      h_max_allsky(k) = horas_dia(ix(ia));
        [~, is] = max(solar_real(ix));   h_max_solar(k)  = horas_dia(ix(is));
    end
    verano = month(dias_u) >= 6 & month(dias_u) <= 8;
    fprintf('\n--- Diagnostico de alineacion horaria ---\n');
    fprintf('  Hora media del maximo de ALLSKY   (jun-ago): %.2f\n', mean(h_max_allsky(verano), 'omitnan'));
    fprintf('  Hora media del maximo de solar ES (jun-ago): %.2f\n', mean(h_max_solar(verano), 'omitnan'));
    desfase = mean(h_max_solar(verano), 'omitnan') - mean(h_max_allsky(verano), 'omitnan');
    if abs(desfase) <= 1.2
        fprintf('  Desfase medio: %.2f h  --> OK\n', desfase);
    else
        fprintf('  Desfase medio: %.2f h  --> REVISAR (se esperaba <= 1.2 h)\n', desfase);
    end
catch ME
    fprintf('\n(Diagnostico de alineacion no ejecutado: %s)\n', ME.message);
end

%% 8. Guardado
archivo_salida = fullfile(ruta_destino, 'datos_OASIS.mat');
save(archivo_salida, ...
    'solar_features', 'precio_features', 'precio_real', 'irrad_real', ...
    'clrsky_real', 'dia_anno_ts', 'dia_semana_ts', ...
    'tiempo_segundos', 'tiempo_1s', '-v7.3');

fprintf('\n======================================================\n');
fprintf('PROCESO COMPLETADO\n');
fprintf('Archivo guardado: %s\n', archivo_salida);
fprintf('Correccion de zona horaria: %d\n', CORREGIR_ZONA_HORARIA);
fprintf('Variables creadas:\n');
fprintf('  - solar_features   (8 variables, LSTM solar; h_sin/h_cos en eje LST)\n');
fprintf('  - precio_features  (3 variables: ALLSKY, T2M, WS50M - raw, S-Function normaliza)\n');
fprintf('  - precio_real      (Precios 2025 sin normalizar, hora local)\n');
fprintf('  - clrsky_real      (Irradiancia de cielo claro horaria, para lstm_sol.m)\n');
fprintf('  - irrad_real       (Irradiancia 2025 con ruido, 1s, semilla %d)\n', SEMILLA_RUIDO_NUBES);
fprintf('  - tiempo_segundos  (Eje temporal horario)\n');
fprintf('======================================================\n');
