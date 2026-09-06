function [RefFC, RefEl, RefBat, DiscEl, DiscFC, Compresor] = fcn( ...
    Carga, PV, EstEl, EstFC, LOH, LOH_High, Precio, DemandaH2, SOC, PVPred, PrecioPred)
%#codegen
% Variante C0 del gestor de energia: es la version C con el planificador apagado,
% asi que de los dos cambios respecto a A solo queda el primero, el de que la
% bateria alimente al electrolizador y al compresor antes que la red mientras le
% quede carga por encima de la reserva. Se usa para ver cuanto aporta esa regla
% por si sola, sin la eleccion de las horas mas baratas del dia.

%% Interruptores de los dos cambios respecto a A
USAR_D1   = true;
USAR_PLAN = false;   % apagado: esta variante no planifica horas

%% Parametros
PmaxBat = 4.94e5;  % W, 380 V x 1300 A (0,5C)
PmaxEl  = 2e5;
PmaxFC  = 1.3e5;
PmaxComp= 15000;

SOC_MAX_PV   = 90;
SOC_MIN_DESC = 20;
SOC_LOW      = 40;
SOC_HIGH     = 80;
SOC          = max(0, min(100, SOC));

LOH_min      = 55;
LOH_maxEL    = 95;
LOH_reserva  = 68;

LOH_High_hi     = 97;
LOH_High_lo_on  = 76;
LOH_High_lo_off = 79;
LOH_High_crit   = 72;

kWh_EL_kg   = 50;
kWh_COMP_kg = 3.6;
H2_PRECIO_EXT_KG = 8;      % EUR/kg, coste de reposicion (camion + compresion). Umbral = 149 EUR/MWh
                           % a 6,12 (indice Mibgas) se obtiene la campana de sensibilidad
C_comp_kg   = Precio * (kWh_COMP_kg / 1000);
C_ELcomp_kg = Precio * ((kWh_EL_kg + kWh_COMP_kg) / 1000);

TMF_s   = 2 * 3600;
Ts_s    = 1;
P_EL_min_keep = 0.20 * PmaxEl;
P_FC_min_keep = 0.25 * PmaxFC;
thr_EL     = 0.15 * PmaxEl;
FC_thr_on  = 0.08 * PmaxFC;
FC_thr_off = 0.04 * PmaxFC;
DEB_on_s  = 30;
DEB_off_s = 90;

%% Parametros propios de esta version
SOC_RESERVA      = 60;      % % de SOC por debajo del cual no se alimenta al electrolizador
N_PLAN_H         = 24;      % horizonte del planificador (h), incluye la hora actual
N_TMF_H          = 2;       % las horas se compran en bloques iguales al tiempo minimo
LOH_OBJ          = LOH_High_lo_off;  % objetivo de inventario del tanque de alta (%)
LOH_OBJ_MAX      = 90;      % por encima no se compra red para H2
CAP_HIGH_KG      = 20;    % kg del tanque de alta al 100 % (gas ideal, 0.41 m3, 600 bar)
CAP_LOW_KG       = 10.1;    % kg del tanque de baja al 100 %
DEM_H2_INI_KG_H  = 0.9;     % kg/h iniciales de la media movil de demanda
NLMIN_A_KGH      = 1e-3 * 60 * 0.08988;   % Nl/min -> kg/h
TAU_DEM_S        = 24 * 3600;             % memoria de la media movil de demanda
DEM_MIN_KG_H     = 0.3;  DEM_MAX_KG_H = 3.0;

%% Estados persistentes
persistent EL_on EL_t EL_deb FC_on FC_t FC_deb_on FC_deb_off
if isempty(EL_on), EL_on = false; EL_t = 0; EL_deb = 0; end
if isempty(FC_on), FC_on = false; FC_t = 0; FC_deb_on = 0; FC_deb_off = 0; end

persistent E_dem_kg_h E_PV_pico E_G_pico
if isempty(E_dem_kg_h), E_dem_kg_h = DEM_H2_INI_KG_H; end
if isempty(E_PV_pico),  E_PV_pico  = 0; end
if isempty(E_G_pico),   E_G_pico   = 0; end

%% Salidas
RefFC = 0; RefEl = 0; RefBat = 0; Compresor = 0;
DiscEl = [0 0 0]; DiscFC = [0 0 0];

Exced = PV - Carga;

comp_ok = (LOH_High < LOH_High_hi) && (LOH > LOH_reserva);
fac_comp = 0;
if comp_ok
    fac_comp = (LOH - LOH_reserva) / max(1e-6, (LOH_maxEL - LOH_reserva));
    fac_comp = max(0, min(1, fac_comp));
end
CompPermitido = PmaxComp * fac_comp;

%% Planificador: decide si toca producir hidrogeno en esta hora
% demanda de H2 prevista: media movil exponencial del caudal medido
dem_ahora = max(0, DemandaH2) * NLMIN_A_KGH;
alfa = Ts_s / TAU_DEM_S;
E_dem_kg_h = (1 - alfa) * E_dem_kg_h + alfa * dem_ahora;
E_dem_kg_h = max(DEM_MIN_KG_H, min(DEM_MAX_KG_H, E_dem_kg_h));

% escala irradiancia -> potencia
E_PV_pico = max(E_PV_pico, PV);
E_G_pico  = max(E_G_pico,  max(PVPred));

% regla de A: producir si el kg propio sale mas barato que el comprado fuera
if LOH > LOH_reserva, C_local_kg = C_comp_kg; else, C_local_kg = C_ELcomp_kg; end
test_A = (LOH_High < LOH_High_lo_off) && (C_local_kg <= H2_PRECIO_EXT_KG);

producir_H2_ahora = test_A;

if USAR_PLAN
    n_h_max = min(N_PLAN_H, numel(PrecioPred) + 1);

    % excedente solar previsto que el electrolizador puede aprovechar gratis (kWh)
    E_pv_el_kWh = min(max(0, Exced), PmaxEl) / 1000;
    for k = 2:n_h_max
        PV_k = 0;
        if E_G_pico > 1e-9
            PV_k = PVPred(k-1) / E_G_pico * E_PV_pico;
        end
        E_pv_el_kWh = E_pv_el_kWh + min(max(0, PV_k - Carga), PmaxEl) / 1000;
    end

    % H2 que falta: reponer tanque de alta + demanda prevista - stock del tanque de baja
    kg_falta = max(0, (LOH_OBJ - LOH_High) / 100 * CAP_HIGH_KG) ...
             + E_dem_kg_h * n_h_max ...
             - max(0, (LOH - LOH_reserva) / 100 * CAP_LOW_KG);
    E_falta_kWh = max(0, kg_falta) * (kWh_EL_kg + kWh_COMP_kg);
    E_red_kWh   = max(0, E_falta_kWh - E_pv_el_kWh);

    % horas de electrolizador que hay que comprar, en bloques de dos horas
    n_h = ceil(E_red_kWh / (PmaxEl / 1000));
    n_h = N_TMF_H * ceil(n_h / N_TMF_H);
    n_h = min(n_h, n_h_max);

    % puesto de la hora actual en el ranking de precios del horizonte
    mas_baratas = 0;
    for k = 1:n_h_max-1
        if PrecioPred(k) < Precio, mas_baratas = mas_baratas + 1; end
    end
    rango_actual = 1 + mas_baratas;

    plan_ok = (n_h > 0) && (rango_actual <= n_h);

    % ademas se respetan los topes de precio e inventario de A
    plan_ok = plan_ok && (C_ELcomp_kg <= H2_PRECIO_EXT_KG) && (LOH_High < LOH_OBJ_MAX);

    producir_H2_ahora = plan_ok || ((LOH_High < LOH_High_crit) && test_A);
end

%% Bloque 1 — reparto de potencia
if Exced > 0
    % sobra sol: mismo reparto que en A
    PotLibre = Exced;

    if SOC < SOC_LOW,       wBat = 0.80; wEl = 0.20;
    elseif SOC < SOC_HIGH,  wBat = 0.60; wEl = 0.40;
    else,                   wBat = 0.30; wEl = 0.70;
    end

    if SOC < SOC_MAX_PV
        PotBat = min(PmaxBat, min(wBat * PotLibre, PotLibre));
        RefBat = -PotBat;
        PotLibre = PotLibre - PotBat;
    end

    if (PotLibre > 0) && (LOH < LOH_maxEL)
        PotEl = min([PmaxEl, wEl * Exced, PotLibre]);
        RefEl = -PotEl;
        PotLibre = PotLibre - PotEl;
    end

    if (PotLibre > 0) && (LOH < LOH_maxEL)
        add = min(PmaxEl - abs(RefEl), PotLibre);
        if add > 0, RefEl = RefEl - add; PotLibre = PotLibre - add; end
    end
    if (PotLibre > 0) && (LOH_High < LOH_High_lo_on) && comp_ok
        add = min(CompPermitido, PotLibre);
        if add > 0, PotLibre = PotLibre - add; end
    end
    if (PotLibre > 0) && (SOC < SOC_MAX_PV)
        add = min(PmaxBat - abs(RefBat), PotLibre);
        if add > 0, RefBat = RefBat - add; PotLibre = PotLibre - add; end
    end
    if (PotLibre > 0) && comp_ok
        add = min(max(0, CompPermitido - Compresor), PotLibre);
        if add > 0, Compresor = Compresor + add; end
    end

elseif Exced < 0
    % falta energia: bateria, luego pila, y compresor solo si el tanque esta critico
    PotDef = -Exced;

    if SOC > SOC_MIN_DESC
        Pdesc = min(PotDef, PmaxBat);
        RefBat = Pdesc;
        PotDef = PotDef - Pdesc;
    end
    if PotDef > 0
        RefFC = min(PotDef, PmaxFC);
        PotDef = PotDef - RefFC;
    end
    if (LOH_High < LOH_High_crit) && comp_ok && (PotDef > 0)
        Compresor = min(CompPermitido, PotDef);
    end

    % arranca el electrolizador si el planificador da luz verde a esta hora
    % el compresor conserva la regla de A
    if producir_H2_ahora
        if LOH < LOH_maxEL, RefEl = min(RefEl, -PmaxEl); end
    end
    if (LOH_High < LOH_High_lo_off) && (C_comp_kg <= H2_PRECIO_EXT_KG) && comp_ok
        Compresor = max(Compresor, CompPermitido);
    end

    % la bateria alimenta al electrolizador y al compresor antes que la red
    if USAR_D1
        P_disc = abs(min(RefEl, 0)) + max(0, Compresor);
        if (P_disc > 0) && (SOC > SOC_RESERVA)
            aporte = min(P_disc, PmaxBat - abs(RefBat));
            if aporte > 0
                RefBat = RefBat + aporte;       % RefBat > 0 = descarga
            end
        end
    end
end

%% Bloque 2 — dos horas minimas encendido, con histeresis y antirrebote
[RefEl, EL_on, EL_t, EL_deb] = tmf_electrolizador( ...
    RefEl, EL_on, EL_t, EL_deb, TMF_s, Ts_s, P_EL_min_keep, thr_EL, DEB_on_s, LOH, LOH_maxEL);

[RefFC, FC_on, FC_t, FC_deb_on, FC_deb_off] = tmf_pila( ...
    RefFC, FC_on, FC_t, FC_deb_on, FC_deb_off, TMF_s, Ts_s, P_FC_min_keep, ...
    FC_thr_on, FC_thr_off, DEB_on_s, DEB_off_s);

%% Bloque 3 — maquina de estados Paro/Standby/Run
if EstEl(1) == 1
    DiscEl(1) = 1;
end
if EL_on && EstEl(2) == 1
    DiscEl(2) = 1;
end
if (~EL_on) && (EstEl(3) == 1)
    DiscEl(1) = 1;
    DiscEl(2) = 0;
end
if LOH >= LOH_maxEL || LOH_High >= LOH_High_hi
    RefEl = 0;
end

if EstFC(1) == 1
    DiscFC(1) = 1;
end
if FC_on && EstFC(2) == 1
    DiscFC(2) = 1;
end
if (~FC_on) && (EstFC(3) == 1)
    DiscFC(1) = 1;
    DiscFC(2) = 0;
end
if LOH_High <= LOH_min
    RefFC = 0;
end

end % fcn


%% Subfunciones de tiempo minimo de funcionamiento
function [RefEl, EL_on, EL_t, EL_deb] = tmf_electrolizador( ...
    RefEl, EL_on, EL_t, EL_deb, TMF_s, Ts_s, P_min_keep, thr, DEB_on_s, LOH, LOH_maxEL)

want_on = (RefEl < -thr) && (LOH < LOH_maxEL);

if EL_on
    EL_t = EL_t + Ts_s;
    if ~want_on
        if EL_t < TMF_s
            RefEl = -max(P_min_keep, 0);
        else
            RefEl = 0; EL_on = false; EL_t = 0; EL_deb = 0;
        end
    end
else
    if want_on
        EL_deb = min(EL_deb + Ts_s, DEB_on_s);
        if EL_deb >= DEB_on_s
            EL_on = true; EL_t = 0;
            if RefEl > -P_min_keep, RefEl = -P_min_keep; end
        end
    else
        EL_deb = 0; RefEl = 0;
    end
end
end


function [RefFC, FC_on, FC_t, FC_deb_on, FC_deb_off] = tmf_pila( ...
    RefFC, FC_on, FC_t, FC_deb_on, FC_deb_off, TMF_s, Ts_s, P_min_keep, ...
    thr_on, thr_off, DEB_on_s, DEB_off_s)

want_on_now  = (RefFC > thr_on);
want_off_now = (RefFC < thr_off);

if FC_on
    FC_t = FC_t + Ts_s;
    if want_off_now
        FC_deb_off = min(FC_deb_off + Ts_s, DEB_off_s);
    else
        FC_deb_off = 0;
    end
    if FC_deb_off >= DEB_off_s
        if FC_t < TMF_s
            RefFC = max(P_min_keep, 0);
        else
            RefFC = 0; FC_on = false; FC_t = 0; FC_deb_on = 0; FC_deb_off = 0;
        end
    else
        FC_deb_on = 0;
    end
else
    if want_on_now
        FC_deb_on = min(FC_deb_on + Ts_s, DEB_on_s);
    else
        FC_deb_on = 0; RefFC = 0;
    end
    if FC_deb_on >= DEB_on_s
        FC_on = true; FC_t = 0; FC_deb_off = 0;
        if RefFC < P_min_keep, RefFC = P_min_keep; end
    end
end
end
