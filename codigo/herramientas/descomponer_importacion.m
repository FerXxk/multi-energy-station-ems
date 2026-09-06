function T = descomponer_importacion(opciones)
% Contesta a en que se gasta el dinero de la factura de luz de cada version.
% Sobre los resultados ya guardados, separa la energia que se compra teniendo
% excedente de la que se compra sin tenerlo, reparte cada kWh comprado entre
% quien lo consumia en ese momento (coches, electrolizador, compresor o bateria)
% y calcula a que precio medio sale cada cosa. Se puede limitar a unas versiones,
% por ejemplo descomponer_importacion(struct('versiones', {{'A','E'}})).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
def = struct('carpeta', fullfile(ruta_ems, '..', 'resultados'), 'eta', 0.90);
def.versiones = {};
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

archivos = dir(fullfile(opciones.carpeta, '*.mat'));
filas = {};
for k = 1:numel(archivos)
    if ~isempty(regexp(archivos(k).name, '^(metricas|campana|ablacion)', 'once')), continue; end
    try, S = load(fullfile(opciones.carpeta, archivos(k).name)); catch, continue; end
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if ~isfield(r, 'P_Grid') || ~isfield(r, 'P_PV'), continue; end
    if ~isempty(opciones.versiones) && ~any(strcmp(r.version_ems, opciones.versiones)), continue; end

    th  = double(r.t_horas(:));
    pv  = double(r.P_PV(:));   ev = double(r.P_EV(:));
    gr  = double(r.P_Grid(:)); pr = double(r.Precio(:));
    el  = double(r.P_El(:));   bat = double(r.P_Bat(:));
    co  = double(r.P_Comp(:)); co(isnan(co)) = 0;

    exc = pv - ev;
    imp = max(gr, 0);  exp_ = abs(min(gr, 0));

    Ei = trapz(th, imp);  Ee = trapz(th, exp_);
    Ci = trapz(th, imp .* pr / 1000);
    Ie = trapz(th, exp_ .* pr / 1000);

    Ei_exc = trapz(th, imp .* (exc > 0));
    Ei_def = trapz(th, imp .* (exc <= 0));

    % cada kWh comprado se reparte entre quien lo consumia en ese instante
    carga_bat = abs(min(bat, 0));
    consumos  = [ev, el, co, carga_bat];
    total_c   = sum(consumos, 2);
    w = zeros(size(consumos));
    ok = total_c > 1e-9;
    w(ok, :) = consumos(ok, :) ./ total_c(ok);
    dest = zeros(1, 4);
    for j = 1:4
        dest(j) = trapz(th, imp .* w(:, j));
    end

    p_imp = NaN; if Ei > 1e-9, p_imp = Ci / Ei * 1000; end
    p_exp = NaN; if Ee > 1e-9, p_exp = Ie / Ee * 1000; end

    % coste (EUR) y precio ponderado (EUR/MWh) de la importacion que va al electrolizador
    Ci_EL    = trapz(th, imp .* w(:, 2) .* pr / 1000);
    p_imp_EL = NaN; if dest(2) > 1e-9, p_imp_EL = Ci_EL / dest(2) * 1000; end

    filas(end+1, :) = {r.version_ems, r.escenario, r.semilla, Ei, Ei_exc, Ei_def, ...
        dest(1), dest(2), dest(3), dest(4), Ee, Ci, Ie, p_imp, p_exp, Ci_EL, p_imp_EL}; %#ok<AGROW>
end
if isempty(filas), error('No se ha podido leer ningun resultado con P_Grid.'); end

T = cell2table(filas, 'VariableNames', {'Version','Escenario','Semilla', ...
    'E_imp','E_imp_con_excedente','E_imp_en_deficit', ...
    'imp_a_EV','imp_a_EL','imp_a_Comp','imp_a_Bateria', ...
    'E_exp','Coste_Import','Ingreso_Export','p_imp','p_exp', ...
    'Coste_imp_EL','p_imp_EL'});

vers = unique(T.Version);

fprintf('\n=== A QUE PRECIO COMPRA EL ELECTROLIZADOR (ponderado por energia) ===\n');
fprintf('%-22s %10s %10s %10s %10s\n', 'Version', 'kWh a EL', 'EUR a EL', 'p_imp_EL', 'p_imp');
for iv = 1:numel(vers)
    s = strcmp(T.Version, vers{iv});
    E_el = sum(T.imp_a_EL(s));  C_el = sum(T.Coste_imp_EL(s));
    p_el = NaN; if E_el > 1e-9, p_el = C_el / E_el * 1000; end
    E_t  = sum(T.E_imp(s));     C_t  = sum(T.Coste_Import(s));
    p_t  = NaN; if E_t > 1e-9,  p_t  = C_t / E_t * 1000; end
    fprintf('%-22s %10.1f %10.2f %10.1f %10.1f\n', vers{iv}, mean(T.imp_a_EL(s)), ...
        mean(T.Coste_imp_EL(s)), p_el, p_t);
end
fprintf('\n(umbral de la regla: 114,2 EUR/MWh con 6,12 EUR/kg; 149,3 con 8)\n');
fprintf('\n=== A QUE PRECIO COMPRA EL ELECTROLIZADOR, por escenario (A_semana) ===\n');
s0 = strcmp(T.Version, 'A_semana');
if any(s0)
    esc = unique(T.Escenario(s0));
    for ie = 1:numel(esc)
        s = s0 & strcmp(T.Escenario, esc{ie});
        E_el = sum(T.imp_a_EL(s));  C_el = sum(T.Coste_imp_EL(s));
        p_el = NaN; if E_el > 1e-9, p_el = C_el / E_el * 1000; end
        fprintf('  %-20s kWh a EL %8.1f   p_imp_EL %7.1f EUR/MWh\n', esc{ie}, mean(T.imp_a_EL(s)), p_el);
    end
end
fprintf('\n=== DE DONDE SALE EL DINERO (medias por version) ===\n');
fprintf('%-18s %9s %9s %9s %9s %8s %8s\n', 'Version', 'C_Import', 'I_Export', ...
    'E_imp', 'E_exp', 'p_imp', 'p_exp');
for iv = 1:numel(vers)
    s = strcmp(T.Version, vers{iv});
    fprintf('%-18s %9.2f %9.2f %9.1f %9.1f %8.1f %8.1f\n', vers{iv}, ...
        mean(T.Coste_Import(s)), mean(T.Ingreso_Export(s)), ...
        mean(T.E_imp(s)), mean(T.E_exp(s)), ...
        mean(T.p_imp(s), 'omitnan'), mean(T.p_exp(s), 'omitnan'));
end

fprintf('\n=== A QUE SE DEDICA LA IMPORTACION (kWh medios) ===\n');
fprintf('%-18s %9s %9s %9s %9s %9s %9s\n', 'Version', 'con EXC', 'en DEF', ...
    'a EV', 'a EL', 'a Comp', 'a Bat');
for iv = 1:numel(vers)
    s = strcmp(T.Version, vers{iv});
    fprintf('%-18s %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f\n', vers{iv}, ...
        mean(T.E_imp_con_excedente(s)), mean(T.E_imp_en_deficit(s)), ...
        mean(T.imp_a_EV(s)), mean(T.imp_a_EL(s)), ...
        mean(T.imp_a_Comp(s)), mean(T.imp_a_Bateria(s)));
end
fprintf('\n=== COTA DEL PREMIO: reasignar excedente para no importar ===\n');
% precios ponderados por energia (no media de medias por simulacion)
fprintf('%-18s %8s %8s %8s %12s %10s\n', 'Version', 'p_imp', 'p_exp', 'margen', ...
    'exc. necesario', 'premio');
for iv = 1:numel(vers)
    s = strcmp(T.Version, vers{iv});
    pi_ = sum(T.Coste_Import(s))   / max(sum(T.E_imp(s)), 1e-9) * 1000;
    pe_ = sum(T.Ingreso_Export(s)) / max(sum(T.E_exp(s)), 1e-9) * 1000;
    Ei_ = mean(T.E_imp(s));
    margen = opciones.eta * pi_ - pe_;               % EUR/MWh
    X = Ei_ / opciones.eta;                           % kWh de excedente necesarios
    fprintf('%-18s %8.1f %8.1f %8.1f %11.1f %9.2f EUR\n', ...
        vers{iv}, pi_, pe_, margen, X, X * margen / 1000);
end
fprintf(['\n(aqui p_imp y p_exp van ponderados por energia de toda la campana; en la\n' ...
    'primera tabla son la media de los precios medios de cada simulacion)\n']);
end
