function [RefFC, RefEl, RefBat, DiscEl, DiscFC, Compresor] = fcn( ...
    Carga, PV, EstEl, EstFC, LOH, LOH_High, Precio, DemandaH2, SOC, PVPred, PrecioPred)
%#codegen
% Gestor de energia de la version A, el mas sencillo de los tres y el que sirve
% de referencia para comparar. Decide solo con lo que ve en cada instante, sin
% mirar al futuro: si sobra sol lo reparte entre bateria y electrolizador segun
% lo llena que este la bateria, si falta energia tira primero de la bateria y
% luego de la pila de combustible, y solo fabrica hidrogeno propio cuando le
% sale mas barato que comprarlo fuera. Ademas obliga a que el electrolizador y
% la pila, una vez arrancados, aguanten dos horas encendidos para no castigar
% los equipos. Recibe las predicciones de sol y precio porque el bloque de
% Simulink las lleva en su firma, pero no las usa.

%% Parametros
PmaxBat = 4.94e5;  % W, 380 V x 1300 A (0,5C)
PmaxEl  = 2e5;
PmaxFC  = 1.3e5;   % 100 kW de pico EV + compresor + margen
PmaxComp= 15000;

SOC_MAX_PV   = 90;   % techo de carga con excedente PV
SOC_MIN_DESC = 20;   % suelo de descarga
SOC_LOW      = 40;
SOC_HIGH     = 80;
SOC          = max(0, min(100, SOC));

LOH_min      = 55;   % tanque de baja: minimo para comprimir
LOH_maxEL    = 95;   % tanque de baja: techo del electrolizador
LOH_reserva  = 68;   % tanque de baja: reserva del compresor

LOH_High_hi     = 97; % tanque de alta: techo de seguridad
LOH_High_lo_on  = 76; % banda baja: activa produccion
LOH_High_lo_off = 79; % banda baja: desactiva
LOH_High_crit   = 72; % nivel critico

kWh_EL_kg   = 50;
kWh_COMP_kg = 3.6;
H2_PRECIO_EXT_KG = 8;      % EUR/kg, coste de reposicion (camion + compresion). Umbral = 149 EUR/MWh
                           % a 6,12 (indice Mibgas) se obtiene la campana de sensibilidad
C_comp_kg   = Precio * (kWh_COMP_kg / 1000);
C_ELcomp_kg = Precio * ((kWh_EL_kg + kWh_COMP_kg) / 1000);

TMF_s   = 2 * 3600;  % tiempo minimo que un equipo sigue encendido tras arrancar
Ts_s    = 1;         % paso del bloque (s)
P_EL_min_keep = 0.20 * PmaxEl;
P_FC_min_keep = 0.25 * PmaxFC;
thr_EL    = 0.15 * PmaxEl;
FC_thr_on  = 0.08 * PmaxFC;
FC_thr_off = 0.04 * PmaxFC;
DEB_on_s  = 30;
DEB_off_s = 90;

%% Estados persistentes: encendido y horas acumuladas de cada equipo
persistent EL_on EL_t EL_deb FC_on FC_t FC_deb_on FC_deb_off
if isempty(EL_on), EL_on = false; EL_t = 0; EL_deb = 0; end
if isempty(FC_on), FC_on = false; FC_t = 0; FC_deb_on = 0; FC_deb_off = 0; end

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

%% Bloque 1 — reparto de potencia
if Exced > 0
    % excedente: bateria y electrolizador segun tramo de SOC, luego segunda pasada
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
    % deficit: bateria -> pila -> compresor de emergencia
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

    % decision economica: producir H2 si el coste local del kg no supera el externo
    if LOH_High < LOH_High_lo_off
        if LOH > LOH_reserva, C_local_kg = C_comp_kg; else, C_local_kg = C_ELcomp_kg; end
        if C_local_kg <= H2_PRECIO_EXT_KG
            if LOH < LOH_maxEL, RefEl = min(RefEl, -PmaxEl); end
            if comp_ok, Compresor = max(Compresor, CompPermitido); end
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
% DiscEl(1)/DiscFC(1): Paro->Standby o Run->Standby. DiscEl(2)/DiscFC(2): Standby->Run.
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
    RefEl = 0;       % proteccion de tanque lleno, por encima del tiempo minimo
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
    RefFC = 0;       % sin H2 utilizable
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
