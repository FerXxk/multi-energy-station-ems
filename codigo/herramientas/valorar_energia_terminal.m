function T = valorar_energia_terminal(opciones)
% Comprueba si la comparacion entre versiones se sostiene cuando se cambia el
% precio al que se valora la energia que queda guardada al acabar la simulacion.
% Una version puede parecer mas barata solo porque termina con la bateria y el
% tanque mas vacios, asi que aqui se le resta al coste el valor de lo que queda
% dentro y se rehace la comparacion pareada con varios precios. Puede trabajar
% sobre los .mat o sobre el CSV de resumen_campana cuando aquellos ya no estan.

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
def = struct('carpeta', fullfile(ruta_ems, '..', 'resultados'), 'desde', '', ...
             'eta', 0.90, ...          % rendimiento de ida y vuelta de la bateria
             'precio_H2', 8, ...    % EUR/kg, coste de reposicion (camion+compresion)
             'cap_bat_kWh', 1000, ...  % 1 MWh, ver capitulo 2
             'precio_fijo', [], ...    % EUR/MWh; [] = usar precio_medio_import de cada dia
             'referencia', 'A');
% por defecto se valora al precio medio de compra de ese dia; precio_fijo permite
% barrer otros precios
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

% Modo CSV, para cuando ya no estan los .mat
if isfield(opciones, 'csv') && ~isempty(opciones.csv)
    D = readtable(opciones.csv);
    req = {'Version','Escenario','Semilla','Coste_Neto','dSOC_pct','d_kg_H2_high'};
    falta = req(~ismember(req, D.Properties.VariableNames));
    if ~isempty(falta)
        error('El CSV no trae %s.', strjoin(falta, ', '));
    end
    n = height(D);
    dE  = D.dSOC_pct / 100 * opciones.cap_bat_kWh;
    dkg = D.d_kg_H2_high;
    if ~isempty(opciones.precio_fijo)
        pr = repmat(opciones.precio_fijo, n, 1);
    elseif ismember('precio_valoracion', D.Properties.VariableNames)
        pr = D.precio_valoracion;
    elseif ismember('precio_medio_import', D.Properties.VariableNames)
        pr = D.precio_medio_import;
    else
        pr = repmat(100, n, 1);
    end
    pr(~isfinite(pr) | pr <= 0) = 100;
    V = dE * opciones.eta .* pr / 1000 + dkg * opciones.precio_H2;
    % dias_sim permite filtrar por horizonte
    if ismember('dias_sim', D.Properties.VariableNames)
        dias = double(D.dias_sim);
        dias(~isfinite(dias) | dias < 1) = 1;
    else
        warning(['El CSV no trae dias_sim: se asume 1 dia para todo. Si la ' ...
            'carpeta mezcla 24 h y semana, el pareado NO es valido.']);
        dias = ones(n, 1);
    end
    filas = [cellstr(string(D.Version)), cellstr(string(D.Escenario)), ...
             num2cell(D.Semilla), num2cell(D.Coste_Neto), num2cell(dE), ...
             num2cell(dkg), num2cell(pr), num2cell(V), num2cell(D.Coste_Neto - V), ...
             num2cell(dias)];
    fprintf('Leido del CSV %s (%d simulaciones)\n', opciones.csv, n);
    archivos = [];
else
    archivos = dir(fullfile(opciones.carpeta, '*.mat'));
    filas = {};
end
if isempty(archivos) && ~isempty(filas)
    % todo listo desde el CSV: se salta el bucle de .mat
    archivos = struct('name', {});
end
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
    try, S = load(fullfile(opciones.carpeta, nombre)); catch, continue; end
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if ~isfield(r, 'SOC_Bat') || ~isfield(r, 'kpi'), continue; end

    soc = double(r.SOC_Bat(:));
    dE  = (soc(end) - soc(1)) / 100 * opciones.cap_bat_kWh;   % kWh

    dkg = 0;
    if isfield(r, 'kg_tanque_high')
        kh = double(r.kg_tanque_high(:));
        if ~all(isnan(kh)), dkg = kh(end) - kh(1); end
    end

    precio = NaN;
    if isfield(r.kpi, 'precio_medio_import'), precio = double(r.kpi.precio_medio_import); end
    if ~isfinite(precio) || precio <= 0
        if isfield(r, 'Precio'), precio = mean(double(r.Precio), 'omitnan'); end
    end
    if ~isfinite(precio), precio = 100; end
    if ~isempty(opciones.precio_fijo), precio = opciones.precio_fijo; end

    V = dE * opciones.eta * precio / 1000 + dkg * opciones.precio_H2;
    C = double(r.kpi.Coste_Neto);

    dias = 1;
    if isfield(r, 'dias_sim') && ~isempty(r.dias_sim), dias = double(r.dias_sim); end

    filas(end+1, :) = {r.version_ems, r.escenario, r.semilla, C, dE, dkg, precio, V, C - V, dias}; %#ok<AGROW>
end

if isempty(filas), error('No se ha podido leer ningun resultado.'); end
T = cell2table(filas, 'VariableNames', {'Version','Escenario','Semilla', ...
    'Coste_Neto','dE_bat_kWh','dkg_H2','precio_EURMWh','V_terminal', ...
    'Coste_corregido','dias_sim'});

%% Solo se emparejan tandas con el mismo numero de dias que la referencia
ref = opciones.referencia;
if any(strcmp(T.Version, ref))
    dias_ref = unique(T.dias_sim(strcmp(T.Version, ref)));
    if numel(dias_ref) > 1
        error(['La version de referencia "%s" mezcla horizontes (%s dias). ' ...
            'Separa las tandas o usa etiquetas distintas.'], ref, mat2str(dias_ref));
    end
    compat = T.dias_sim == dias_ref;
    if ~all(compat)
        excl = unique(T.Version(~compat));
        fprintf(['[HORIZONTE] La referencia "%s" es de %d dia(s). Se excluyen %d ' ...
            'simulaciones de otro horizonte: %s\n'], ref, dias_ref, sum(~compat), ...
            strjoin(reshape(cellstr(excl), 1, []), ', '));
        T = T(compat, :);
    end
end

fprintf('Analizadas %d simulaciones (eta = %.2f, H2 = %.2f EUR/kg)\n\n', ...
    height(T), opciones.eta, opciones.precio_H2);

vers = unique(T.Version);
fprintf('%-22s %6s %12s %12s %12s %14s\n', 'Version','n','dE_bat kWh','dkg H2','V_term EUR','Coste corr.');
for iv = 1:numel(vers)
    s = strcmp(T.Version, vers{iv});
    fprintf('%-22s %6d %12.1f %12.3f %12.2f %14.2f\n', vers{iv}, sum(s), ...
        mean(T.dE_bat_kWh(s)), mean(T.dkg_H2(s)), mean(T.V_terminal(s)), mean(T.Coste_corregido(s)));
end

% ref ya se ha fijado en el filtro de horizonte
if ~any(strcmp(vers, ref))
    warning('No hay version de referencia "%s": no se hace comparacion pareada.', ref);
    return;
end

fprintf('\n=== PAREADO CONTRA %s ===\n', ref);
fprintf('%-22s %14s %16s %14s\n', 'Version', 'dif SIN valorar', 'dif VALORANDO', 'cambia el signo?');
A = T(strcmp(T.Version, ref), :);
for iv = 1:numel(vers)
    v = vers{iv};
    if strcmp(v, ref), continue; end
    B = T(strcmp(T.Version, v), :);
    d1 = []; d2 = [];
    for j = 1:height(B)
        m = strcmp(A.Escenario, B.Escenario{j}) & (A.Semilla == B.Semilla(j));
        if ~any(m), continue; end
        d1(end+1) = B.Coste_Neto(j)      - A.Coste_Neto(find(m,1));      %#ok<AGROW>
        d2(end+1) = B.Coste_corregido(j) - A.Coste_corregido(find(m,1)); %#ok<AGROW>
    end
    if isempty(d1), continue; end
    m1 = mean(d1); m2 = mean(d2);
    % con NaN la comparacion de signos daria un falso "SI": se marca con "?"
    if ~isfinite(m1) || ~isfinite(m2)
        sgn = '?';
    else
        sgn = ternario(sign(m1) ~= sign(m2), 'SI', 'no');
    end
    fprintf('%-22s %+14.2f %+16.2f %14s\n', v, m1, m2, sgn);
end

fprintf(['\nSi "dif VALORANDO" se acerca a cero o cambia de signo, la desventaja de\n' ...
    'esa version viene de la energia que deja almacenada al final, no de operar peor.\n']);

% precio al que la diferencia se anula: es la cifra que hay que discutir, porque
% cambia la conclusion de signo
for iv = 1:numel(vers)
    v = vers{iv};
    if strcmp(v, ref), continue; end
    B = T(strcmp(T.Version, v), :);
    dC = []; dE = []; dK = [];
    for j = 1:height(B)
        m = strcmp(A.Escenario, B.Escenario{j}) & (A.Semilla == B.Semilla(j));
        if ~any(m), continue; end
        ja = find(m,1);
        dC(end+1) = B.Coste_Neto(j)  - A.Coste_Neto(ja);   %#ok<AGROW>
        dE(end+1) = B.dE_bat_kWh(j)  - A.dE_bat_kWh(ja);   %#ok<AGROW>
        dK(end+1) = B.dkg_H2(j)      - A.dkg_H2(ja);       %#ok<AGROW>
    end
    if isempty(dC), continue; end
    num = mean(dC) - mean(dK)*opciones.precio_H2;
    den = mean(dE) * opciones.eta / 1000;
    if abs(den) > 1e-9
        fprintf(['\nPrecio de valoracion que ANULA la diferencia de %s: %.1f EUR/MWh\n' ...
            '  (media spot del ano de test ~60-65; medio ponderado de importacion ~12-22)\n'], ...
            v, num/den);
    end
end

fprintf('\n=== SENSIBILIDAD al precio de valoracion (version %s) ===\n', ref);
for f = [0.5 0.75 1.0 1.25]
    fprintf('  precio x%.2f :', f);
    for iv = 1:numel(vers)
        v = vers{iv};
        if strcmp(v, ref), continue; end
        B = T(strcmp(T.Version, v), :); d = [];
        for j = 1:height(B)
            m = strcmp(A.Escenario, B.Escenario{j}) & (A.Semilla == B.Semilla(j));
            if ~any(m), continue; end
            ja = find(m,1);
            cb = B.Coste_Neto(j) - f*B.V_terminal(j);
            ca = A.Coste_Neto(ja) - f*A.V_terminal(ja);
            d(end+1) = cb - ca; %#ok<AGROW>
        end
        if ~isempty(d), fprintf('  %s %+.2f', v, mean(d)); end
    end
    fprintf('\n');
end
end

function s = ternario(cond, a, b)
if cond, s = a; else, s = b; end
end
