function T = medir_activacion_arbitraje(opciones)
% Cuenta cuantas horas se habria puesto en marcha la compra anticipada de energia
% barata de la version B, sin volver a simular. Para cada horizonte de busqueda y
% cada techo de carga mira las dos condiciones por separado: que la subida de
% precio compense las perdidas de la bateria, y que la bateria tenga sitio.
% Usa el precio real como si fuera la prevision, asi que lo que sale es una cota
% superior. Se le pueden dar otros horizontes, por ejemplo
% medir_activacion_arbitraje(struct('N_arb',[2 4 6 12 24])).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
def = struct('carpeta', fullfile(ruta_ems, '..', 'resultados'), ...
             'version', 'A', 'margen', 25, 'eta', 0.90, 'cap_bat', 1000);
def.N_arb   = [2 4 6 12 24];
def.SOC_obj = [85 90 95];
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

archivos = dir(fullfile(opciones.carpeta, [opciones.version '_E*.mat']));
if isempty(archivos)
    error('No hay resultados de la version "%s" en %s', opciones.version, opciones.carpeta);
end

% carga los resultados y los lleva a paso horario
sims = struct('escenario', {}, 'semilla', {}, 'precio', {}, 'soc', {}, 'pred', {});
for k = 1:numel(archivos)
    S = load(fullfile(opciones.carpeta, archivos(k).name));
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if ~isfield(r, 'Precio') || ~isfield(r, 'SOC_Bat') || ~isfield(r, 't_horas'), continue; end
    th = double(r.t_horas(:));
    horas = floor(th(1)) : floor(th(end));
    if numel(horas) < 4, continue; end
    pred = nan(numel(horas), 1);
    if isfield(r, 'Precio_Pred1h') && ~all(isnan(r.Precio_Pred1h))
        pred = interp1(th, double(r.Precio_Pred1h(:)), horas(:), 'linear', 'extrap');
    end
    sims(end+1) = struct('escenario', r.escenario, 'semilla', r.semilla, ...
        'precio', interp1(th, double(r.Precio(:)), horas(:), 'linear', 'extrap'), ...
        'soc',    interp1(th, double(r.SOC_Bat(:)), horas(:), 'linear', 'extrap'), ...
        'pred',   pred); %#ok<AGROW>
end
if isempty(sims), error('Ningun .mat tenia Precio/SOC_Bat utilizables.'); end
fprintf('Diagnostico sobre %d simulaciones de "%s" (%d horas cada una de media)\n\n', ...
    numel(sims), opciones.version, round(mean(cellfun(@numel, {sims.precio}))));

% simulaciones que guardaron la prevision, para la segunda parte
tiene_pred = arrayfun(@(x) any(~isnan(x.pred)), sims);
sims_p = sims(tiene_pred);

% barrido de horizontes y techos de carga
filas = {};
for iN = 1:numel(opciones.N_arb)
    N = opciones.N_arb(iN);
    for iS = 1:numel(opciones.SOC_obj)
        SOCobj = opciones.SOC_obj(iS);
        pct_eco = 0; pct_soc = 0; pct_amb = 0; E_tot = 0; n_h = 0;
        for is = 1:numel(sims)
            p = sims(is).precio; soc = sims(is).soc; nh = numel(p);
            for h = 1:nh-1
                fin_h  = min(h + N, nh);
                p_punta = max(p(h+1:fin_h));
                eco = (p_punta * opciones.eta - p(h)) > opciones.margen;
                est = soc(h) < SOCobj;
                pct_eco = pct_eco + eco;
                pct_soc = pct_soc + est;
                if eco && est
                    pct_amb = pct_amb + 1;
                    % energia que se moveria esa hora, dimensionada igual que en B
                    [~, h_rel] = max(p(h+1:fin_h));
                    E_falta = (SOCobj - soc(h)) / 100 * opciones.cap_bat;
                    E_tot = E_tot + min(E_falta / max(h_rel,1), E_falta);
                end
                n_h = n_h + 1;
            end
        end
        filas(end+1, :) = {N, SOCobj, 100*pct_eco/n_h, 100*pct_soc/n_h, ...
            100*pct_amb/n_h, E_tot/numel(sims)}; %#ok<AGROW>
    end
end

T = cell2table(filas, 'VariableNames', {'N_arb_h', 'SOC_obj', ...
    'pct_horas_test_economico', 'pct_horas_SOC_libre', ...
    'pct_horas_ACTIVA', 'kWh_movidos_por_sim'});

fprintf('%8s %8s %14s %14s %14s %16s\n', 'N_arb', 'SOC_obj', ...
    '%h economica', '%h SOC libre', '%h ACTIVA', 'kWh/sim');
for i = 1:height(T)
    fprintf('%8d %8d %13.1f%% %13.1f%% %13.1f%% %16.1f\n', ...
        T.N_arb_h(i), T.SOC_obj(i), T.pct_horas_test_economico(i), ...
        T.pct_horas_SOC_libre(i), T.pct_horas_ACTIVA(i), T.kWh_movidos_por_sim(i));
end

fprintf('\nCOMO LEERLO\n');
fprintf('  - "%%h economica": horas en que la subida de precio cubre las perdidas.\n');
fprintf('  - "%%h SOC libre": horas en que la bateria tiene sitio para cargar.\n');
fprintf('  - "%%h ACTIVA": las dos a la vez, que es cuando compraria de red.\n');
fprintf('  - kWh/sim: tamano del efecto, para compararlo con la importacion total.\n');
fprintf('  - Con el precio real como prevision, todo esto es una cota superior.\n');

%% Segunda parte: cuanto se aplana la prevision frente al precio real
% la decision depende de la altura del pico, no del error medio, asi que se
% comparan el recorrido y la desviacion tipica de la prevision y del precio
fprintf('\n\n=== DISPERSION DE LA PREVISION (h+1) ===\n');
fprintf('%-20s %8s %10s %10s %10s %10s\n', 'Escenario', 'n', ...
    'rango real', 'rango prev', 'ratio std', 'MAE h+1');

escs = unique({sims_p.escenario});
for ie = 1:numel(escs)
    sel = strcmp({sims_p.escenario}, escs{ie});
    ss  = sims_p(sel);
    rr = zeros(numel(ss),1); rp = rr; rs = rr; ma = rr;
    for j = 1:numel(ss)
        P = ss(j).precio; PP = ss(j).pred;
        rr(j) = max(P) - min(P);
        rp(j) = max(PP) - min(PP);
        sP = std(P);
        if sP > 1e-9, rs(j) = std(PP) / sP; else, rs(j) = NaN; end
        ma(j) = mean(abs(PP(1:end-1) - P(2:end)));
    end
    fprintf('%-20s %8d %10.1f %10.1f %10.3f %10.2f\n', escs{ie}, numel(ss), ...
        mean(rr), mean(rp), mean(rs, 'omitnan'), mean(ma));
end
rr_all = zeros(numel(sims_p),1); rp_all = rr_all; rs_all = rr_all;
for j = 1:numel(sims_p)
    P = sims_p(j).precio; PP = sims_p(j).pred;
    rr_all(j) = max(P) - min(P); rp_all(j) = max(PP) - min(PP);
    sP = std(P);
    if sP > 1e-9, rs_all(j) = std(PP)/sP; else, rs_all(j) = NaN; end
end
fprintf('%-20s %8d %10.1f %10.1f %10.3f\n', 'TODOS', numel(sims_p), ...
    mean(rr_all), mean(rp_all), mean(rs_all, 'omitnan'));

fprintf(['\nSi el ratio de desviaciones esta muy por debajo de 1, la prevision esta\n' ...
    'SUB-DISPERSA: comprime el precio hacia su media. En una tanda de oraculo\n' ...
    'este ratio tiene que salir 1,00 exacto; usalo como comprobacion.\n']);

%% Tercera parte: mirar la media de las proximas horas o mirar el maximo
% la media diluye justo la punta que se busca, asi que las dos reglas no ven
% las mismas oportunidades aunque usen el mismo horizonte
fprintf('\n\n=== OPERADOR DE AGREGACION: MEAN vs MAX ===\n');
fprintf('Fraccion de horas en que se dispara la condicion (MARGEN = %.0f EUR/MWh)\n\n', ...
    opciones.margen);
fprintf('%6s %14s %14s\n', 'N (h)', 'regla MEAN', 'regla MAX');
for iN = 1:numel(opciones.N_arb)
    N = opciones.N_arb(iN);
    cm = 0; cx = 0; tot = 0;
    for is = 1:numel(sims)
        p = sims(is).precio; nh = numel(p);
        for h = 1:nh-1
            fin_h = min(h + N, nh);
            fut = p(h+1:fin_h);
            if isempty(fut), continue; end
            if mean(fut) - p(h) > opciones.margen, cm = cm + 1; end
            if max(fut) * opciones.eta - p(h) > opciones.margen, cx = cx + 1; end
            tot = tot + 1;
        end
    end
    fprintf('%6d %13.1f%% %13.1f%%\n', N, 100*cm/tot, 100*cx/tot);
end
%% Cuarta parte: activacion por escenario
fprintf('\n\n=== ACTIVACION POR ESCENARIO ===\n');
escs_a = unique({sims.escenario});
for reg_i = 1:2
    if reg_i == 1
        nombre = 'regla MEAN  (Bloque 1B de la Version B, via N_PRECIO_H)';
    else
        nombre = 'regla MAX   (arbitraje de la Version B'''', via N_ARB_H)';
    end
    fprintf('\n--- %s ---\n', nombre);
    fprintf('%-20s', 'Escenario');
    for iN = 1:numel(opciones.N_arb), fprintf(' %9s', sprintf('N=%d', opciones.N_arb(iN))); end
    fprintf(' %9s\n', 'ratio');
    for ie = 1:numel(escs_a)
        sel = strcmp({sims.escenario}, escs_a{ie});
        ss  = sims(sel);
        fr  = nan(1, numel(opciones.N_arb));
        for iN = 1:numel(opciones.N_arb)
            N = opciones.N_arb(iN);
            c = 0; tot = 0;
            for is = 1:numel(ss)
                p = ss(is).precio; nh = numel(p);
                for h = 1:nh-1
                    fin_h = min(h + N, nh);
                    fut = p(h+1:fin_h);
                    if isempty(fut), continue; end
                    if reg_i == 1
                        disp_ok = (mean(fut) - p(h)) > opciones.margen;
                    else
                        disp_ok = (max(fut) * opciones.eta - p(h)) > opciones.margen;
                    end
                    if disp_ok, c = c + 1; end
                    tot = tot + 1;
                end
            end
            if tot > 0, fr(iN) = 100 * c / tot; end
        end
        fprintf('%-20s', escs_a{ie});
        for iN = 1:numel(fr), fprintf(' %8.1f%%', fr(iN)); end
        if fr(1) > 0.05
            fprintf(' %9.2f\n', fr(end) / fr(1));
        else
            fprintf(' %9s\n', '--');
        end
    end
end
fprintf(['\n"ratio" es cuantas veces mas dispara la regla con el horizonte largo\n' ...
    'que con el corto en ese escenario. Un ratio proximo a 1 significa que\n' ...
    'ampliar el horizonte no anade ni una activacion alli.\n']);

fprintf(['\nLa columna MEAN corresponde a mirar la media de las proximas horas y la\n' ...
    'columna MAX a buscar la punta, que es lo que hace la version B.\n']);

end
