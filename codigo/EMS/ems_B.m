function [RefFC, RefEl, RefBat, DiscEl, DiscFC, Compresor] = fcn( ...
    Carga, PV, EstEl, EstFC, LOH, LOH_High, Precio, DemandaH2, SOC, PVPred, PrecioPred)
%#codegen
% Gestor de energia de la version B: es la version A a la que se le han anadido
% dos decisiones que miran a las proximas horas. Con la prevision de sol adelanta
% trabajo al electrolizador cuando ve que el excedente va a caer, y se lo cede a
% la bateria cuando ve que va a subir. Con la prevision de precio busca la punta
% de las proximas horas y, si el ahorro compensa las perdidas de la bateria,
% compra de red lo justo para llegar a esa punta con la bateria cargada. El resto
% funciona exactamente igual que A y mantiene la misma firma del bloque de
% Simulink.

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

%% Parametros de las dos decisiones con prevision
N_PV_H       = 2;     % horas de PVPred promediadas (tramo con skill positivo)
N_PRECIO_H   = 2;     % horas de PrecioPred promediadas para 'precio_sube'
DELTA_W_MAX  = 0.15;  % desplazamiento maximo del reparto por prevision PV
MARGEN_PRECIO= 25;    % EUR/MWh de subida prevista para 'precio_sube' (> MAE de la prevision)
CAP_BAT_kWh  = 1000;  % capacidad util de la bateria
ETA_BAT      = 0.90;  % rendimiento ida y vuelta
N_ARB_H      = 12;    % horizonte de busqueda de la punta de precio (h)
MARGEN_ARB   = 25;    % EUR/MWh de beneficio neto exigido para comprar red
SOC_OBJ_ARB  = 85;    % SOC objetivo del arbitraje, por debajo de SOC_MAX_PV

%% Estados persistentes: encendido y horas acumuladas de cada equipo
persistent EL_on EL_t EL_deb FC_on FC_t FC_deb_on FC_deb_off
if isempty(EL_on), EL_on = false; EL_t = 0; EL_deb = 0; end
if isempty(FC_on), FC_on = false; FC_t = 0; FC_deb_on = 0; FC_deb_off = 0; end

%% Previsiones de corto plazo
n_pv = min(N_PV_H, numel(PVPred));
PV_near = mean(PVPred(1:max(1,n_pv)));
pv_trend = PV_near - PV;            % >0 mas excedente proximo, <0 caida

n_pr = min(N_PRECIO_H, numel(PrecioPred));
Precio_near = mean(PrecioPred(1:max(1,n_pr)));
precio_sube = (Precio_near - Precio) > MARGEN_PRECIO;

% punta de precio prevista y test economico del arbitraje
n_arb   = min(N_ARB_H, numel(PrecioPred));
p_punta = Precio;
h_punta = 0;
for k_arb = 1:n_arb
    if PrecioPred(k_arb) > p_punta
        p_punta = PrecioPred(k_arb);
        h_punta = k_arb;
    end
end
ganancia_arb = p_punta * ETA_BAT - Precio;          % EUR/MWh
arbitraje_ok = (h_punta >= 1) && (ganancia_arb > MARGEN_ARB);

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

%% Bloque 1 — reparto de potencia, corregido con la prevision de sol
if Exced > 0
    PotLibre = Exced;

    if SOC < SOC_LOW,       wBat = 0.80; wEl = 0.20;
    elseif SOC < SOC_HIGH,  wBat = 0.60; wEl = 0.40;
    else,                   wBat = 0.30; wEl = 0.70;
    end

    % mueve el reparto hacia el electrolizador si el excedente va a caer
    if pv_trend < 0
        delta = min(DELTA_W_MAX, wBat * 0.5) * min(1, abs(pv_trend) / max(PV, 1e-6));
    else
        delta = -min(DELTA_W_MAX, wEl * 0.5) * min(1, pv_trend / max(PV, 1e-6));
    end
    wEl  = max(0, min(1, wEl + delta));
    wBat = max(0, 1 - wEl);

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

    if LOH_High < LOH_High_lo_off
        if LOH > LOH_reserva, C_local_kg = C_comp_kg; else, C_local_kg = C_ELcomp_kg; end
        if C_local_kg <= H2_PRECIO_EXT_KG
            if LOH < LOH_maxEL, RefEl = min(RefEl, -PmaxEl); end
            if comp_ok, Compresor = max(Compresor, CompPermitido); end
        end
    end
end

%% Bloque 1B — compra anticipada de energia barata
% si el precio va a subir, pasa excedente de la bateria al electrolizador
% (el total no cambia, no se compra nada de red)
if precio_sube && (Exced > 0) && (LOH < LOH_maxEL)
    P_el_act = abs(min(RefEl, 0));
    P_bat_act = abs(min(RefBat, 0));
    P_el_obj = min(0.5 * PmaxEl, Exced);
    if P_el_act < P_el_obj
        extra = min(P_el_obj - P_el_act, P_bat_act);
        if extra > 0
            RefEl  = -(P_el_act + extra);
            RefBat = -(P_bat_act - extra);
        end
    end
end

% compra de red lo que falta para llegar a la punta con la bateria cargada
if arbitraje_ok && (SOC < SOC_OBJ_ARB)
    E_falta_kWh = (SOC_OBJ_ARB - SOC) / 100 * CAP_BAT_kWh;
    P_arb       = E_falta_kWh / h_punta * 1000;      % kWh/h -> W
    P_arb       = min(P_arb, PmaxBat);
    RefBat = min(RefBat, -P_arb);                    % solo refuerza la carga
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
