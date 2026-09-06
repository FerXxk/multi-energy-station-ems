function [T_par, T_agg] = analisis_ablacion(opciones)
% Compara cada version con una de referencia emparejando simulaciones que
% comparten dia y semilla, que es la unica forma de que la diferencia no sea
% ruido del escenario. De cada KPI da la media y la mediana de la diferencia, en
% cuantos pares gana, y dos contrastes: el t-test pareado y el de Wilcoxon, que
% es el que hay que citar porque el promedio lo suelen mandar unas pocas
% semillas. Solo empareja tandas del mismo numero de dias. Se elige la referencia,
% por ejemplo analisis_ablacion(struct('referencia', 'A_semana')).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
def = struct('carpeta', fullfile(ruta_ems, '..', 'resultados'), ...
             'desde', '', 'referencia', 'A', 'guardar', true);
def.kpis = {'Coste_Neto', 'Coste_corregido', 'Coste_total_H2', 'V_terminal', ...
            'E_Import_Red', 'E_Export_Red', 'Autarquia_pct', ...
            'Autoconsumo_pct', 'coste_H2_kg', 'kg_H2_EL', 'E_Comp', ...
            't_run_El_pct', 'Conmutaciones_El', 'LOH_High_media', ...
            'LOH_High_min', 'pct_tiempo_critico'};
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

%% 1. Cargar todos los resultados
archivos = dir(fullfile(opciones.carpeta, '*.mat'));
if isempty(archivos)
    error('No hay resultados en %s.', opciones.carpeta);
end

reg = struct('version', {}, 'escenario', {}, 'semilla', {}, 'kpi', {}, 'sello', {}, 'dias', {});
n_desc = 0;
for k = 1:numel(archivos)
    nombre = archivos(k).name;
    if ~isempty(regexp(nombre, '^(metricas|campana)', 'once')), continue; end
    try
        S = load(fullfile(opciones.carpeta, nombre));
    catch
        continue;
    end
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if ~isfield(r, 'kpi') || isempty(fieldnames(r.kpi)), continue; end

    sello = '';
    tok = regexp(nombre, '_(\d{8}_\d{6})\.mat$', 'tokens', 'once');
    if ~isempty(tok), sello = tok{1}; end
    if ~isempty(opciones.desde) && ~isempty(sello)
        % comparacion numerica del sello de fecha, no de cadenas
        n_sello = str2double(strrep(sello, '_', ''));
        n_desde = str2double(strrep(opciones.desde, '_', ''));
        if ~isnan(n_sello) && ~isnan(n_desde) && n_sello < n_desde
            n_desc = n_desc + 1;
            continue;
        end
    end

    % horizonte (dias_sim); los .mat sin el campo son de 24 h
    dias = 1;
    if isfield(r, 'dias_sim') && ~isempty(r.dias_sim), dias = double(r.dias_sim); end

    reg(end+1) = struct('version', r.version_ems, 'escenario', r.escenario, ...
        'semilla', r.semilla, 'kpi', r.kpi, 'sello', sello, 'dias', dias); %#ok<AGROW>
end

if isempty(reg)
    error('No se ha podido leer ningun resultado utilizable.');
end
fprintf('Leidas %d simulaciones', numel(reg));
if n_desc > 0
    fprintf(' (%d descartadas por ser anteriores a %s)', n_desc, opciones.desde);
end
fprintf('\n');

versiones = unique({reg.version});
fprintf('Versiones encontradas: %s\n', strjoin(versiones, ', '));
ref = opciones.referencia;
if ~any(strcmp(versiones, ref))
    error('No hay resultados de la version de referencia "%s".', ref);
end

%% 1b. Solo se comparan tandas con el mismo numero de dias que la referencia
dias_ref = unique([reg(strcmp({reg.version}, ref)).dias]);
if numel(dias_ref) > 1
    error(['La version de referencia "%s" mezcla horizontes (%s dias). ' ...
        'Separa las tandas o usa etiquetas distintas.'], ref, mat2str(dias_ref));
end
compat = [reg.dias] == dias_ref;
if ~all(compat)
    fuera = unique({reg(~compat).version});
    fprintf(['[HORIZONTE] La referencia "%s" es de %d dia(s). Se excluyen %d ' ...
        'simulaciones de otro horizonte: %s\n'], ref, dias_ref, sum(~compat), ...
        strjoin(fuera, ', '));
    reg = reg(compat);
    versiones = unique({reg.version});
end
fprintf('Comparando sobre horizonte de %d dia(s): %s\n', dias_ref, strjoin(versiones, ', '));

%% 2. Comprobaciones de sanidad antes de comparar nada
fprintf('\n--- Sanidad ---\n');
for iv = 1:numel(versiones)
    sel = strcmp({reg.version}, versiones{iv});
    bal = leer_kpi(reg(sel), 'balance_pct');
    neg = leer_kpi(reg(sel), 'pct_tiempo_LOH_negativo');
    fprintf('%-14s n=%3d | balance max %.2e %% | LOH<0 en %d sims (max %.2f %% del tiempo)\n', ...
        versiones{iv}, sum(sel), max(bal), sum(neg > 0), max([neg, 0]));
end

%% 2b. Recuento por escenario, para detectar tandas duplicadas
escs_ref = unique({reg(strcmp({reg.version}, ref)).escenario});
hay_desigual = false;
for iv = 1:numel(versiones)
    v = versiones{iv};
    for ie = 1:numel(escs_ref)
        n_ref = sum(strcmp({reg.version}, ref) & strcmp({reg.escenario}, escs_ref{ie}));
        n_v   = sum(strcmp({reg.version}, v)   & strcmp({reg.escenario}, escs_ref{ie}));
        if n_v > 0 && n_v ~= n_ref
            fprintf(2, ['[RECUENTO] "%s" tiene %d simulaciones en %s y la referencia ' ...
                '"%s" tiene %d. Hay tiradas duplicadas o faltantes.\n'], ...
                v, n_v, escs_ref{ie}, ref, n_ref);
            hay_desigual = true;
        end
    end
end
if hay_desigual
    fprintf(2, ['[RECUENTO] >> La fila TODOS queda mal ponderada; las de cada ' ...
        'escenario siguen valiendo.\n' ...
        '            Borra las tiradas sobrantes o relanza la campana entera.\n']);
end

%% 3. Comparacion pareada contra la referencia
filas = {};
for iv = 1:numel(versiones)
    v = versiones{iv};
    if strcmp(v, ref), continue; end
    escs = unique({reg(strcmp({reg.version}, v)).escenario});
    for ie = 1:numel(escs)
        for ik = 1:numel(opciones.kpis)
            [a, b, sem] = emparejar(reg, ref, v, escs{ie}, opciones.kpis{ik});
            if isempty(a), continue; end
            filas(end+1, :) = resumir(v, escs{ie}, opciones.kpis{ik}, a, b, sem); %#ok<AGROW>
        end
    end
    % agregado sobre todos los escenarios
    for ik = 1:numel(opciones.kpis)
        [a, b, sem] = emparejar(reg, ref, v, '', opciones.kpis{ik});
        if isempty(a), continue; end
        filas(end+1, :) = resumir(v, 'TODOS', opciones.kpis{ik}, a, b, sem); %#ok<AGROW>
    end
end

if isempty(filas)
    warning('Solo hay resultados de la version de referencia: nada que comparar.');
    T_par = table(); T_agg = table();
    return;
end

T_par = cell2table(filas, 'VariableNames', {'Version','Escenario','KPI','N', ...
    'Ref_media','Ver_media','Dif','Dif_mediana','Dif_pct','Gana_ver','p_t','p_rank'});
T_agg = T_par(strcmp(T_par.Escenario, 'TODOS'), :);

%% 4. Impresion legible del agregado
fprintf('\n=== COMPARACION PAREADA CONTRA LA VERSION %s (agregado) ===\n', ref);
for iv = 1:numel(versiones)
    v = versiones{iv};
    if strcmp(v, ref), continue; end
    sub = T_agg(strcmp(T_agg.Version, v), :);
    if isempty(sub), continue; end
    fprintf('\n--- %s  (n = %d pares) ---\n', v, sub.N(1));
    fprintf('%-20s %9s %9s %9s %9s %7s %8s %9s %9s\n', 'KPI', ref, v, ...
        'dif', 'mediana', 'dif %', 'gana', 'p_t', 'p_rank');
    for j = 1:height(sub)
        fprintf('%-20s %9.2f %9.2f %+9.2f %+9.2f %+6.1f%% %5d/%-2d %9.3g %9.3g\n', ...
            sub.KPI{j}, sub.Ref_media(j), sub.Ver_media(j), sub.Dif(j), ...
            sub.Dif_mediana(j), sub.Dif_pct(j), sub.Gana_ver(j), sub.N(j), ...
            sub.p_t(j), sub.p_rank(j));
    end
end
fprintf(['\n"gana" = en cuantas semillas la version es mejor que %s.\n' ...
    'p_t     t-test pareado, solo valido si "dif" y "mediana" se parecen.\n' ...
    'p_rank  Wilcoxon de rangos con signo, que es el que hay que citar.\n' ...
    'Si "dif" y "mediana" difieren mucho, el promedio lo mandan pocas semillas.\n'], ref);

%% 4b. Desglose por escenario
% esta es la tabla que se publica, no la agregada
kpis_desglose = intersect(opciones.kpis, ...
    {'Coste_Neto','Coste_corregido','Coste_total_H2'}, 'stable');
if ~isempty(kpis_desglose) && numel(escs_ref) > 1
    fprintf('\n\n=== DESGLOSE POR ESCENARIO ===\n');
    fprintf('Cada celda: media (mediana) [en cuantas semillas gana]\n');
    for ik = 1:numel(kpis_desglose)
        campo = kpis_desglose{ik};
        fprintf('\n--- %s ---\n', campo);
        fprintf('%-22s', 'Version');
        for ie = 1:numel(escs_ref), fprintf(' %-19s', escs_ref{ie}); end
        fprintf('\n');
        for iv = 1:numel(versiones)
            v = versiones{iv};
            if strcmp(v, ref), continue; end
            fprintf('%-22s', v);
            for ie = 1:numel(escs_ref)
                f = strcmp(T_par.Version, v) & strcmp(T_par.Escenario, escs_ref{ie}) ...
                    & strcmp(T_par.KPI, campo);
                if any(f)
                    j = find(f, 1);
                    fprintf(' %+7.2f (%+6.2f)[%2d]', T_par.Dif(j), ...
                        T_par.Dif_mediana(j), T_par.Gana_ver(j));
                else
                    fprintf(' %-19s', '--');
                end
            end
            fprintf('\n');
        end
    end
    fprintf(['\nSi una columna concentra el efecto y las demas salen a cero, la version\n' ...
        'solo actua en ese escenario, y asi hay que contarlo.\n']);
end

%% 5. Guardado
if opciones.guardar
    sello = datestr(now, 'yyyymmdd_HHMMSS');
    f1 = fullfile(opciones.carpeta, sprintf('ablacion_detalle_%s.csv', sello));
    f2 = fullfile(opciones.carpeta, sprintf('ablacion_agregado_%s.csv', sello));
    writetable(T_par, f1);
    writetable(T_agg, f2);
    fprintf('\nGuardado:\n  %s\n  %s\n', f1, f2);
end

end

% =======================================================================
function v = leer_kpi(reg, campo)
v = nan(1, numel(reg));
for k = 1:numel(reg)
    if isfield(reg(k).kpi, campo)
        x = reg(k).kpi.(campo);
        if isscalar(x) && isnumeric(x), v(k) = double(x); end
    end
end
v = v(~isnan(v));
if isempty(v), v = NaN; end
end

% =======================================================================
function [a, b, sem] = emparejar(reg, ref, ver, escenario, campo)
% Devuelve los vectores de la referencia (a) y de la version (b) emparejados
% por escenario+semilla. Si escenario esta vacio, empareja sobre todos.
a = []; b = []; sem = {};
if isempty(escenario)
    escs = unique({reg(strcmp({reg.version}, ver)).escenario});
else
    escs = {escenario};
end
for ie = 1:numel(escs)
    iA = find(strcmp({reg.version}, ref) & strcmp({reg.escenario}, escs{ie}));
    iB = find(strcmp({reg.version}, ver) & strcmp({reg.escenario}, escs{ie}));
    for p = 1:numel(iB)
        s = reg(iB(p)).semilla;
        q = [];
        for w = 1:numel(iA)
            if isequal(reg(iA(w)).semilla, s), q = iA(w); break; end
        end
        if isempty(q), continue; end
        if ~isfield(reg(q).kpi, campo) || ~isfield(reg(iB(p)).kpi, campo), continue; end
        va = reg(q).kpi.(campo);
        vb = reg(iB(p)).kpi.(campo);
        if ~isscalar(va) || ~isscalar(vb) || ~isnumeric(va) || ~isnumeric(vb), continue; end
        if isnan(va) || isnan(vb), continue; end
        a(end+1) = double(va); %#ok<AGROW>
        b(end+1) = double(vb); %#ok<AGROW>
        sem{end+1} = sprintf('%s_s%d', escs{ie}, s); %#ok<AGROW>
    end
end
end

% =======================================================================
function fila = resumir(ver, esc, campo, a, b, sem) %#ok<INUSD>
d = b - a;
n = numel(d);

% t-test pareado, que se conserva pero no es el que se cita
p_t = NaN;
if n > 1 && std(d) > 0
    t = mean(d) / (std(d) / sqrt(n));
    if exist('tcdf', 'file') == 2
        p_t = 2 * (1 - tcdf(abs(t), n - 1));
    else
        p_t = erfc(abs(t) / sqrt(2));   % aproximacion normal, sin toolbox
    end
elseif n > 1
    p_t = 1;   % diferencia identicamente nula
end

% Wilcoxon de rangos con signo, el que se cita
p_r = p_signrank(d);

% KPI en los que menor es mejor y en los que mayor es mejor; los que no tienen
% un sentido claro se quedan fuera
menor_mejor = {'Coste_Neto','E_Import_Red','coste_H2_kg','Conmutaciones_El', ...
               'pct_tiempo_critico','E_Comp','coste_energia_H2', ...
               'Coste_corregido','Coste_total_H2','Coste_H2_deficit', ...
               'kg_H2_no_servido'};
mayor_mejor = {'Autarquia_pct','Autoconsumo_pct','kg_H2_EL','LOH_High_media', ...
               'LOH_High_min','V_terminal'};
gana = NaN;
if any(strcmp(campo, menor_mejor))
    gana = sum(d < 0);
elseif any(strcmp(campo, mayor_mejor))
    gana = sum(d > 0);
end

pct = NaN;
if mean(a) ~= 0
    pct = 100 * mean(d) / abs(mean(a));
end

fila = {ver, esc, campo, n, mean(a), mean(b), mean(d), median(d), pct, gana, p_t, p_r};
end

% =======================================================================
function p = p_signrank(d)
% Wilcoxon de rangos con signo por aproximacion normal, sin necesitar toolbox
%
% contesta en cuantas semillas es mejor y por cuanto, no cuanto vale la media
d = d(:);
d = d(isfinite(d) & d ~= 0);
n = numel(d);
p = NaN;
if n < 6, return; end          % por debajo de 6 pares la aproximacion no vale

ad = abs(d);
[~, orden] = sort(ad);
r = zeros(n, 1);
r(orden) = 1:n;

% empates: rango promedio y su correccion en la varianza
u = unique(ad);
emp = zeros(numel(u), 1);
for k = 1:numel(u)
    m = (ad == u(k));
    emp(k) = sum(m);
    if emp(k) > 1, r(m) = mean(r(m)); end
end

W  = sum(r(d > 0));
mu = n * (n + 1) / 4;
vW = n*(n+1)*(2*n+1)/24 - sum(emp.^3 - emp) / 48;
if vW <= 0, p = 1; return; end

z = (abs(W - mu) - 0.5) / sqrt(vW);    % correccion por continuidad
z = max(z, 0);
p = erfc(z / sqrt(2));
p = min(1, max(0, p));
end
