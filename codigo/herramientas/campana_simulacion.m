function T = campana_simulacion(version_ems, opciones)
% Lanza de una tirada todas las simulaciones de una version: cada dia tipo del
% ano contra cada semilla de demanda, y va guardando los KPIs de cada una. La
% misma semilla da siempre la misma demanda, asi que dos versiones se pueden
% comparar par a par. Ojo: no cambia el EMS, hay que haber pegado antes el .m
% correspondiente en el bloque de OASIS.slx; la etiqueta solo sirve para nombrar
% y agrupar los resultados. Se llama por ejemplo como
% campana_simulacion('C', struct('dias_sim', 7, 'semillas', 1:5)).

if nargin < 1 || isempty(version_ems), version_ems = 'sin_etiquetar'; end
if nargin < 2, opciones = struct(); end

% Escenarios: nombre, fecha, perfil de demanda y descripcion
ESCENARIOS = {
  'E1_lab_soleado',    '02-07-2025', 'laborable',   'Laborable, kt=1.00, precio plano 71-130 EUR/MWh'
  'E2_lab_nublado',    '11-02-2025', 'laborable',   'Laborable nublado kt=0.36, punta 194 EUR/MWh a las 20 h'
  'E3_finde_soleado',  '13-07-2025', 'findesemana', 'Domingo, irradiancia maxima del ano en finde, precio 0-4 a mediodia'
  'E4_volatilidad',    '17-09-2025', 'laborable',   'Mayor spread de 2025: 24 -> 252 EUR/MWh'
};

def = struct('semillas', 1:10, 'modelo', 'OASIS', 'factor_precio_export', 1.0, ...
             'generar_demanda_si_falta', true, 'opciones_demanda', struct(), ...
             'parar_si_error', false, 'dias_sim', 1, 'decimar_guardado', 1, ...
             'npar_pv', []);
def.escenarios = ESCENARIOS(:,1)';
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

% opciones desconocidas: aviso (los parametros de demanda van dentro de .opciones_demanda)
sobran = setdiff(fieldnames(opciones), campos);
if ~isempty(sobran)
    fprintf(2, '[CAMPANA] AVISO: opciones desconocidas, se IGNORAN: %s\n', strjoin(sobran', ', '));
    dem = {'factor_llegadas_EV','factor_llegadas_H2','N_postes_EV','N_postes_H2', ...
           'P_cargador_EV','Caudal_H2_surtidor','usar_datos_reales'};
    if any(ismember(sobran, dem))
        fprintf(2, ['            Los parametros de demanda van DENTRO de .opciones_demanda:\n' ...
            '            campana_simulacion(''X'', struct(''dias_sim'',7, ...\n' ...
            '                ''opciones_demanda'', struct(''factor_llegadas_EV'',1.5)))\n']);
    end
end

% Rutas del modelo y de los resultados
ruta_ems      = fileparts(mfilename('fullpath'));
ruta_raiz     = fullfile(ruta_ems, '..', '..');
ruta_modelo   = fullfile(ruta_raiz, 'SimugridElectrolinera');
ruta_preparar = fullfile(ruta_raiz, 'codigo', 'preparar');
ruta_cars     = fullfile(ruta_modelo, 'Datos', 'Cars');
addpath(ruta_modelo, ruta_ems, ruta_preparar);

if ~exist(fullfile(ruta_modelo, 'Datos', 'datos_OASIS.mat'), 'file')
    error(['Falta %s. Ejecuta primero codigo/preparar/preparar_workspace_simulink.m'], ...
        fullfile(ruta_modelo, 'Datos', 'datos_OASIS.mat'));
end

% Aviso de modo oraculo: se activa desde el workspace y no deja rastro en el
% nombre de los ficheros, asi que confundirlo con una tanda normal invalidaria
% la comparacion
oraculo_on = false;
if evalin('base', 'exist(''ORACULO'', ''var'')')
    oraculo_on = logical(evalin('base', 'ORACULO'));
end
if oraculo_on
    fprintf(['\n*** MODO ORACULO: los dos bloques de prevision entregan valores reales.\n' ...
        '    Esta tanda mide el techo del mecanismo. ***\n']);
    if isempty(strfind(lower(version_ems), 'oraculo')) %#ok<STREMP>
        warning(['[CAMPANA] ORACULO activo pero la etiqueta "%s" no lo dice. Usa una ' ...
            'etiqueta que lo mencione, o haz clear ORACULO.'], version_ems);
    end
elseif ~isempty(strfind(lower(version_ems), 'oraculo')) %#ok<STREMP>
    warning(['[CAMPANA] La etiqueta "%s" dice oraculo pero ORACULO no esta activo ' ...
        'en el workspace base: esta tanda usaria las predicciones normales.'], version_ems);
end

% Horizonte: un dia o varios seguidos. Con varios, el escenario deja de ser
% "este dia" y pasa a ser "la semana que empieza este dia", y el tipo de cada
% dia lo fija el calendario real
dias_sim = max(1, round(opciones.dias_sim));
stop_s   = dias_sim * 86400;

modelo = opciones.modelo;
if ~bdIsLoaded(modelo), load_system(modelo); end
set_param(modelo, 'StopTime', num2str(stop_s));

if dias_sim > 1
    fprintf(['\n[CAMPANA] Horizonte de %d dias seguidos (%d s por simulacion). ' ...
        'Cada simulacion tarda del orden de %d veces lo que una de 24 h.\n'], ...
        dias_sim, stop_s, dias_sim);
    if opciones.decimar_guardado <= 1
        fprintf(2, ['[CAMPANA] AVISO: decimar_guardado = 1 con %d dias -> unos %d MB ' ...
            'por .mat. Usa opciones.decimar_guardado = 10 salvo que necesites ' ...
            'la senal a 1 s.\n'], dias_sim, round(4*dias_sim));
    end
end

% Tamano del campo fotovoltaico
% npar = cadenas en paralelo del bloque "Solar - Irradiance"; se restaura al salir.
bloque_pv = [modelo '/Solar - Irradiance'];
try
    npar_base = get_param(bloque_pv, 'npar');
catch
    npar_base = '';
end
if isempty(npar_base)
    if ~isempty(opciones.npar_pv)
        error('No encuentro el parametro npar en el bloque %s.', bloque_pv);
    end
elseif ~isempty(opciones.npar_pv)
    set_param(bloque_pv, 'npar', num2str(opciones.npar_pv));
    restaurar_pv = onCleanup(@() set_param(bloque_pv, 'npar', npar_base)); %#ok<NASGU>
    fprintf('\n[CAMPANA] Campo fotovoltaico: npar %s -> %d cadenas en paralelo (x%.2f)\n', ...
        npar_base, opciones.npar_pv, opciones.npar_pv / str2double(npar_base));
    if isempty(strfind(lower(version_ems), 'pv')) %#ok<STREMP>
        warning('[CAMPANA] Campo ampliado pero la etiqueta "%s" no lo dice.', version_ems);
    end
elseif ~isempty(strfind(lower(version_ems), 'pv')) %#ok<STREMP>
    warning('[CAMPANA] La etiqueta "%s" dice pv pero no hay npar_pv: campo base (npar = %s).', ...
        version_ems, npar_base);
end

% Aviso de resultados previos con la misma etiqueta, que desequilibran el pareado
ruta_res = fullfile(ruta_raiz, 'codigo', 'resultados');
previos = dir(fullfile(ruta_res, [version_ems '_E*.mat']));
if ~isempty(previos)
    fprintf(2, ['\n[CAMPANA] AVISO: ya hay %d resultados con la etiqueta "%s". Esta\n' ...
        '          tanda se suma a ellos y el pareado saldra mal ponderado.\n' ...
        '          Para relanzar: delete(fullfile(''%s'', ''%s_E*.mat''))\n'], ...
        numel(previos), version_ems, ruta_res, version_ems);
end

filas = {};
n_total = numel(opciones.escenarios) * numel(opciones.semillas);
n = 0;
t_campana = tic;

for ie = 1:numel(opciones.escenarios)
    nombre_esc = opciones.escenarios{ie};
    ke = find(strcmp(ESCENARIOS(:,1), nombre_esc), 1);
    if isempty(ke)
        warning('Escenario desconocido: %s (se omite)', nombre_esc);
        continue;
    end
    fecha_esc = ESCENARIOS{ke,2};
    modo_esc  = ESCENARIOS{ke,3};

    for is = 1:numel(opciones.semillas)
        semilla = opciones.semillas(is);
        n = n + 1;
        fprintf('\n===== [%d/%d] EMS %s | %s | %s | semilla %d =====\n', ...
            n, n_total, version_ems, nombre_esc, fecha_esc, semilla);

        % 1) perfil de demanda de esa semilla; con varios dias no se usa, los
        %    construye init_OASIS con semillas derivadas
        f_ev = fullfile(ruta_cars, sprintf('perfil_EV_s%d.mat', semilla));
        if dias_sim > 1
            % nada que hacer aqui
        elseif ~exist(f_ev, 'file')
            if opciones.generar_demanda_si_falta
                fprintf('  Generando perfil de demanda de la semilla %d...\n', semilla);
                Demanda_Coches_Aleatoria(semilla, opciones.opciones_demanda);
            else
                warning('No existe %s y generar_demanda_si_falta=false. Se omite.', f_ev);
                continue;
            end
        end

        % 2) init_OASIS va en el workspace base, que es de donde leen los
        %    bloques From Workspace del modelo
        assignin('base', 'fecha_sim',   fecha_esc);
        assignin('base', 'modo_ev_sel', modo_esc);
        assignin('base', 'semilla_sim', semilla);
        assignin('base', 'dias_sim_sel', dias_sim);
        if isempty(fieldnames(opciones.opciones_demanda))
            evalin('base', 'clear opciones_demanda_sim');
        else
            assignin('base', 'opciones_demanda_sim', opciones.opciones_demanda);
        end

        try
            evalin('base', 'init_OASIS;');
            t_sim = tic;
            out = sim(modelo);
            seg = toc(t_sim);
            fprintf('  Simulacion terminada en %.1f s\n', seg);

            opc = struct('factor_precio_export', opciones.factor_precio_export, ...
                         'guardar', true, 'fecha', fecha_esc, ...
                         'semilla', semilla, 'verbose', true, ...
                         'decimar_guardado', opciones.decimar_guardado, ...
                         'dias_sim', dias_sim);
            r = guardar_resultados_ems(out, version_ems, nombre_esc, opc);

            % el struct de KPI va envuelto en cell o cell2table lo convierte en
            % un array de structs y luego falla el acceso con llaves
            filas(end+1, :) = {version_ems, nombre_esc, fecha_esc, modo_esc, semilla, ...
                seg, {r.kpi}, ''}; %#ok<AGROW>
        catch ME
            fprintf(2, '  ERROR: %s\n', ME.message);
            filas(end+1, :) = {version_ems, nombre_esc, fecha_esc, modo_esc, semilla, ...
                NaN, {struct()}, ME.message}; %#ok<AGROW>
            if opciones.parar_si_error, rethrow(ME); end
        end
    end
end

fprintf('\nCampana terminada: %d simulaciones en %.1f min\n', size(filas,1), toc(t_campana)/60);

% Limpia las variables de control del workspace base: si dias_sim_sel se quedase
% puesto, la siguiente ejecucion manual simularia una semana sin avisar
evalin('base', 'clear dias_sim_sel dias_sim opciones_demanda_sim');

% Tabla resumen de la campana
if isempty(filas)
    T = table();
    return;
end
T = cell2table(filas, 'VariableNames', ...
    {'Version','Escenario','Fecha','Perfil','Semilla','Segundos','KPI','Error'});

% Aviso si alguna simulacion no cerro el balance
malos = 0;
for i = 1:height(T)
    if iscell(T.KPI), k = T.KPI{i}; else, k = T.KPI(i); end
    if isstruct(k) && isfield(k, 'balance_pct') && k.balance_pct > 3
        malos = malos + 1;
    end
end
if malos > 0
    fprintf(2, ['ATENCION: %d de %d simulaciones no cierran el balance electrico. ' ...
        'Revisa signos/unidades antes de usar estos resultados.\n'], malos, height(T));
end

fprintf('Usa resumen_campana() para construir la tabla media +/- desviacion.\n');

end
