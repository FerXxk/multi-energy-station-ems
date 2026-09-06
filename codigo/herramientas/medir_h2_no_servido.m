function T = medir_h2_no_servido(opciones)
% Mide cuanto hidrogeno se despacho con el tanque de alta ya vacio, que es la
% demanda que en la practica no se habria podido servir: el modelo deja que el
% inventario baje de cero en vez de cortar el suministro. Lee los resultados ya
% guardados en disco, no vuelve a simular, y da por simulacion el deficit maximo,
% los kilos servidos en vacio y lo que suponen sobre la demanda total. Admite
% filtrar por fecha, por ejemplo medir_h2_no_servido(struct('desde','20260902_000000')).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
def = struct('carpeta', fullfile(ruta_ems, '..', 'resultados'), 'desde', '');
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

RHO_H2_N = 0.08988;   % kg/Nm3 en condiciones normales
archivos = dir(fullfile(opciones.carpeta, '*.mat'));
filas = {};

for k = 1:numel(archivos)
    nombre = archivos(k).name;
    if ~isempty(regexp(nombre, '^(metricas|campana|ablacion)', 'once')), continue; end
    if ~isempty(opciones.desde)
        tok = regexp(nombre, '_(\d{8}_\d{6})\.mat$', 'tokens', 'once');
        if ~isempty(tok)
            a = str2double(strrep(tok{1}, '_', ''));
            b = str2double(strrep(opciones.desde, '_', ''));
            if ~isnan(a) && ~isnan(b) && a < b, continue; end
        end
    end
    try
        S = load(fullfile(opciones.carpeta, nombre));
    catch
        continue;
    end
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if ~isfield(r, 'kg_tanque_high') || ~isfield(r, 't_horas'), continue; end

    t   = double(r.t_horas(:)) * 3600;
    inv = double(r.kg_tanque_high(:));
    if numel(inv) ~= numel(t) || all(isnan(inv)), continue; end

    % el campo del caudal de demanda cambio de nombre: se aceptan los dos
    q = [];
    if isfield(r, 'Dem_H2_nl'), q = double(r.Dem_H2_nl(:));
    elseif isfield(r, 'Dem_H2'), q = double(r.Dem_H2(:)); end

    deficit_max = max(0, -min(inv));

    kg_vacio = 0; pct = NaN; kg_dem_total = NaN;
    if ~isempty(q) && numel(q) == numel(t)
        q(isnan(q)) = 0;
        kg_dem_total = trapz(t, q * 1e-3 / 60 * RHO_H2_N);
        vacio = inv <= 0;
        if any(vacio)
            q_v = q; q_v(~vacio) = 0;
            kg_vacio = trapz(t, q_v * 1e-3 / 60 * RHO_H2_N);
        end
        if kg_dem_total > 0, pct = 100 * kg_vacio / kg_dem_total; end
    end

    filas(end+1, :) = {r.version_ems, r.escenario, r.semilla, ...
        min(inv), deficit_max, kg_vacio, kg_dem_total, pct}; %#ok<AGROW>
end

if isempty(filas)
    error('No se ha podido leer ningun resultado con inventario de tanque.');
end

T = cell2table(filas, 'VariableNames', {'Version','Escenario','Semilla', ...
    'inv_min_kg','deficit_max_kg','kg_en_vacio','kg_dem_total','pct_de_demanda'});

fprintf('Analizadas %d simulaciones\n\n', height(T));
vers = unique(T.Version);
fprintf('%-14s %6s %8s %14s %14s %12s\n', 'Version', 'n', 'n<0', ...
    'deficit_max', 'kg_en_vacio', '%% demanda');
for iv = 1:numel(vers)
    s = strcmp(T.Version, vers{iv});
    fprintf('%-14s %6d %8d %14.3f %14.3f %12.3f\n', vers{iv}, sum(s), ...
        sum(T.inv_min_kg(s) < 0), max(T.deficit_max_kg(s)), ...
        sum(T.kg_en_vacio(s)), mean(T.pct_de_demanda(s), 'omitnan'));
end
fprintf(['\n"n<0" = simulaciones en que el inventario se hizo negativo.\n' ...
    '"deficit_max" = peor deficit instantaneo de la version (kg).\n' ...
    '"kg_en_vacio" = H2 dispensado con el tanque vacio, SUMADO sobre la version.\n']);

peor = T(T.inv_min_kg < 0, :);
if ~isempty(peor)
    fprintf('\nSimulaciones afectadas:\n');
    disp(sortrows(peor, 'inv_min_kg'));
end
end
