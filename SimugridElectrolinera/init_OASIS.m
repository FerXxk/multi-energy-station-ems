% Deja el workspace listo para simular OASIS.slx. Carga los perfiles de demanda
% de coches electricos y de hidrogeno, recorta las series de precio y de
% meteorologia al dia que se quiere simular dejando una semana previa de historia
% para que las redes lleguen calientes, y carga las dos LSTM. Si se ejecuta tal
% cual, pregunta la fecha por una ventana; si antes se han definido fecha_sim,
% modo_ev_sel, semilla_sim o dias_sim_sel no pregunta nada, que es como lo
% arranca la campana de simulacion.
clc;
ruta_base = fileparts(mfilename('fullpath'));

GridON = 1;       % 1 = Conectado a la red, 0 = Modo isla
DiscreteON = 1;   % 1 = Simulación discreta (para paso fijo ode3)
Risk = 1;         % Flag de escenario de riesgo/peor caso

% Escenario: tipo de dia y semilla del perfil de demanda
if exist('modo_ev_sel', 'var') && ~isempty(modo_ev_sel)
    modo_ev = modo_ev_sel;
else
    modo_ev = 'laborable';  % <--- CAMBIAR A 'findesemana' si se necesita
end
if exist('semilla_sim', 'var') && ~isempty(semilla_sim)
    semilla_ev = semilla_sim;
else
    semilla_ev = [];        % [] = usar el perfil activo (perfil_EV.mat)
end

% Numero de dias seguidos a simular: con mas de uno se encadenan varios perfiles
% diarios y el EMS deja de estar obligado a cerrar el balance dentro del dia.
if exist('dias_sim_sel', 'var') && ~isempty(dias_sim_sel)
    dias_sim = dias_sim_sel;
elseif ~exist('dias_sim', 'var') || isempty(dias_sim)
    dias_sim = 1;
end
dias_sim = max(1, round(dias_sim));

if isempty(semilla_ev)
    nombre_ev = 'perfil_EV.mat';
    nombre_h2 = 'perfil_H2.mat';
else
    nombre_ev = sprintf('perfil_EV_s%d.mat', semilla_ev);
    nombre_h2 = sprintf('perfil_H2_s%d.mat', semilla_ev);
end

perfil_ev_path = fullfile(ruta_base, 'Datos', 'Cars', nombre_ev);
if exist(perfil_ev_path, 'file')
    datos_EV = load(perfil_ev_path);
    if strcmp(modo_ev, 'findesemana')
        demanda_EV = datos_EV.demanda_EV_finde;
        pot_EV    = datos_EV.pot_EV_finde;
    else
        demanda_EV = datos_EV.demanda_EV_lab;
        pot_EV    = datos_EV.pot_EV_lab;
    end
    % los bloques From Workspace de Simulink leen del workspace base
    assignin('base', 'demanda_EV', demanda_EV);
    assignin('base', 'pot_EV', pot_EV);
    % se dejan tambien con los nombres antiguos por compatibilidad
    assignin('base', 'pot_EV_lab', datos_EV.pot_EV_lab);
    assignin('base', 'pot_EV_finde', datos_EV.pot_EV_finde);
    assignin('base', 'demanda_EV_lab', datos_EV.demanda_EV_lab);
    assignin('base', 'demanda_EV_finde', datos_EV.demanda_EV_finde);
    clear datos_EV;
else
    warning('[OASIS] %s no encontrado. Ejecuta Demanda_Coches_Aleatoria(semilla) desde codigo/preparar/.', nombre_ev);
end

perfil_h2_path = fullfile(ruta_base, 'Datos', 'Cars', nombre_h2);
if exist(perfil_h2_path, 'file')
    datos_H2 = load(perfil_h2_path);
    if strcmp(modo_ev, 'findesemana')
        demanda_H2 = datos_H2.demanda_H2_finde;
    else
        demanda_H2 = datos_H2.demanda_H2_lab;
    end
    % los bloques From Workspace de Simulink leen del workspace base
    assignin('base', 'demanda_H2', demanda_H2);
    % se dejan tambien con los nombres antiguos por compatibilidad
    assignin('base', 'demanda_H2_lab', datos_H2.demanda_H2_lab);
    assignin('base', 'demanda_H2_finde', datos_H2.demanda_H2_finde);
    clear datos_H2;
end

% Parámetros de potencia base que usará Simulink para multiplicar las ondas
P_cargador_EV = 50000; % 50 kW por cada poste eléctrico activo

%% 1. Fecha a simular: por variable si existe, si no se pregunta
if exist('fecha_sim', 'var') && ~isempty(fecha_sim)
    fecha_usuario = fecha_sim;
    fprintf('[OASIS] Fecha fijada por variable fecha_sim: %s\n', fecha_usuario);
else
    prompt   = {'Introduce la fecha a simular de 2025 (DD-MM-AAAA):'};
    dlgtitle = 'Configurador de Escenario Climático';
    dims     = [1 50];
    definput = {'15-08-2025'};
    respuesta = inputdlg(prompt, dlgtitle, dims, definput);

    if isempty(respuesta)
        fecha_usuario = '15-08-2025';
    else
        fecha_usuario = respuesta{1};
    end
end

%% 2. Offsets temporales
t_inicio     = datetime(fecha_usuario, 'InputFormat', 'dd-MM-yyyy');
t_cero_anno  = datetime(2025, 1, 1, 0, 0, 0);
offset_segundos = seconds(t_inicio - t_cero_anno);

% el buffer cubre la historia mas larga que pide una red: 168 h la de precio
horas_buffer      = 168;
segundos_buffer   = horas_buffer * 3600;
inicio_con_buffer = offset_segundos - segundos_buffer;
fin_segundos      = offset_segundos + dias_sim * 86400; % dias_sim x 24 h a simular

if inicio_con_buffer < 0
    inicio_con_buffer = 0;
    warning('[OASIS] Fecha demasiado cercana al 1 de enero: buffer de historia recortado.');
end

%% 2b. Demanda de varios dias seguidos, sustituye a la de un dia
% se hace aqui porque el tipo de perfil de cada dia sale del calendario real
if dias_sim > 1
    addpath(fullfile(ruta_base, '..', 'codigo', 'preparar'));
    ruta_cars_md = fullfile(ruta_base, 'Datos', 'Cars');

    if isempty(semilla_ev)
        semilla_md = 1;
        warning(['[OASIS] dias_sim = %d sin semilla_sim definida: se usa la ' ...
            'semilla base 1 para construir la demanda multidia.'], dias_sim);
    else
        semilla_md = semilla_ev;
    end

    opc_md = struct('verbose', true);
    if exist('opciones_demanda_sim', 'var') && ~isempty(opciones_demanda_sim)
        opc_md.opciones_demanda = opciones_demanda_sim;
        opc_md.regenerar = true;   % el .mat se nombra solo por la semilla: con
                                   % otras opciones hay que rehacerlo
    end

    D_md = construir_demanda_multidia(fecha_usuario, dias_sim, semilla_md, ...
        ruta_cars_md, opc_md);

    demanda_EV = D_md.demanda_EV;
    pot_EV     = D_md.pot_EV;
    demanda_H2 = D_md.demanda_H2;

    assignin('base', 'demanda_EV', demanda_EV);
    assignin('base', 'demanda_H2', demanda_H2);
    assignin('base', 'pot_EV',     pot_EV);
    % pot_EV_lab solo alimenta un Scope, pero sin la serie larga se queda en blanco
    assignin('base', 'pot_EV_lab', pot_EV);
    assignin('base', 'detalle_semana', D_md.detalle);
end

%% 3. Datos de entrada, generados por preparar_workspace_simulink.m
% trae solar_features, precio_features, precio_real, irrad_real y tiempo_segundos
workspace_mat = fullfile(ruta_base, 'Datos', 'datos_OASIS.mat');
if exist(workspace_mat, 'file')
    load(workspace_mat);
    fprintf('[OASIS] Workspace con datos para los LSTMs cargado: %.0f horas de datos (%.1f días)\n', ...
        length(tiempo_segundos), length(tiempo_segundos)/24);
else
    error('[OASIS] No se encuentra datos_OASIS.mat. Ejecuta primero preparar_workspace_simulink.m desde codigo/preparar/');
end

%% 4. Recorte de las series al dia simulado, mas el buffer de historia

% entradas de la LSTM solar
idx_sol = (solar_features.Time >= inicio_con_buffer) & ...
    (solar_features.Time <= fin_segundos);
ts_solar_sim = timeseries(solar_features.Data(:, :, idx_sol), ...
    solar_features.Time(idx_sol) - offset_segundos);
ts_solar_sim.Name = 'features_solar';

assignin('base', 'features_solar', ts_solar_sim);

% entradas meteorologicas de la LSTM de precio
idx_pr = (precio_features.Time >= inicio_con_buffer) & ...
    (precio_features.Time <= fin_segundos);
ts_precio_sim = timeseries(precio_features.Data(:, :, idx_pr), ...
    precio_features.Time(idx_pr) - offset_segundos);
ts_precio_sim.Name = 'features_precio';
assignin('base', 'features_precio', ts_precio_sim);

% irradiancia real, solo como referencia
idx_ir = (irrad_real.Time >= inicio_con_buffer) & ...
    (irrad_real.Time <= fin_segundos);
ts_irrad_ref = timeseries(irrad_real.Data(idx_ir), ...
    irrad_real.Time(idx_ir) - offset_segundos);
ts_irrad_ref.Name = 'irrad_real_seg';
assignin('base', 'irrad_real_seg', ts_irrad_ref);

% irradiancia de cielo claro, que la LSTM solar usa como envolvente
% se corta 24 h mas alla del final porque en la ultima hora aun pide futuro
if exist('clrsky_real', 'var')
    idx_clr = (clrsky_real.Time >= inicio_con_buffer) & ...
        (clrsky_real.Time <= fin_segundos + 24*3600);
    clrsky_sim = timeseries(clrsky_real.Data(idx_clr), ...
        clrsky_real.Time(idx_clr) - offset_segundos);
    clrsky_sim.Name = 'clrsky_hour';
    assignin('base', 'clrsky_hour', clrsky_sim);
else
    warning(['[OASIS] Falta clrsky_real en datos_OASIS.mat: la LSTM solar dara la ' ...
        'prediccion cruda. Regeneralo con preparar_workspace_simulink.m.']);
end

% Series alargadas 24 h para el modo oraculo, que lee valores reales del futuro
% van aparte para no tocar las que consumen los bloques normales
idx_sol_ext = (solar_features.Time >= inicio_con_buffer) & ...
    (solar_features.Time <= fin_segundos + 24*3600);
features_solar_ext = timeseries(solar_features.Data(:, :, idx_sol_ext), ...
    solar_features.Time(idx_sol_ext) - offset_segundos);
features_solar_ext.Name = 'features_solar_ext';
assignin('base', 'features_solar_ext', features_solar_ext);

idx_pr_ext = (precio_real.Time >= inicio_con_buffer) & ...
    (precio_real.Time <= fin_segundos + 24*3600);
precio_real_ext = timeseries(precio_real.Data(idx_pr_ext), ...
    precio_real.Time(idx_pr_ext) - offset_segundos);
precio_real_ext.Name = 'precio_real_ext';
assignin('base', 'precio_real_ext', precio_real_ext);

% precio real desplazado a tiempos negativos, para precargar el buffer de la LSTM
idx_pr_real = (precio_real.Time >= inicio_con_buffer) & ...
    (precio_real.Time <= fin_segundos);
precio_real_sim = timeseries(precio_real.Data(idx_pr_real), ...
    precio_real.Time(idx_pr_real) - offset_segundos);
precio_real_sim.Name = 'precio_real_hour';
assignin('base', 'precio_real_hour', precio_real_sim);

% dia del ano y dia de la semana, entradas de calendario de la LSTM de precio

idx_da = (dia_anno_ts.Time >= inicio_con_buffer) & (dia_anno_ts.Time <= fin_segundos);
dia_anno_sim = timeseries(dia_anno_ts.Data(idx_da), dia_anno_ts.Time(idx_da) - offset_segundos);
dia_anno_sim.Name = 'dia_anno';

idx_ds = (dia_semana_ts.Time >= inicio_con_buffer) & (dia_semana_ts.Time <= fin_segundos);
dia_semana_sim = timeseries(dia_semana_ts.Data(idx_ds), dia_semana_ts.Time(idx_ds) - offset_segundos);
dia_semana_sim.Name = 'dia_semana';

assignin('base', 'dia_anno', dia_anno_sim);
assignin('base', 'dia_semana', dia_semana_sim);


%% 5. Carga de las dos redes
ruta_modelos = fullfile(ruta_base, '..', 'codigo', 'modelos');

loaded_solar = load(fullfile(ruta_modelos, 'lstm_solar_sevilla.mat'));
lstm_net     = loaded_solar.lstm_net;
norm_params  = loaded_solar.norm_params;

% red de precio: 14 entradas, precio pasado mas meteorologia de la NASA
archivo_precio = 'lstm_precio_luz.mat';
loaded_precio = load(fullfile(ruta_modelos, archivo_precio));
net_precio    = loaded_precio.net;
norm_precio   = loaded_precio.norm_params;

fprintf('[OASIS] Redes neuronales cargadas: %s | %s (%s)\n', class(lstm_net), class(net_precio), archivo_precio);

%% 6. Resumen de lo preparado
fecha_dt = datetime(fecha_usuario, 'InputFormat', 'dd-MM-yyyy');
dias_sem = {'domingo','lunes','martes','miércoles','jueves','viernes','sábado'};
nombre_dia = dias_sem{weekday(fecha_dt)};
es_finde_real = ismember(weekday(fecha_dt), [1 7]);   % 1=domingo, 7=sábado
es_finde_perf = strcmp(modo_ev, 'findesemana');
if (dias_sim == 1) && (es_finde_real ~= es_finde_perf)
    warning(['[OASIS] %s es %s, pero el perfil de demanda cargado es ''%s''. ' ...
        'Si no es intencionado, ajusta modo_ev / modo_ev_sel.'], ...
        fecha_usuario, nombre_dia, modo_ev);
end

fprintf('\n[OASIS] ESCENARIO PREPARADO\n');
fprintf('  Fecha         : %s (%s)\n', fecha_usuario, nombre_dia);
if dias_sim == 1
    fprintf('  Perfil demanda: %s\n', modo_ev);
else
    fprintf('  Horizonte     : %d dias seguidos (%.0f s)\n', dias_sim, dias_sim*86400);
    fprintf('  Perfil demanda: multidia (laborable/findesemana por dia real)\n');
end
if isempty(semilla_ev)
    fprintf('  Semilla       : perfil activo (perfil_EV.mat)\n');
else
    fprintf('  Semilla       : %d\n', semilla_ev);
end
fprintf('  Modo red      : GridON = %d\n', GridON);
if dias_sim == 1
    disp(['[OASIS] Listo para simular el día: ', fecha_usuario]);
else
    fprintf('[OASIS] Listo para simular %d días seguidos desde el %s. Acuérdate de poner StopTime = %d.\n', ...
        dias_sim, fecha_usuario, dias_sim*86400);
end
