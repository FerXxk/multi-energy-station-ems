function D = construir_demanda_multidia(fecha_inicio, dias, semilla, ruta_cars, opciones)
% Encadena varios dias de demanda en una sola serie continua, para poder simular
% una semana entera de una tirada. Hace falta porque simulando dia a dia el EMS
% esta obligado a cerrar el balance antes de medianoche, y eso castiga cualquier
% decision anticipatoria; con una semana seguida solo el ultimo dia queda
% expuesto a ese efecto de borde. Para cada dia mira el calendario real y decide
% si toca perfil laborable o de fin de semana, y usa una semilla derivada de la
% de la semana, de forma que los dias son distintos entre si pero la semana de la
% semilla 3 es siempre la misma en todas las versiones del EMS. Si un perfil
% diario no existe, lo genera. Se llama como
% construir_demanda_multidia('02-07-2025', 7, 3, ruta_cars).

if nargin < 5, opciones = struct(); end
def = struct('opciones_demanda', struct(), 'regenerar', false, 'verbose', true);
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

SEMILLA_BASE_MULTIDIA = 1000;   % separa las semillas de semana de las de la
                                % campana de un dia, para no pisar los .mat
SEG_DIA = 86400;

dias = max(1, round(dias));
t0   = datetime(fecha_inicio, 'InputFormat', 'dd-MM-yyyy');

opc_dem = opciones.opciones_demanda;
opc_dem.guardar_perfil_activo = false;

nombres_dia = {'domingo','lunes','martes','miercoles','jueves','viernes','sabado'};

n_tot = dias * SEG_DIA + 1;
ev  = zeros(n_tot, 1);
pot = zeros(n_tot, 1);
h2  = zeros(n_tot, 1);

info = cell(dias, 5);

for d = 0:dias-1
    fecha_d = t0 + days(d);
    es_finde = ismember(weekday(fecha_d), [1 7]);
    if es_finde, tipo = 'findesemana'; else, tipo = 'laborable'; end

    k = SEMILLA_BASE_MULTIDIA + (semilla - 1) * dias + d;

    f_ev = fullfile(ruta_cars, sprintf('perfil_EV_s%d.mat', k));
    f_h2 = fullfile(ruta_cars, sprintf('perfil_H2_s%d.mat', k));

    % el nombre del perfil solo lleva la semilla, asi que se compara la
    % configuracion guardada con la pedida y se regenera si no coinciden
    hay_que_generar = opciones.regenerar || ~exist(f_ev, 'file') || ~exist(f_h2, 'file');
    motivo = 'no existe';
    if ~hay_que_generar
        [coincide, motivo] = misma_config(f_ev, opc_dem);
        if ~coincide
            hay_que_generar = true;
        end
    end

    if hay_que_generar
        if opciones.verbose
            fprintf('[MULTIDIA] Generando perfil diario de la semilla derivada %d (%s)...\n', k, motivo);
        end
        Demanda_Coches_Aleatoria(k, opc_dem);
    end

    dev = load(f_ev);
    dh2 = load(f_h2);
    if es_finde
        ev_d  = dev.demanda_EV_finde.Data(:);
        pot_d = dev.pot_EV_finde.Data(:);
        h2_d  = dh2.demanda_H2_finde.Data(:);
    else
        ev_d  = dev.demanda_EV_lab.Data(:);
        pot_d = dev.pot_EV_lab.Data(:);
        h2_d  = dh2.demanda_H2_lab.Data(:);
    end

    % cada perfil diario repite la muestra de medianoche: se copian las 86400
    % primeras y la ultima se anade al salir del bucle
    i0 = d * SEG_DIA + 1;
    iF = i0 + SEG_DIA - 1;
    ev(i0:iF)  = ev_d(1:SEG_DIA);
    pot(i0:iF) = pot_d(1:SEG_DIA);
    h2(i0:iF)  = h2_d(1:SEG_DIA);

    info(d+1, :) = {d+1, datestr(fecha_d, 'dd-mm-yyyy'), ...
        nombres_dia{weekday(fecha_d)}, tipo, k};
end

% muestra final: se prolonga el ultimo valor
ev(end)  = ev(end-1);
pot(end) = pot(end-1);
h2(end)  = h2(end-1);

tiempo = (0:SEG_DIA*dias)';

ts_ev  = timeseries(ev,  tiempo);  ts_ev.Name  = 'Coches_EV_MultiDia';
ts_pot = timeseries(pot, tiempo);  ts_pot.Name = 'Potencia_EV_kW_MultiDia';
ts_h2  = timeseries(h2,  tiempo);  ts_h2.Name  = 'Demanda_H2_MultiDia';

D = struct();
D.demanda_EV = ts_ev;
D.pot_EV     = ts_pot;
D.demanda_H2 = ts_h2;
D.dias       = dias;
D.fecha_inicio = fecha_inicio;
D.semilla    = semilla;
D.detalle    = cell2table(info, 'VariableNames', ...
    {'Dia','Fecha','DiaSemana','Perfil','SemillaDerivada'});

if opciones.verbose
    fprintf('[MULTIDIA] Semana de %d dias desde %s (semilla base %d)\n', ...
        dias, fecha_inicio, semilla);
    disp(D.detalle);
    fprintf('[MULTIDIA] H2 total de la semana: %.1f kg | coches-segundo EV: %.0f\n', ...
        sum(h2(1:end-1)), sum(ev(1:end-1)));
end

% traza de la configuracion de demanda realmente usada
try
    mm = load(f_ev, 'meta');
    fprintf(['[MULTIDIA] Configuracion de demanda efectiva: factor EV = %.2f, ' ...
        'factor H2 = %.2f, postes EV = %d, postes H2 = %d\n'], ...
        mm.meta.opciones.factor_llegadas_EV, mm.meta.opciones.factor_llegadas_H2, ...
        mm.meta.opciones.N_postes_EV, mm.meta.opciones.N_postes_H2);
catch
end

end

% =======================================================================
function [ok, motivo] = misma_config(f_ev, opc_pedida)
% compara la configuracion de demanda pedida con la guardada en el perfil
ok = true; motivo = 'cacheado';
campos = {'factor_llegadas_EV', 'factor_llegadas_H2', 'N_postes_EV', ...
          'N_postes_H2', 'P_cargador_EV', 'Caudal_H2_surtidor'};
def = struct('N_postes_EV', 2, 'N_postes_H2', 1, 'P_cargador_EV', 50, ...
             'Caudal_H2_surtidor', 1.2, 'factor_llegadas_EV', 1.0, ...
             'factor_llegadas_H2', 1.0);
try
    mm = load(f_ev, 'meta');
    guardada = mm.meta.opciones;
catch
    ok = false; motivo = 'el perfil no guarda su configuracion'; return;
end
for ii = 1:numel(campos)
    c = campos{ii};
    if isfield(opc_pedida, c), pedido = opc_pedida.(c); else, pedido = def.(c); end
    if isfield(guardada, c),   tiene  = guardada.(c);   else, tiene  = def.(c);  end
    if abs(double(pedido) - double(tiene)) > 1e-9
        ok = false;
        motivo = sprintf('%s pedido %.2f, cacheado %.2f', c, double(pedido), double(tiene));
        return;
    end
end
end
