function T = medir_reserva_ociosa(opciones)
% Estima cuanto se habria podido ahorrar si la bateria, en vez de la red, hubiese
% alimentado al electrolizador y al compresor. Recorre los resultados guardados y,
% hora a hora, comprueba cuanta energia habia en la bateria por encima de un piso
% de carga y la va gastando, reponiendola despues con la exportacion que sobra.
% Es una cota superior calculada sobre una trayectoria fija, no una simulacion
% nueva. Se le pueden dar varios pisos de carga, por ejemplo
% medir_reserva_ociosa(struct('pisos', [20 40 60])).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
def = struct('carpeta', fullfile(ruta_ems, '..', 'resultados'), ...
             'cap_bat_kWh', 1000, ...   % capacidad util de la bateria
             'PmaxBat_kW',  494, ...    % 380 V x 1300 A, ver ems_A.m
             'eta',         0.90);      % rendimiento de ida y vuelta
def.pisos     = [20 40 60];             % SOC_MIN_DESC y dos reservas mas duras
def.versiones = {'A'};                  % {} = todas
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end
np = numel(opciones.pisos);

archivos = dir(fullfile(opciones.carpeta, '*.mat'));
filas = {};
for k = 1:numel(archivos)
    if ~isempty(regexp(archivos(k).name, '^(metricas|campana|ablacion)', 'once')), continue; end
    try, S = load(fullfile(opciones.carpeta, archivos(k).name)); catch, continue; end
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if ~isfield(r, 'P_Grid') || ~isfield(r, 'SOC_Bat') || ~isfield(r, 'P_El'), continue; end
    if ~isempty(opciones.versiones) && ~any(strcmp(r.version_ems, opciones.versiones)), continue; end

    th  = double(r.t_horas(:));
    if numel(th) < 3, continue; end
    gr  = double(r.P_Grid(:));  pr  = double(r.Precio(:));
    ev  = double(r.P_EV(:));    el  = double(r.P_El(:));
    bat = double(r.P_Bat(:));   soc = double(r.SOC_Bat(:));
    co  = double(r.P_Comp(:));  co(isnan(co)) = 0;

    % pesos de integracion, porque el muestreo guardado no es uniforme
    w = zeros(size(th));
    w(1)       = (th(2) - th(1)) / 2;
    w(end)     = (th(end) - th(end-1)) / 2;
    w(2:end-1) = (th(3:end) - th(1:end-2)) / 2;

    imp  = max(gr, 0);
    expo = abs(min(gr, 0));

    % importacion que alimenta al electrolizador y al compresor, que es la
    % unica que se podria haber evitado con la bateria
    carga_bat = abs(min(bat, 0));
    total_c   = ev + el + co + carga_bat;
    frac      = zeros(size(total_c));
    ok        = total_c > 1e-9;
    frac(ok)  = (el(ok) + co(ok)) ./ total_c(ok);
    imp_disc  = imp .* frac;                       % kW

    E_disc = sum(imp_disc .* w);                   % kWh importados para EL+Comp
    E_imp  = sum(imp .* w);

    % carga media de la bateria en los instantes en que se compra
    soc_medio_disc = NaN;
    if E_disc > 1e-9
        soc_medio_disc = sum(soc .* imp_disc .* w) / E_disc;
    end

    fila = {r.version_ems, r.escenario, r.semilla, E_imp, E_disc, ...
            soc_medio_disc, min(soc), soc(end) - soc(1)};

    % recorrido hora a hora, repitiendo la cuenta con cada piso de carga
    for ip = 1:np
        piso  = opciones.pisos(ip);
        D     = 0;      % kWh ya desviados de la bateria y aun no repuestos
        E_div = 0;      % kWh totales desviados
        V_ev  = 0;      % EUR ahorrados por no importar
        V_px  = 0;      % EUR dejados de ingresar por no exportar
        for i = 1:numel(th)
            % (a) energia disponible sobre el piso, menos lo ya gastado
            E_lib = max(0, (soc(i) - piso) / 100 * opciones.cap_bat_kWh - D);
            % (b) potencia que le queda libre a la bateria
            P_lib = max(0, opciones.PmaxBat_kW - abs(bat(i)));
            if (imp_disc(i) > 0) && (E_lib > 0) && (P_lib > 0) && (w(i) > 0)
                aporte = min([imp_disc(i), P_lib, E_lib / w(i)]);   % kW
                e      = aporte * w(i);                             % kWh
                E_div  = E_div + e;
                D      = D + e;
                V_ev   = V_ev + e * pr(i) / 1000;
            end
            % (c) la exportacion posterior repone la bateria, asi que ese
            %     ingreso se deja de percibir
            if (D > 0) && (expo(i) > 0) && (w(i) > 0)
                rec = min(D / opciones.eta, expo(i) * w(i));        % kWh de red
                D   = max(0, D - rec * opciones.eta);
                V_px = V_px + rec * pr(i) / 1000;
            end
        end
        fila = [fila, {E_div, V_ev - V_px, D}]; %#ok<AGROW>
    end
    filas(end+1, :) = fila; %#ok<AGROW>
end

if isempty(filas)
    error(['No hay resultados con P_Grid/SOC_Bat/P_El en %s. Los .mat no estan en ' ...
        'el repositorio: lanzalo en la maquina de simulacion.'], opciones.carpeta);
end

nombres = {'Version','Escenario','Semilla','E_imp','E_imp_discrecional', ...
           'SOC_medio_al_importar','SOC_min','dSOC_final'};
for ip = 1:np
    s = sprintf('_piso%d', opciones.pisos(ip));
    nombres = [nombres, {['E_divertible' s], ['Premio_EUR' s], ['Sin_reponer' s]}]; %#ok<AGROW>
end
T = cell2table(filas, 'VariableNames', nombres);

%% Impresion de resultados
vers = unique(T.Version);
for iv = 1:numel(vers)
    v  = vers{iv};
    sv = strcmp(T.Version, v);
    fprintf('\n\n=== %s — %d simulaciones ===\n', v, sum(sv));
    fprintf('Importacion total                     %8.1f kWh\n', mean(T.E_imp(sv)));
    fprintf('  de ella al electrolizador+compresor %8.1f kWh  (%.0f %%)\n', ...
        mean(T.E_imp_discrecional(sv)), ...
        100 * mean(T.E_imp_discrecional(sv)) / max(mean(T.E_imp(sv)), 1e-9));
    fprintf('SOC medio en esos instantes           %8.1f %%\n', ...
        mean(T.SOC_medio_al_importar(sv), 'omitnan'));
    fprintf('SOC minimo alcanzado                  %8.1f %%\n', mean(T.SOC_min(sv)));
    fprintf('SOC final - SOC inicial               %+8.1f %%\n', mean(T.dSOC_final(sv)));

    fprintf('\n%-26s', 'piso de SOC');
    for ip = 1:np, fprintf(' %12s', sprintf('%d %%', opciones.pisos(ip))); end
    fprintf('\n%-26s', 'E divertible (kWh)');
    for ip = 1:np
        fprintf(' %12.1f', mean(T.(sprintf('E_divertible_piso%d', opciones.pisos(ip)))(sv)));
    end
    fprintf('\n%-26s', '  % del import discrec.');
    for ip = 1:np
        fprintf(' %11.1f%%', 100 * mean(T.(sprintf('E_divertible_piso%d', opciones.pisos(ip)))(sv)) ...
            / max(mean(T.E_imp_discrecional(sv)), 1e-9));
    end
    fprintf('\n%-26s', 'Premio (EUR/sim)');
    for ip = 1:np
        fprintf(' %12.2f', mean(T.(sprintf('Premio_EUR_piso%d', opciones.pisos(ip)))(sv)));
    end
    fprintf('\n%-26s', 'sin reponer al final (kWh)');
    for ip = 1:np
        fprintf(' %12.1f', mean(T.(sprintf('Sin_reponer_piso%d', opciones.pisos(ip)))(sv)));
    end
    fprintf('\n');

    % desglose por escenario, porque el agregado tapa las diferencias
    escs = unique(T.Escenario(sv));
    if numel(escs) > 1
        fprintf('\n  Por escenario (E divertible kWh / premio EUR, piso %d %%):\n', opciones.pisos(1));
        cd_ = sprintf('E_divertible_piso%d', opciones.pisos(1));
        cp_ = sprintf('Premio_EUR_piso%d',  opciones.pisos(1));
        for ie = 1:numel(escs)
            se = sv & strcmp(T.Escenario, escs{ie});
            fprintf('    %-20s %8.1f kWh   %7.2f EUR   (SOC medio %.1f %%)\n', ...
                escs{ie}, mean(T.(cd_)(se)), mean(T.(cp_)(se)), ...
                mean(T.SOC_medio_al_importar(se), 'omitnan'));
        end
    end
end

fprintf(['\n\nCOMO LEERLO\n' ...
    '  - "E divertible": energia que la bateria podria haber puesto en vez de\n' ...
    '    la red. Cuanto mas cae al subir el piso, mas depende de la reserva.\n' ...
    '  - "sin reponer al final": lo desviado que la exportacion no devolvio a la\n' ...
    '    bateria. Si es grande, el ahorro sale de vaciar el almacenamiento.\n' ...
    '  - Es una cota superior sobre una trayectoria fija: el sistema real habria\n' ...
    '    reaccionado, asi que la cifra que decide es la de la campana.\n']);

end
