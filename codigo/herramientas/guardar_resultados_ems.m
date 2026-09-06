function resultados = guardar_resultados_ems(out, version_ems, escenario, opciones)
% Coge lo que ha salido de una simulacion de OASIS y saca de ahi todas las cifras
% con las que luego se compara: energia comprada y vendida, coste, kilos de
% hidrogeno y lo que cuesta cada uno, autoconsumo, arranques de los equipos,
% estado de los tanques y calidad de las previsiones. Es el unico sitio donde se
% calculan estas cifras, para que todos los analisis usen la misma definicion.
% Guarda ademas las series temporales en un .mat, aligeradas si se pide, y avisa
% cuando el balance de energia no cierra o falta alguna senal. Se llama como
% guardar_resultados_ems(out, 'C', 'E2_lab_nublado', opciones).

%% 0. Opciones
if nargin < 4, opciones = struct(); end
def = struct('factor_precio_export', 1.0, 'guardar', true, ...
             'fecha', '', 'semilla', [], ...
             'LOH_High_crit', 72, 'LOH_min', 55, ...
             'Vol_low', 3.1, 'Vol_high', 0.41, ...
             'PMax_low', 40, 'PMax_high', 600, 'T_tanque', 298, ...
             'debounce_arranque_s', 30, 'verbose', true, ...
             'decimar_guardado', 1, 'dias_sim', 1, ...
             'eta_bat', 0.90, 'cap_bat_kWh', 1000, 'precio_H2_kg', 8);
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end

RHO_H2_N = 0.08988;   % kg/Nm3 de H2 en condiciones normales (0 C, 1 atm)
R_H2     = 4124.2;    % J/(kg*K)

avisos = {};

if opciones.verbose
    fprintf('Extrayendo KPIs - EMS %s, escenario %s\n', version_ems, escenario);
    fprintf('---------------------------------------------------\n');
end

%% 1. Eje temporal de referencia y extraccion de senales
[P_PV_W, t] = extraer(out, 'PV', []);
if isempty(t)
    error('No se encuentra out.PV: sin senal de referencia no se puede analizar.');
end
t_horas = t / 3600;

P_PV   = P_PV_W / 1000;                                    % kW
P_EV   = abs(extraer(out, 'CargaEV', t)) / 1000;           % kW
P_Grid = extraer(out, 'P_Red',  t) / 1000;                 % kW (>0 importa)
P_El   = abs(extraer(out, 'P_EL', t)) / 1000;              % kW
P_FC   = extraer(out, 'P_FC',   t) / 1000;                 % kW
P_Bat  = extraer(out, 'P_Bat',  t) / 1000;                 % kW (>0 descarga)

SOC_Bat  = extraer(out, 'SOC', t);
LOH_Low  = extraer(out, 'LOH', t);
LOH_High = extraer(out, 'LOH_High', t);

Precio = extraer(out, 'Precio_Real', t);                   % EUR/MWh
if all(isnan(Precio))
    avisos{end+1} = 'Falta out.Precio_Real: no hay coste operativo.';
end

% la consigna de potencia que el EMS manda al compresor es tambien su consumo
P_Comp = extraer(out, {'P_Comp', 'Compresor'}, t) / 1000;  % kW
if all(isnan(P_Comp))
    avisos{end+1} = 'Falta out.P_Comp: el balance y el coste ignoran el compresor (15 kW).';
end

% Caudales de H2 en Nl/min (electrolizador, compresor, pila)
H2_EL_nl   = extraer(out, {'H2_EL', 'H2Elec'}, t);
H2_Comp_nl = extraer(out, {'H2_Comp', 'H2Comp'}, t);
H2_FC_nl   = extraer(out, {'H2_FC', 'H2Fuel'}, t);
% Demanda de los FCEV en Nl/min (el bloque Coches Hidrogeno convierte kg/s x 667560)
H2_Dem_nl = extraer(out, {'H2_Dem', 'DemandaH2', 'demanda_H2'}, t);

Est_EL = extraer_matriz(out, {'Est_EL', 'EstEl'}, t);
Est_FC = extraer_matriz(out, {'Est_FC', 'EstFC'}, t);

Irrad         = extraer(out, {'Irrad', 'Irradiance'}, t);
% si no hay senal dedicada a la prevision de 1 h se toma la primera componente
% del vector de 24, que es justo esa
PV_Pred1h     = extraer(out, {'PV_Pred1h', 'PV_Pred'}, t);
Precio_Pred1h = extraer(out, {'Precio_Pred1h', 'Precio_Pred'}, t);

P_Low_bar  = extraer(out, 'P_Low', t);
P_High_bar = extraer(out, 'P_High', t);

% que senales opcionales se han leido, para saber por que un KPI sale vacio
if opciones.verbose
    chk = {'P_Comp',P_Comp; 'H2_EL',H2_EL_nl; 'H2_Comp',H2_Comp_nl; ...
           'H2_FC',H2_FC_nl; 'H2_Dem',H2_Dem_nl; 'P_Low',P_Low_bar; ...
           'P_High',P_High_bar; 'Irrad',Irrad; 'Precio_Pred1h',Precio_Pred1h};
    falta = {};
    for ii = 1:size(chk,1)
        if isempty(chk{ii,2}) || all(isnan(chk{ii,2})), falta{end+1} = chk{ii,1}; end %#ok<AGROW>
    end
    if isempty(Est_EL), est_txt = 'Est_EL VACIA';
    else, est_txt = sprintf('Est_EL [%d x %d]', size(Est_EL,1), size(Est_EL,2)); end
    if isempty(Est_FC), est_txt = [est_txt ' | Est_FC VACIA'];
    else, est_txt = sprintf('%s | Est_FC [%d x %d]', est_txt, size(Est_FC,1), size(Est_FC,2)); end
    fprintf('Senales: %s', est_txt);
    if isempty(falta), fprintf(' | todas las escalares OK\n');
    else, fprintf(' | sin leer: %s\n', strjoin(falta, ', ')); end
end

%% 2. Energias integradas (kWh)
E_Solar_Gen  = trapz(t_horas, P_PV);
E_Demanda_EV = trapz(t_horas, P_EV);
E_Consumo_El = trapz(t_horas, P_El);
E_Gen_Pila   = trapz(t_horas, P_FC);
E_Comp       = integrar_si(t_horas, P_Comp);

P_Importada = max(P_Grid, 0);
P_Exportada = abs(min(P_Grid, 0));
E_Import_Red = trapz(t_horas, P_Importada);
E_Export_Red = trapz(t_horas, P_Exportada);

E_Bat_desc = trapz(t_horas, max(P_Bat, 0));
E_Bat_carga = trapz(t_horas, abs(min(P_Bat, 0)));

%% 3. Comprobacion de que el balance electrico cierra
% en el bus de alterna del modelo se cumple
%   PV + FC - EL - Compresor - Carga + Bat + Grid = 0
% con la red positiva importando y la bateria positiva descargando; si el resto
% no es pequeno, hay un signo o una unidad mal
P_Comp_bal = P_Comp; P_Comp_bal(isnan(P_Comp_bal)) = 0;
residuo = P_PV + P_FC + P_Grid + P_Bat - P_EV - P_El - P_Comp_bal;
esc_pot = max([max(abs(P_PV)), max(abs(P_Grid)), 1]);
balance_rms_kW = sqrt(mean(residuo.^2));
balance_max_kW = max(abs(residuo));
balance_pct    = 100 * balance_rms_kW / esc_pot;

% si no cierra se prueban combinaciones de signo para ver cual esta invertida
balance_alternativas = {};
if balance_pct > 3
    combos = {
        'Bat invertida',        P_PV + P_FC + P_Grid - P_Bat - P_EV - P_El - P_Comp_bal
        'Grid invertida',       P_PV + P_FC - P_Grid + P_Bat - P_EV - P_El - P_Comp_bal
        'Bat y Grid invertidas',P_PV + P_FC - P_Grid - P_Bat - P_EV - P_El - P_Comp_bal
        'FC como consumo',      P_PV - P_FC + P_Grid + P_Bat - P_EV - P_El - P_Comp_bal
    };
    for k = 1:size(combos,1)
        r = sqrt(mean(combos{k,2}.^2));
        balance_alternativas(end+1, 1:2) = {combos{k,1}, 100*r/esc_pot}; %#ok<AGROW>
    end
end

%% 4. Coste operativo (EUR)
if ~all(isnan(Precio))
    coste_inst = (P_Importada - opciones.factor_precio_export * P_Exportada) .* Precio / 1000; % EUR/h
    Coste_Import   = trapz(t_horas, P_Importada .* Precio / 1000);
    Ingreso_Export = opciones.factor_precio_export * trapz(t_horas, P_Exportada .* Precio / 1000);
    Coste_Neto     = Coste_Import - Ingreso_Export;
    precio_medio_import = ponderado(P_Importada, Precio, t_horas);
else
    coste_inst = nan(size(t)); Coste_Import = NaN; Ingreso_Export = NaN;
    Coste_Neto = NaN; precio_medio_import = NaN;
end

%% 5. Hidrogeno: kg y coste por kg
kg_EL   = kg_desde_nlmin(t, H2_EL_nl, RHO_H2_N);
kg_Comp = kg_desde_nlmin(t, H2_Comp_nl, RHO_H2_N);
kg_FC   = kg_desde_nlmin(t, H2_FC_nl, RHO_H2_N);
kg_Dem = kg_desde_nlmin(t, H2_Dem_nl, RHO_H2_N);

% Inventario de los tanques en kg (gas ideal, igual que el modelo de tanque)
kg_tanque_low  = masa_tanque(P_Low_bar,  opciones.Vol_low,  opciones.T_tanque, R_H2);
kg_tanque_high = masa_tanque(P_High_bar, opciones.Vol_high, opciones.T_tanque, R_H2);
if all(isnan(kg_tanque_low)) && ~all(isnan(LOH_Low))
    kg_tanque_low = masa_tanque(LOH_Low/100*opciones.PMax_low, opciones.Vol_low, opciones.T_tanque, R_H2);
end
if all(isnan(kg_tanque_high)) && ~all(isnan(LOH_High))
    kg_tanque_high = masa_tanque(LOH_High/100*opciones.PMax_high, opciones.Vol_high, opciones.T_tanque, R_H2);
end
d_kg_low  = delta(kg_tanque_low);
d_kg_high = delta(kg_tanque_high);

% Cierre del balance de H2 (verificacion)
%   tanque baja : +EL -FC -Comp ;  tanque alta : +Comp -Demanda
balance_H2_low  = (kg_EL - kg_FC - kg_Comp) - d_kg_low;
balance_H2_high = (kg_Comp - kg_Dem) - d_kg_high;

% coste medio del kg producido: solo energia, valorada toda a precio de red
if ~all(isnan(Precio)) && kg_EL > 0
    coste_energia_H2 = trapz(t_horas, (P_El + rellenar0(P_Comp)) .* Precio / 1000);
    coste_H2_kg = coste_energia_H2 / kg_EL;
else
    coste_energia_H2 = NaN; coste_H2_kg = NaN;
end
if isnan(kg_EL)
    avisos{end+1} = 'Falta out.H2_EL: no se puede calcular el coste del H2 en EUR/kg.';
end

%% 6. Autoconsumo y autosuficiencia
% autoconsumo: parte de lo que genera el sol que se queda en la estacion
% autosuficiencia: parte de todo lo que consume la estacion que no viene de red
E_Demanda_Total = E_Demanda_EV + E_Consumo_El + rellenarNaN0(E_Comp);

if E_Solar_Gen > 0
    Autoconsumo_pct = (1 - E_Export_Red / E_Solar_Gen) * 100;
else
    Autoconsumo_pct = NaN;
end
if E_Demanda_Total > 0
    Autarquia_pct = max(0, min(100, (1 - E_Import_Red / E_Demanda_Total) * 100));
else
    Autarquia_pct = 100;
end

%% 7. Arranques de los equipos, con el estado real si se ha guardado
[Conm_El, t_run_El_pct, origen_conm_El] = conmutaciones(t, Est_EL, P_El, 2, opciones.debounce_arranque_s);
[Conm_FC, t_run_FC_pct, origen_conm_FC] = conmutaciones(t, Est_FC, P_FC, 1, opciones.debounce_arranque_s);
if strcmp(origen_conm_El, 'proxy')
    avisos{end+1} = 'Faltan out.Est_EL/out.Est_FC: conmutaciones estimadas por umbral de potencia (proxy).';
end

%% 8. Estado de los tanques y episodios anomalos
LOH_High_media = mean(LOH_High);
LOH_High_std   = std(LOH_High);
LOH_Low_media  = mean(LOH_Low);
LOH_Low_std    = std(LOH_Low);
LOH_High_min   = min(LOH_High);
LOH_Low_min    = min(LOH_Low);
pct_tiempo_critico = 100 * mean(LOH_High < opciones.LOH_High_crit);
pct_tiempo_low_bajo_min = 100 * mean(LOH_Low < opciones.LOH_min);
% el tanque no satura, asi que puede bajar de 0 (se sirvio hidrogeno que no
% habia) o pasar de 100 (sobrellenado); las dos cosas invalidan el escenario
pct_tiempo_LOH_negativo = 100 * mean(LOH_High < 0);
pct_tiempo_LOH_saturado = 100 * mean(LOH_High > 100);

%% 9. Calidad de las previsiones en el dia simulado
% el paso de emision (3600 s) hace falta o la metrica mide el remuestreo
[mae_PV, rmse_PV]   = error_prevision(t, PV_Pred1h/1000, P_PV, 3600, 3600);
[mae_Pr, rmse_Pr]   = error_prevision(t, Precio_Pred1h, Precio, 3600, 3600);

%% 9b. Valor de la energia que queda almacenada al final
if ~isempty(SOC_Bat) && ~all(isnan(SOC_Bat))
    dSOC_pct_v = SOC_Bat(end) - SOC_Bat(1);
else
    dSOC_pct_v = NaN;
end
% se descuenta del coste para que dos versiones que acaban con distinto nivel de
% bateria y de tanque sean comparables
precio_val = precio_medio_import;
if ~isfinite(precio_val) || precio_val <= 0
    if ~all(isnan(Precio)), precio_val = mean(Precio, 'omitnan'); else, precio_val = 100; end
end
dE_bat_kWh = dSOC_pct_v / 100 * opciones.cap_bat_kWh;
dkg_val    = d_kg_high; if ~isfinite(dkg_val), dkg_val = 0; end
V_terminal = dE_bat_kWh * opciones.eta_bat * precio_val / 1000 + dkg_val * opciones.precio_H2_kg;
Coste_corregido = Coste_Neto - V_terminal;

%% 9c. Coste total, sumando el hidrogeno que hubo que traer de fuera
% el hidrogeno servido con el tanque en negativo se cobra al precio externo; el
% que queda dentro ya se ha abonado antes como valor terminal
kg_H2_no_servido = 0;
if ~isempty(kg_tanque_high) && ~all(isnan(kg_tanque_high))
    inv = kg_tanque_high(:);
    q   = rellenar0(H2_Dem_nl);
    if numel(q) == numel(inv)
        q_v = q; q_v(inv > 0) = 0;         % caudal dispensado con inventario <= 0
        kg_H2_no_servido = trapz(t, q_v * 1e-3 / 60 * RHO_H2_N);
    end
end
Coste_H2_deficit = kg_H2_no_servido * opciones.precio_H2_kg;
Coste_total_H2   = Coste_corregido + Coste_H2_deficit;



%% 10. Resumen en consola
if opciones.verbose
    fprintf('ENERGIA (kWh)\n');
    fprintf('  PV generada           : %8.1f\n', E_Solar_Gen);
    fprintf('  Demanda EV            : %8.1f\n', E_Demanda_EV);
    fprintf('  Electrolizador        : %8.1f\n', E_Consumo_El);
    fprintf('  Compresor             : %8.1f\n', E_Comp);
    fprintf('  Pila de combustible   : %8.1f\n', E_Gen_Pila);
    fprintf('  Importada de red      : %8.1f\n', E_Import_Red);
    fprintf('  Exportada a red       : %8.1f\n', E_Export_Red);
    fprintf('  Bateria carga/descarga: %8.1f / %.1f\n', E_Bat_carga, E_Bat_desc);
    fprintf('HIDROGENO (kg)\n');
    fprintf('  Producido (electrol.) : %8.2f\n', kg_EL);
    fprintf('  Comprimido a alta     : %8.2f\n', kg_Comp);
    fprintf('  Consumido por la pila : %8.2f\n', kg_FC);
    fprintf('  Servido a FCEV        : %8.2f\n', kg_Dem);
    fprintf('  Coste medio del H2    : %8.2f EUR/kg\n', coste_H2_kg);
    fprintf('ECONOMIA\n');
    fprintf('  Coste neto operativo  : %8.2f EUR\n', Coste_Neto);
    fprintf('  Precio medio importado: %8.2f EUR/MWh\n', precio_medio_import);
    fprintf('  Valor terminal        : %8.2f EUR  (%.1f kWh bat, %.3f kg H2)\n', ...
        V_terminal, dE_bat_kWh, dkg_val);
    fprintf('  Coste CORREGIDO       : %8.2f EUR\n', Coste_corregido);
    fprintf('  H2 no servido         : %8.3f kg -> %.2f EUR de deficit\n', ...
        kg_H2_no_servido, Coste_H2_deficit);
    fprintf('  COSTE TOTAL (con H2)  : %8.2f EUR\n', Coste_total_H2);
    fprintf('  Autoconsumo renovable : %8.2f %%\n', Autoconsumo_pct);
    fprintf('  Autosuficiencia       : %8.2f %%\n', Autarquia_pct);
    fprintf('OPERACION\n');
    fprintf('  Arranques electrol.   : %8d  (%s, %.0f%% del dia en Run)\n', Conm_El, origen_conm_El, t_run_El_pct);
    fprintf('  Arranques pila        : %8d  (%s, %.0f%% del dia en Run)\n', Conm_FC, origen_conm_FC, t_run_FC_pct);
    fprintf('  LOH alta media/min    : %6.1f / %.1f %%\n', LOH_High_media, LOH_High_min);
    fprintf('  Tiempo LOH alta < %2d%% : %8.1f %%\n', opciones.LOH_High_crit, pct_tiempo_critico);
    fprintf('VERIFICACION\n');
    fprintf('  Balance electrico     : RMS %.3f kW (%.2f %% del pico) | max %.3f kW\n', ...
        balance_rms_kW, balance_pct, balance_max_kW);
    if balance_pct > 3
        fprintf(2, '  >> El balance NO cierra. Alternativas de signo probadas:\n');
        for k = 1:size(balance_alternativas,1)
            fprintf(2, '     %-24s -> %.2f %%\n', balance_alternativas{k,1}, balance_alternativas{k,2});
        end
    end
    fprintf('  Balance H2 baja/alta  : %.3f / %.3f kg de descuadre\n', balance_H2_low, balance_H2_high);
    if pct_tiempo_LOH_negativo > 0
        fprintf(2, '  >> LOH_High < 0 durante %.1f %% del dia: se ha servido H2 inexistente.\n', pct_tiempo_LOH_negativo);
    end
    if pct_tiempo_LOH_saturado > 0
        fprintf(2, '  >> LOH_High > 100 durante %.1f %% del dia: sobrellenado del tanque.\n', pct_tiempo_LOH_saturado);
    end
    if ~isnan(mae_Pr)
        fprintf('  MAE prevision precio  : %.2f EUR/MWh | PV: %.1f kW\n', mae_Pr, mae_PV);
    end
    for k = 1:numel(avisos)
        fprintf('  (aviso) %s\n', avisos{k});
    end
    fprintf('---------------------------------------------------\n');
end

%% 11. Struct de salida
resultados = struct();
resultados.version_ems = version_ems;
resultados.escenario   = escenario;
resultados.fecha       = opciones.fecha;
resultados.semilla     = opciones.semilla;
resultados.timestamp   = datestr(now, 'yyyymmdd_HHMMSS');
resultados.opciones    = opciones;
resultados.avisos      = avisos;

resultados.t_horas = t_horas;
resultados.P_PV = P_PV; resultados.P_EV = P_EV; resultados.P_Grid = P_Grid;
resultados.P_El = P_El; resultados.P_FC = P_FC; resultados.P_Bat = P_Bat;
resultados.P_Comp = P_Comp;
resultados.SOC_Bat = SOC_Bat; resultados.LOH_Low = LOH_Low; resultados.LOH_High = LOH_High;
resultados.Precio = Precio; resultados.Precio_Pred1h = Precio_Pred1h;
resultados.PV_Pred1h = PV_Pred1h; resultados.Irrad = Irrad;
resultados.Dem_H2_nl = H2_Dem_nl;
resultados.H2_EL_nl = H2_EL_nl; resultados.H2_Comp_nl = H2_Comp_nl; resultados.H2_FC_nl = H2_FC_nl;
resultados.Est_EL = Est_EL; resultados.Est_FC = Est_FC;
resultados.coste_inst = coste_inst;
resultados.kg_tanque_low = kg_tanque_low; resultados.kg_tanque_high = kg_tanque_high;

k = struct();
k.E_Solar_Gen = E_Solar_Gen;  k.E_Demanda_EV = E_Demanda_EV;
k.E_Consumo_El = E_Consumo_El; k.E_Gen_Pila = E_Gen_Pila;
k.E_Import_Red = E_Import_Red; k.E_Export_Red = E_Export_Red;
k.E_Comp = E_Comp; k.E_Demanda_Total = E_Demanda_Total;
k.E_Bat_carga = E_Bat_carga; k.E_Bat_desc = E_Bat_desc;
k.Coste_Neto = Coste_Neto; k.Coste_Import = Coste_Import;
k.Ingreso_Export = Ingreso_Export; k.precio_medio_import = precio_medio_import;
k.kg_H2_EL = kg_EL; k.kg_H2_Comp = kg_Comp; k.kg_H2_FC = kg_FC; k.kg_H2_Dem = kg_Dem;
k.coste_H2_kg = coste_H2_kg; k.coste_energia_H2 = coste_energia_H2;
k.Autoconsumo_pct = Autoconsumo_pct; k.Autarquia_pct = Autarquia_pct;
k.Conmutaciones_El = Conm_El; k.Conmutaciones_FC = Conm_FC;
k.origen_conmutaciones = origen_conm_El;
k.t_run_El_pct = t_run_El_pct; k.t_run_FC_pct = t_run_FC_pct;
k.LOH_High_media = LOH_High_media; k.LOH_High_std = LOH_High_std;
k.LOH_High_min = LOH_High_min; k.LOH_Low_media = LOH_Low_media;
k.LOH_Low_std = LOH_Low_std; k.LOH_Low_min = LOH_Low_min;
k.pct_tiempo_critico = pct_tiempo_critico;
k.pct_tiempo_low_bajo_min = pct_tiempo_low_bajo_min;
k.pct_tiempo_LOH_negativo = pct_tiempo_LOH_negativo;
k.pct_tiempo_LOH_saturado = pct_tiempo_LOH_saturado;
k.balance_rms_kW = balance_rms_kW; k.balance_max_kW = balance_max_kW;
k.balance_pct = balance_pct;
k.balance_H2_low = balance_H2_low; k.balance_H2_high = balance_H2_high;
% --- Estado terminal, para valorar la energia almacenada desde el CSV ---
if ~isempty(SOC_Bat) && ~all(isnan(SOC_Bat))
    k.SOC_ini = SOC_Bat(1); k.SOC_fin = SOC_Bat(end);
else
    k.SOC_ini = NaN; k.SOC_fin = NaN;
end
k.dSOC_pct = dSOC_pct_v;
k.d_kg_H2_high = d_kg_high;
k.d_kg_H2_low  = d_kg_low;
k.dias_sim     = opciones.dias_sim;
k.dE_bat_kWh        = dE_bat_kWh;
k.precio_valoracion = precio_val;
k.V_terminal        = V_terminal;
k.Coste_corregido   = Coste_corregido;
k.kg_H2_no_servido  = kg_H2_no_servido;
k.Coste_H2_deficit  = Coste_H2_deficit;
k.Coste_total_H2    = Coste_total_H2;
% lo que queda almacenado al final, en kg, bar, SOC y euros, para poder valorar
% el estado terminal desde el CSV sin volver a abrir el .mat
k.SOC_fin_pct     = NaN; if ~all(isnan(SOC_Bat)), k.SOC_fin_pct = SOC_Bat(end); end
k.kg_H2_high_fin  = NaN; if ~isempty(kg_tanque_high) && ~all(isnan(kg_tanque_high)), k.kg_H2_high_fin = kg_tanque_high(end); end
k.LOH_High_fin    = NaN; if ~all(isnan(LOH_High)), k.LOH_High_fin = LOH_High(end); end
k.bar_H2_high_fin = NaN; if ~isnan(k.LOH_High_fin), k.bar_H2_high_fin = k.LOH_High_fin/100*opciones.PMax_high; end
k.valor_H2_rem    = NaN; if ~isnan(k.kg_H2_high_fin), k.valor_H2_rem = k.kg_H2_high_fin * opciones.precio_H2_kg; end
k.valor_bat_rem   = NaN; if ~isnan(k.SOC_fin_pct), k.valor_bat_rem = k.SOC_fin_pct/100 * opciones.cap_bat_kWh * precio_val / 1000; end
k.kg_H2_high_ini  = NaN; if ~isempty(kg_tanque_high) && ~all(isnan(kg_tanque_high)), k.kg_H2_high_ini = kg_tanque_high(1); end

k.mae_prevision_precio = mae_Pr; k.rmse_prevision_precio = rmse_Pr;
k.mae_prevision_PV = mae_PV; k.rmse_prevision_PV = rmse_PV;
resultados.kpi = k;

%% 11b. Aligerado de las series que se archivan, no de los KPI
% los KPI ya estan calculados a 1 s; esto solo reduce el tamano del .mat, y el
% factor debe dividir a 3600 para no perder los instantes de emision
dec = max(1, round(opciones.decimar_guardado));
if dec > 1
    idec = 1:dec:numel(t_horas);
    if idec(end) ~= numel(t_horas), idec(end+1) = numel(t_horas); end
    campos_ts = {'t_horas','P_PV','P_EV','P_Grid','P_El','P_FC','P_Bat','P_Comp', ...
                 'SOC_Bat','LOH_Low','LOH_High','Precio','Precio_Pred1h', ...
                 'PV_Pred1h','Irrad','Dem_H2_nl','H2_EL_nl','H2_Comp_nl', ...
                 'H2_FC_nl','coste_inst','kg_tanque_low','kg_tanque_high', ...
                 'Est_EL','Est_FC'};
    for ii = 1:numel(campos_ts)
        nm = campos_ts{ii};
        if ~isfield(resultados, nm), continue; end
        v = resultados.(nm);
        if isempty(v), continue; end
        if size(v,1) == numel(t_horas)
            resultados.(nm) = v(idec, :);
        end
    end
    resultados.decimado = dec;
    if opciones.verbose
        fprintf('  Series guardadas decimadas x%d (paso %.0f s). Los KPIs son de la senal completa.\n', ...
            dec, dec * median(diff(t)));
    end
else
    resultados.decimado = 1;
end
resultados.dias_sim = opciones.dias_sim;

%% 12. Guardado
if opciones.guardar
    ruta_base = fileparts(mfilename('fullpath'));
    carpeta = fullfile(ruta_base, '..', 'resultados');
    if ~exist(carpeta, 'dir'), mkdir(carpeta); end
    if isempty(opciones.semilla)
        nombre = sprintf('%s_%s_%s.mat', version_ems, escenario, resultados.timestamp);
    else
        nombre = sprintf('%s_%s_s%d_%s.mat', version_ems, escenario, opciones.semilla, resultados.timestamp);
    end
    ruta = fullfile(carpeta, nombre);
    save(ruta, 'resultados');
    if opciones.verbose, fprintf('Guardado en: %s\n', ruta); end
    resultados.archivo = ruta;
end

end

% =======================================================================
%  FUNCIONES AUXILIARES
% =======================================================================

function ok = existe_senal(out, nombre)
ok = false;
try
    ok = any(strcmp(out.who, nombre));
catch
end
if ~ok
    try, ok = isfield(out, nombre); catch, end
end
if ~ok
    try, ok = isprop(out, nombre); catch, end
end
if ~ok
    try
        v = out.(nombre); %#ok<NASGU>
        ok = true;
    catch
    end
end
end

function [dat, tt] = extraer(out, nombres, t_ref)
% devuelve la senal como columna en el eje de referencia; si no existe, NaN
if ischar(nombres), nombres = {nombres}; end
dat = []; tt = [];
for i = 1:numel(nombres)
    if ~existe_senal(out, nombres{i}), continue; end
    s = out.(nombres{i});
    try
        if isa(s, 'timeseries')
            d = squeeze(s.Data); tt = s.Time(:);
        elseif isstruct(s) && isfield(s, 'Data')
            d = squeeze(s.Data);
            if isfield(s, 'Time'), tt = s.Time(:); else, tt = []; end
        elseif isnumeric(s)
            d = squeeze(s);
            tt = [];
        else
            continue;
        end
    catch
        continue;
    end
    d = double(d);
    if size(d,1) == 1 && size(d,2) > 1, d = d'; end
    % senal vectorial: muestras en filas y canales en columnas
    if ~isempty(tt) && size(d,1) ~= numel(tt) && size(d,2) == numel(tt)
        d = d';
    end
    if ~isempty(t_ref)
        if isempty(tt) || numel(tt) ~= size(d,1)
            if size(d,1) == numel(t_ref)
                dat = d(:,1);
            else
                dat = nan(numel(t_ref), 1);
            end
        elseif numel(tt) == numel(t_ref) && max(abs(tt - t_ref)) < 1e-9
            dat = d(:,1);
        else
            % el solver repite instantes en los cruces por cero e interp1 exige
            % puntos unicos
            [tu, iu] = unique(tt, 'stable');
            dat = interp1(tu, d(iu,1), t_ref, 'linear', 'extrap');
        end
        tt = t_ref;
    else
        dat = d(:,1);
    end
    return;
end
if isempty(dat)
    if isempty(t_ref), dat = []; else, dat = nan(numel(t_ref), 1); end
    tt = t_ref;
end
end

function M = extraer_matriz(out, nombres, t_ref)
% igual que extraer pero conservando todas las columnas, para los vectores de
% estado [Paro Standby Run]
if ischar(nombres), nombres = {nombres}; end
M = [];
for i = 1:numel(nombres)
    if ~existe_senal(out, nombres{i}), continue; end
    s = out.(nombres{i});
    % se aceptan los cuatro formatos que puede dar un bloque To Workspace
    d = []; tt = [];
    try
        if isa(s, 'timeseries')
            d = squeeze(s.Data); tt = s.Time(:);
        elseif isstruct(s) && isfield(s, 'signals')
            v = s.signals;
            if numel(v) > 1, v = v(1); end
            d = squeeze(v.values);
            if isfield(s, 'time') && ~isempty(s.time), tt = s.time(:); end
        elseif isstruct(s) && isfield(s, 'Data')
            d = squeeze(s.Data);
            if isfield(s, 'Time'), tt = s.Time(:); end
        elseif isnumeric(s)
            d = squeeze(s);
        end
    catch
        d = [];
    end
    if isempty(d), continue; end
    d = double(d);
    if ndims(d) > 2, d = reshape(d, size(d,1), []); end
    if size(d,1) < size(d,2), d = d'; end     % muestras en filas
    if ~isempty(t_ref) && ~isempty(tt) && numel(tt) == size(d,1) && numel(tt) ~= numel(t_ref)
        [tu, iu] = unique(tt, 'stable');
        M = interp1(tu, d(iu,:), t_ref, 'nearest', 'extrap');
    else
        M = d;
    end
    return;
end
end

function E = integrar_si(t_h, x)
if isempty(x) || all(isnan(x)), E = NaN; else, E = trapz(t_h, rellenar0(x)); end
end

function y = rellenar0(x)
y = x; y(isnan(y)) = 0;
end

function y = rellenarNaN0(x)
y = x; if isnan(y), y = 0; end
end

function kg = kg_desde_nlmin(t, q_nlmin, rho)
% Nl/min -> kg acumulados. 1 Nl = 1e-3 Nm3; /60 para pasar a por segundo.
if isempty(q_nlmin) || all(isnan(q_nlmin)), kg = NaN; return; end
kg = trapz(t, rellenar0(q_nlmin) * 1e-3 / 60 * rho);
end

function m = masa_tanque(P_bar, Vol_m3, T_K, R_H2)
% masa de H2 en el tanque como gas ideal, igual que el modelo de OASIS; a 600 bar
% eso sobreestima la masa un 40 %
if isempty(P_bar) || all(isnan(P_bar)), m = nan(size(P_bar)); return; end
m = (P_bar * 1e5) * Vol_m3 / (R_H2 * T_K);
end

function d = delta(x)
if isempty(x) || all(isnan(x)), d = NaN; else, d = x(end) - x(1); end
end

function p = ponderado(peso, valor, t_h)
den = trapz(t_h, peso);
if den > 0, p = trapz(t_h, peso .* valor) / den; else, p = NaN; end
end

function [n, pct_run, origen] = conmutaciones(t, Est, P, umbral_kW, deb_s)
% numero de arranques: exacto si se ha guardado el vector de estado, y si no
% aproximado por umbral de potencia
n = NaN; pct_run = NaN; origen = 'proxy';
if ~isempty(Est) && size(Est,2) >= 3
    run = Est(:,3) > 0.5;
    n = sum(diff([false; run]) == 1);
    pct_run = 100 * mean(run);
    origen = 'estado real';
    return;
end
if ~isempty(P) && ~all(isnan(P))
    n = contar_arranques(t, P, umbral_kW, deb_s);
    pct_run = 100 * mean(P > umbral_kW);
end
end

function n = contar_arranques(t, P, umbral_kW, duracion_min_s)
% flancos de subida que se mantienen un minimo de tiempo, igual que el antirrebote
% del EMS
if nargin < 4, duracion_min_s = 0; end
encendido = P > umbral_kW;
if duracion_min_s <= 0
    n = sum(diff([0; encendido(:)]) == 1);
    return;
end
if numel(t) > 1, Ts = median(diff(t)); else, Ts = 1; end
min_muestras = max(1, round(duracion_min_s / Ts));
encendido = encendido(:);
N = numel(encendido); n = 0; i = 1;
while i <= N
    if encendido(i) && (i == 1 || ~encendido(i-1))
        j = i;
        while j <= N && encendido(j), j = j + 1; end
        if (j - i) >= min_muestras, n = n + 1; end
        i = j;
    else
        i = i + 1;
    end
end
end

function [mae, rmse] = error_prevision(t, pred, real, horizonte_s, paso_emision_s)
% compara la prevision emitida en t con el valor real en t mas el horizonte
% solo se evalua en los instantes de emision: entre ellos la serie guardada es
% una rampa que el EMS nunca vio, y compararla mediria el remuestreo
if nargin < 5, paso_emision_s = []; end
mae = NaN; rmse = NaN;
if isempty(pred) || all(isnan(pred)) || isempty(real) || all(isnan(real))
    return;
end
try
    [tu, iu] = unique(t, 'stable');
    real_futuro = interp1(tu, real(iu), t + horizonte_s, 'linear', NaN);
catch
    return;
end
if ~isempty(paso_emision_s) && numel(t) > 1
    dt = median(diff(t));
    if isfinite(dt) && dt > 0
        salto = max(1, round(paso_emision_s / dt));
        sel   = 1:salto:numel(t);
        pred        = pred(sel);
        real_futuro = real_futuro(sel);
    end
end
val = ~isnan(pred) & ~isnan(real_futuro);
if ~any(val), return; end
e = pred(val) - real_futuro(val);
mae  = mean(abs(e));
rmse = sqrt(mean(e.^2));
end
