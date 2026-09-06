function [T_detalle, T_resumen] = resumen_campana(opciones)
% Junta todos los .mat que ha dejado la campana en una tabla con una fila por
% simulacion y otra tabla agregada por version y escenario, con media, desviacion
% tipica e intervalo de confianza del 95 %. Las dos se guardan en CSV, que es el
% formato con el que luego se trabaja. Se le puede decir que KPI mirar, por
% ejemplo resumen_campana(struct('kpis', {{'Coste_Neto','coste_H2_kg'}})).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
def = struct('carpeta', fullfile(ruta_ems, '..', 'resultados'), ...
             'patron', '*.mat', 'guardar', true);
def.kpis = {'Coste_Neto', 'coste_H2_kg', 'Autoconsumo_pct', 'Autarquia_pct', ...
            'E_Import_Red', 'E_Export_Red', 'E_Comp', 'kg_H2_EL', 'kg_H2_Dem', ...
            'Conmutaciones_El', 'Conmutaciones_FC', 'LOH_High_media', ...
            'LOH_High_min', 'pct_tiempo_critico', 'pct_tiempo_LOH_negativo', ...
            'mae_prevision_precio', 'balance_pct', ...
            't_run_El_pct', 'E_Bat_carga', 'E_Bat_desc', 'coste_energia_H2', ...
            'Coste_Import', 'Ingreso_Export', 'precio_medio_import', ...
            'dSOC_pct', 'd_kg_H2_high', 'd_kg_H2_low', 'dias_sim', ...
            'dE_bat_kWh', 'precio_valoracion', 'V_terminal', 'Coste_corregido', ...
            'kg_H2_no_servido', 'Coste_H2_deficit', 'Coste_total_H2', ...
            'kg_H2_high_ini', 'kg_H2_high_fin', 'LOH_High_fin', 'bar_H2_high_fin', ...
            'valor_H2_rem', 'valor_bat_rem', 'SOC_fin_pct'};
% importacion y exportacion van por separado porque el neto es la resta de las dos
% y la exportacion, comun a todas las versiones, tapa las diferencias de compra
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

archivos = dir(fullfile(opciones.carpeta, opciones.patron));
if isempty(archivos)
    error('No hay resultados en %s. Lanza antes campana_simulacion.', opciones.carpeta);
end

filas = {};
for i = 1:numel(archivos)
    S = load(fullfile(opciones.carpeta, archivos(i).name));
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if ~isfield(r, 'kpi'), continue; end
    semilla = NaN;
    if isfield(r, 'semilla') && ~isempty(r.semilla), semilla = r.semilla; end
    fecha = '';
    if isfield(r, 'fecha'), fecha = r.fecha; end
    fila = {r.version_ems, r.escenario, fecha, semilla, archivos(i).name};
    for j = 1:numel(opciones.kpis)
        c = opciones.kpis{j};
        if isfield(r.kpi, c) && ~isempty(r.kpi.(c))
            fila{end+1} = double(r.kpi.(c)); %#ok<AGROW>
        else
            fila{end+1} = NaN; %#ok<AGROW>
        end
    end
    filas(end+1, :) = fila; %#ok<AGROW>
end

if isempty(filas)
    error('Se han encontrado %d .mat pero ninguno con el struct ''resultados''.', numel(archivos));
end

nombres = [{'Version','Escenario','Fecha','Semilla','Archivo'}, opciones.kpis];
T_detalle = cell2table(filas, 'VariableNames', nombres);
T_detalle = sortrows(T_detalle, {'Escenario','Version','Semilla'});

% agregado por version y escenario
claves = strcat(T_detalle.Version, '|', T_detalle.Escenario);
[u, ~, g] = unique(claves);
filas_r = {};
for k = 1:numel(u)
    partes = strsplit(u{k}, '|');
    idx = (g == k);
    fila = {partes{1}, partes{2}, sum(idx)};
    for j = 1:numel(opciones.kpis)
        v = T_detalle.(opciones.kpis{j})(idx);
        v = v(~isnan(v));
        nv = numel(v);
        m = mean(v);
        s = std(v);
        if nv > 1
            try
                tcrit = tinv(0.975, nv-1);
            catch
                tcrit = 1.96;
            end
            ic = tcrit * s / sqrt(nv);
        else
            ic = NaN;
        end
        fila = [fila, {m, s, ic}]; %#ok<AGROW>
    end
    filas_r(end+1, :) = fila; %#ok<AGROW>
end

nombres_r = {'Version','Escenario','N'};
for j = 1:numel(opciones.kpis)
    c = opciones.kpis{j};
    nombres_r = [nombres_r, {[c '_media'], [c '_std'], [c '_ic95']}]; %#ok<AGROW>
end
T_resumen = cell2table(filas_r, 'VariableNames', nombres_r);
T_resumen = sortrows(T_resumen, {'Escenario','Version'});

fprintf('\n%d simulaciones agregadas en %d combinaciones version x escenario.\n', ...
    height(T_detalle), height(T_resumen));

% vista rapida por pantalla de los tres KPI principales
fprintf('\n%-10s %-20s %3s %14s %14s %12s\n', 'Version','Escenario','N', ...
    'Coste (EUR)','H2 (EUR/kg)','Autoc. (%)');
for i = 1:height(T_resumen)
    fprintf('%-10s %-20s %3d %7.2f+/-%-5.2f %7.2f+/-%-5.2f %6.1f+/-%-4.1f\n', ...
        T_resumen.Version{i}, T_resumen.Escenario{i}, T_resumen.N(i), ...
        T_resumen.Coste_Neto_media(i), T_resumen.Coste_Neto_ic95(i), ...
        T_resumen.coste_H2_kg_media(i), T_resumen.coste_H2_kg_ic95(i), ...
        T_resumen.Autoconsumo_pct_media(i), T_resumen.Autoconsumo_pct_ic95(i));
end

if opciones.guardar
    sello = datestr(now, 'yyyymmdd_HHMMSS');
    f1 = fullfile(opciones.carpeta, sprintf('campana_detalle_%s.csv', sello));
    f2 = fullfile(opciones.carpeta, sprintf('campana_resumen_%s.csv', sello));
    writetable(T_detalle, f1);
    writetable(T_resumen, f2);
    fprintf('\nCSV guardados:\n  %s\n  %s\n', f1, f2);
end

end
