function meta = Demanda_Coches_Aleatoria(semilla, opciones)
% Inventa un dia de trafico en la estacion: a que hora llega cada coche, cuanta
% energia o cuantos kilos de hidrogeno pide, y cuanto tarda en servirse haciendo
% cola si estan todos los surtidores ocupados. Las llegadas y las energias salen
% de las distribuciones medidas en el conjunto de datos de la EPFL, y la carga
% electrica sigue la curva real de un cargador, primero a corriente constante y
% luego a tension constante. Genera un dia laborable y uno de fin de semana y los
% guarda en un .mat por semilla, de forma que la misma semilla da siempre el
% mismo dia y las versiones del EMS se pueden comparar sobre la misma demanda.
% Se llama por ejemplo como Demanda_Coches_Aleatoria(7, struct('N_postes_EV', 4)).

if nargin < 1 || isempty(semilla), semilla = 1; end
if nargin < 2, opciones = struct(); end

def = struct('N_postes_EV', 2, 'N_postes_H2', 1, ...
             'P_cargador_EV', 50, 'Caudal_H2_surtidor', 1.2, ...
             'factor_llegadas_EV', 1.0, 'factor_llegadas_H2', 1.0, ...
             'usar_datos_reales', true, 'guardar_perfil_activo', true);
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

rng(semilla, 'twister');
fprintf('[OASIS] Generando demanda con semilla %d (postes EV=%d, H2=%d, factor EV=%.2f, factor H2=%.2f)\n', ...
    semilla, opciones.N_postes_EV, opciones.N_postes_H2, ...
    opciones.factor_llegadas_EV, opciones.factor_llegadas_H2);


%% Configuracion
usar_datos_reales = opciones.usar_datos_reales;   % true = usar distribuciones de DESL-EPFL

N_postes_EV = opciones.N_postes_EV;   % Nº de surtidores EV disponibles
N_postes_H2 = opciones.N_postes_H2;   % Nº de surtidores H2 disponibles

P_cargador_EV = opciones.P_cargador_EV;             % Potencia nominal del cargador (kW)
Caudal_H2_surtidor = opciones.Caudal_H2_surtidor;   % Velocidad de repostaje H2 (kg/min)
Caudal_H2_segundo = Caudal_H2_surtidor / 60; % kg/s


%% Datos reales de sesiones de carga, si estan disponibles
ruta_base = fileparts(mfilename('fullpath'));
ruta_dataset = fullfile(ruta_base, '..', 'data', 'desl_epfl');

datos_cargados = false;
resumen_tipo_dia = [];
if usar_datos_reales
    archivo_llegadas = fullfile(ruta_dataset, 'distribucion_llegadas_ev.csv');
    archivo_energia  = fullfile(ruta_dataset, 'distribucion_energia_ev.csv');
    archivo_soc      = fullfile(ruta_dataset, 'distribucion_soc_ev.csv');
    archivo_tipo_dia = fullfile(ruta_dataset, 'resumen_por_tipo_dia.csv');

    if exist(archivo_llegadas, 'file') && exist(archivo_energia, 'file') && ...
       exist(archivo_soc, 'file')

        llegadas_ev = readtable(archivo_llegadas);
        energia_ev  = readtable(archivo_energia);
        soc_ev      = readtable(archivo_soc);
        datos_cargados = true;
        fprintf('Datos DESL-EPFL cargados correctamente.\n');

        if exist(archivo_tipo_dia, 'file')
            resumen_tipo_dia = readtable(archivo_tipo_dia);
        end
    else
        warning('Archivos DESL-EPFL no encontrados. Usando generación aleatoria.');
    end
end


%% Eje de tiempo del dia, segundo a segundo
tiempo = (0:1:86400)';
N = length(tiempo);
ruta_cars = fullfile(ruta_base, '..', '..', 'SimugridElectrolinera', 'Datos', 'Cars');
if ~exist(ruta_cars, 'dir'), mkdir(ruta_cars); end


%% Perfiles del dia laborable y del fin de semana
modos = {'laborable', 'findesemana'};
meta = struct();

for m = 1:length(modos)
    es_findesemana = strcmp(modos{m}, 'findesemana');

    % numero de coches segun el tipo de dia
    if datos_cargados && usar_datos_reales
        if ~isempty(resumen_tipo_dia)
            if es_findesemana
                spd = resumen_tipo_dia.sesiones_por_dia(strcmp(resumen_tipo_dia.tipo_dia, 'findesemana'));
            else
                spd = resumen_tipo_dia.sesiones_por_dia(strcmp(resumen_tipo_dia.tipo_dia, 'laborable'));
            end
        else
            spd = 8.5;
        end
        rango_EVs = max(round(spd * opciones.factor_llegadas_EV), 1);
        rango_EVs = [max(rango_EVs - 1, 1), rango_EVs + 1];
        rango_H2s = max(round([4, 8] * opciones.factor_llegadas_H2), 1);
    else
        if es_findesemana
            rango_EVs = max(round([4, 8] * opciones.factor_llegadas_EV), 1);
            rango_H2s = max(round([2, 4] * opciones.factor_llegadas_H2), 1);
        else
            rango_EVs = max(round([8, 15] * opciones.factor_llegadas_EV), 1);
            rango_H2s = max(round([4, 8] * opciones.factor_llegadas_H2), 1);
        end
    end

    %% Coches electricos
    Num_EVs = randi(rango_EVs);
    t_entrada_EV  = zeros(Num_EVs, 1);
    T_carga_seg   = zeros(Num_EVs, 1);
    Capacidad_bat = zeros(Num_EVs, 1);
    SOC_ini_vec   = zeros(Num_EVs, 1);
    SOC_fin_vec   = zeros(Num_EVs, 1);
    Energia_needed_vec = zeros(Num_EVs, 1);

    for i = 1:Num_EVs
        if datos_cargados && usar_datos_reales
            hora_llegada = randsample(llegadas_ev.hora, 1, true, llegadas_ev.probabilidad);
            t_entrada_EV(i) = hora_llegada * 3600 + randi([0, 59]) * 60;
            Energia_needed  = randsample(energia_ev.energia_kwh, 1);
            Capacidad_bat(i) = randi([50, 80]);
            SOC_ini_vec(i) = max(min(round(randsample(soc_ev.soc_llegada, 1)), 90), 5);
            SOC_fin_vec(i) = min(round(SOC_ini_vec(i) + (Energia_needed / Capacidad_bat(i)) * 100), 95);
            T_carga_seg(i) = round((Energia_needed / P_cargador_EV) * 3600);
            Energia_needed_vec(i) = Energia_needed;
        else
            t_entrada_EV(i) = randi([6*3600, 22*3600]);
            Capacidad_bat(i) = randi([50, 80]);
            SOC_ini_vec(i) = randi([10, 30]);
            SOC_fin_vec(i) = randi([75, 85]);
            Energia_needed = Capacidad_bat(i) * (SOC_fin_vec(i) - SOC_ini_vec(i)) / 100;
            T_carga_seg(i) = round((Energia_needed / P_cargador_EV) * 3600);
            Energia_needed_vec(i) = Energia_needed;
        end
    end

    % cola por orden de llegada
    [~, idx_orden] = sort(t_entrada_EV);
    disp_postes = zeros(N_postes_EV, 1);
    t_inicio_EV = zeros(Num_EVs, 1);
    t_salida_EV = zeros(Num_EVs, 1);
    for i = 1:Num_EVs
        k = idx_orden(i);
        [t_libre, j] = min(disp_postes);
        t_inicio_EV(k) = max(t_entrada_EV(k), t_libre);
        t_salida_EV(k) = t_inicio_EV(k) + T_carga_seg(k);
        if t_salida_EV(k) > 86400; t_salida_EV(k) = 86400; end
        disp_postes(j) = t_salida_EV(k);
    end

    % numero de coches conectados en cada instante
    coches_EV = zeros(N, 1);
    for i = 1:Num_EVs
        idx = tiempo >= t_inicio_EV(i) & tiempo <= t_salida_EV(i);
        coches_EV(idx) = coches_EV(idx) + 1;
    end

    % curva de potencia del cargador, con la duracion ajustada por biseccion
    pot_EV = zeros(N, 1);
    for i = 1:Num_EVs
        dur_original = t_salida_EV(i) - t_inicio_EV(i);
        if dur_original <= 0; continue; end

        Energia_CC = max(Capacidad_bat(i) * (min(SOC_fin_vec(i), 80) - SOC_ini_vec(i)) / 100, 0);
        t_CC_nominal = min(round((Energia_CC / P_cargador_EV) * 3600), dur_original);

        % energia entregada para una duracion dada
        calc_energia = @(dur_val) calc_energia_cc_cv(dur_val, t_CC_nominal, P_cargador_EV);

        % se busca la duracion que entrega justo la energia que pide el coche
        E_target = Energia_needed_vec(i);
        d_lo = max(t_CC_nominal, 1);   % mínimo hasta fin de fase CC
        d_hi = dur_original * 3;        % permitir hasta 3x la duración nominal
        E_lo = calc_energia(d_lo);
        E_hi = calc_energia(d_hi);

        if E_target <= E_lo
            dur_real = d_lo;
        elseif E_target >= E_hi
            dur_real = d_hi;
        else
            for iter = 1:30
                d_mid = (d_lo + d_hi) / 2;
                E_mid = calc_energia(d_mid);
                if E_mid < E_target
                    d_lo = d_mid;
                else
                    d_hi = d_mid;
                end
            end
            dur_real = round((d_lo + d_hi) / 2);
        end

        dur_real = max(dur_real, 1);
        t_loc = (0:dur_real-1)';
        P = zeros(length(t_loc), 1);
        for t = 1:length(t_loc)
            if t_loc(t) < t_CC_nominal
                P(t) = P_cargador_EV;
            else
                tau = max((dur_real - t_CC_nominal) / 3, 1);
                P(t) = P_cargador_EV * exp(-(t_loc(t) - t_CC_nominal) / tau);
            end
        end
        i0 = t_inicio_EV(i) + 1;
        iF = min(i0 + length(P) - 1, N);
        pot_EV(i0:iF) = pot_EV(i0:iF) + P(1:iF - i0 + 1);
    end

    % se guarda con el sufijo del tipo de dia
    if es_findesemana
        demanda_EV_finde  = timeseries(coches_EV, tiempo);
        demanda_EV_finde.Name = 'Coches_EV_Findesemana';
        pot_EV_finde      = timeseries(pot_EV, tiempo);
        pot_EV_finde.Name = 'Potencia_EV_kW_Findesemana';
    else
        demanda_EV_lab    = timeseries(coches_EV, tiempo);
        demanda_EV_lab.Name = 'Coches_EV_Laborable';
        pot_EV_lab        = timeseries(pot_EV, tiempo);
        pot_EV_lab.Name = 'Potencia_EV_kW_Laborable';
    end

    %% Hidrogeno
    % no hay datos publicos de repostajes de hidrogeno: se reutiliza la
    % distribucion de llegadas de los electricos y una carga de 3 a 5 kg,
    % que es lo que admite un turismo de pila de combustible
    Num_H2s = randi(rango_H2s);
    t_entrada_H2 = zeros(Num_H2s, 1);
    T_repostaje  = zeros(Num_H2s, 1);
    Kg_repost    = zeros(Num_H2s, 1);
    for i = 1:Num_H2s
        if datos_cargados && usar_datos_reales
            hora_llegada_h2 = randsample(llegadas_ev.hora, 1, true, llegadas_ev.probabilidad);
            t_entrada_H2(i) = hora_llegada_h2 * 3600 + randi([0, 59]) * 60;
        else
            t_entrada_H2(i) = randi([7*3600, 21*3600]);
        end
        Kg_repost(i) = 3 + 2 * rand();
        T_repostaje(i) = round(Kg_repost(i) / Caudal_H2_segundo);
    end
    disp_H2 = zeros(N_postes_H2, 1);
    t_ini_H2 = zeros(Num_H2s, 1);
    t_sal_H2 = zeros(Num_H2s, 1);
    [~, idx_H2] = sort(t_entrada_H2);
    for i = 1:Num_H2s
        k = idx_H2(i);
        [tl, j] = min(disp_H2);
        t_ini_H2(k) = max(t_entrada_H2(k), tl);
        t_sal_H2(k) = t_ini_H2(k) + T_repostaje(k);
        if t_sal_H2(k) > 86400; t_sal_H2(k) = 86400; end
        disp_H2(j) = t_sal_H2(k);
    end
    H2 = zeros(N, 1);
    for i = 1:Num_H2s
        idx = tiempo >= t_ini_H2(i) & tiempo <= t_sal_H2(i);
        H2(idx) = H2(idx) + Caudal_H2_segundo;
    end

    if es_findesemana
        demanda_H2_finde = timeseries(H2, tiempo);
        demanda_H2_finde.Name = 'Demanda_H2_Findesemana';
    else
        demanda_H2_lab   = timeseries(H2, tiempo);
        demanda_H2_lab.Name = 'Demanda_H2_Laborable';
    end

    % estadisticas del dia generado
    T_esp = t_inicio_EV - t_entrada_EV;
    espera_max = max(T_esp);
    fprintf('\n[%s] %d EVs, %d H2s | Esperaron EV: %d (%.0f%%) | Espera máx: %.0f min\n', ...
        upper(modos{m}), Num_EVs, Num_H2s, sum(T_esp > 0), 100*sum(T_esp > 0)/Num_EVs, espera_max/60);
    if espera_max > 7200
        warning('[OASIS] Espera máxima > 2 horas (%.0f min). Considerar añadir cargadores o implementar renegging.', espera_max/60);
    end

    % comprobacion de que la curva entrega la energia pedida
    energia_entregada = sum(pot_EV) / 3600;  % kWh (paso de 1 segundo)
    energia_pedida = sum(Energia_needed_vec);
    ratio = energia_entregada / energia_pedida;
    fprintf('  Energía pedida: %.1f kWh | Entregada (integrada): %.1f kWh | Ratio: %.2f\n', ...
        energia_pedida, energia_entregada, ratio);
    if abs(ratio - 1) > 0.1
        warning('Discrepancia de energía > 10%%. La curva CC-CV puede estar entregando menos energía de la necesaria.');
    end

    % totales del dia, para poder describir el escenario
    % el modelo no usa pot_EV: multiplica el contador de coches por la potencia
    kg_H2_dia   = sum(H2) * 1;                       % H2 en kg/s, paso 1 s
    kWh_EV_dia  = energia_entregada;                 % kWh integrados de pot_EV
    kWh_EV_slx  = sum(coches_EV) * (P_cargador_EV/0.9) / 3600;  % lo que vera el modelo
    if es_findesemana
        meta.findesemana = struct('Num_EVs', Num_EVs, 'Num_H2s', Num_H2s, ...
            'kg_H2_dia', kg_H2_dia, 'kWh_EV_perfil', kWh_EV_dia, ...
            'kWh_EV_modelo', kWh_EV_slx, 'espera_max_min', espera_max/60);
    else
        meta.laborable = struct('Num_EVs', Num_EVs, 'Num_H2s', Num_H2s, ...
            'kg_H2_dia', kg_H2_dia, 'kWh_EV_perfil', kWh_EV_dia, ...
            'kWh_EV_modelo', kWh_EV_slx, 'espera_max_min', espera_max/60);
    end
    fprintf('  H2 servido: %.1f kg | EV perfil CC-CV: %.0f kWh | EV como lo ve OASIS.slx: %.0f kWh\n', ...
        kg_H2_dia, kWh_EV_dia, kWh_EV_slx);
end


%% Guardado, con los arrays crudos ademas de los timeseries para que Python
% pueda leerlos
% se extraen tiempos y datos de los timeseries
demanda_EV_lab_data   = demanda_EV_lab.Data;
demanda_EV_lab_time   = demanda_EV_lab.Time;
demanda_EV_finde_data = demanda_EV_finde.Data;
demanda_EV_finde_time = demanda_EV_finde.Time;
pot_EV_lab_data       = pot_EV_lab.Data;
pot_EV_lab_time       = pot_EV_lab.Time;
pot_EV_finde_data     = pot_EV_finde.Data;
pot_EV_finde_time     = pot_EV_finde.Time;
tiempo_ev             = demanda_EV_lab.Time;

demanda_H2_lab_data   = demanda_H2_lab.Data;
demanda_H2_lab_time   = demanda_H2_lab.Time;
demanda_H2_finde_data = demanda_H2_finde.Data;
demanda_H2_finde_time = demanda_H2_finde.Time;
tiempo_h2             = demanda_H2_lab.Time;
meta.semilla   = semilla;
meta.opciones  = opciones;
meta.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

vars_EV = {'demanda_EV_lab', 'demanda_EV_finde', 'pot_EV_lab', 'pot_EV_finde', ...
    'tiempo_ev', ...
    'demanda_EV_lab_data', 'demanda_EV_lab_time', ...
    'demanda_EV_finde_data', 'demanda_EV_finde_time', ...
    'pot_EV_lab_data', 'pot_EV_lab_time', ...
    'pot_EV_finde_data', 'pot_EV_finde_time', 'meta'};
vars_H2 = {'demanda_H2_lab', 'demanda_H2_finde', ...
    'tiempo_h2', ...
    'demanda_H2_lab_data', 'demanda_H2_lab_time', ...
    'demanda_H2_finde_data', 'demanda_H2_finde_time', 'meta'};

% copia identificada por semilla, la que usa la campana
archivo_EV_s = fullfile(ruta_cars, sprintf('perfil_EV_s%d.mat', semilla));
archivo_H2_s = fullfile(ruta_cars, sprintf('perfil_H2_s%d.mat', semilla));
save(archivo_EV_s, vars_EV{:});
save(archivo_H2_s, vars_H2{:});

% y copia con los nombres de siempre, para quien cargue perfil_EV.mat directamente
if opciones.guardar_perfil_activo
    save(fullfile(ruta_cars, 'perfil_EV.mat'), vars_EV{:});
    save(fullfile(ruta_cars, 'perfil_H2.mat'), vars_H2{:});
end

fprintf('\nGuardado en: %s\n', ruta_cars);
fprintf('  perfil_EV_s%d.mat / perfil_H2_s%d.mat\n', semilla, semilla);
if opciones.guardar_perfil_activo
    fprintf('  perfil_EV.mat / perfil_H2.mat (perfil activo = semilla %d)\n', semilla);
end

end   % <-- fin de la funcion principal Demanda_Coches_Aleatoria


%% Funciones auxiliares
function E = calc_energia_cc_cv(dur, t_CC, P_max)
    % energia entregada por la curva del cargador en una duracion dada
    if dur <= 0
        E = 0;
        return;
    end
    t_CC_eff = min(t_CC, dur);
    % fase de corriente constante
    E_CC = P_max * t_CC_eff / 3600;
    % fase de tension constante, si queda tiempo
    if dur > t_CC_eff
        tau = max((dur - t_CC_eff) / 3, 1);
        E_CV = P_max * tau * (1 - exp(-(dur - t_CC_eff) / tau)) / 3600;
    else
        E_CV = 0;
    end
    E = E_CC + E_CV;
end
