function figuras_memoria(opciones)
% Dibuja las siete figuras del capitulo de resultados y las deja en memoria/img/.
% Se apoya en el CSV de campana mas reciente, en el de reparto de la importacion
% y, para las que llevan series hora a hora, en los .mat de las simulaciones.
% Cada figura va protegida por su try/catch, asi que si falta un dato salen las
% demas. Las figuras no llevan titulo dentro, porque lo pone el pie en la
% memoria, y los decimales van con coma. Se puede elegir que dia dibujar, por
% ejemplo figuras_memoria(struct('escenario_dia','E2_lab_nublado','semilla',3)).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
ruta_res = fullfile(ruta_ems, '..', 'resultados');
ruta_img = fullfile(ruta_ems, '..', '..', 'memoria', 'img');
def = struct('csv', '', 'csv_import', '', 'escenario_dia', 'E2_lab_nublado', ...
             'semilla', 1, 'dia', 3, 'ref', 'A_8_semana', 'ver', 'E_8', 'ver0', 'E0_8', ...
             'verS', 'E_sinLSTM_8', 'escenario_pan', 'E1_lab_soleado', 'guardar', true);
alt = struct('ref', 'A_semana', 'ver', 'E', 'ver0', 'E0', 'verS', 'E_sinLSTM');   % campana a 6,12 EUR/kg
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end
if ~exist(ruta_img, 'dir'), mkdir(ruta_img); end

col_A  = [0.45 0.45 0.45];
col_E  = [0.00 0.35 0.70];
col_E0 = [0.45 0.70 0.90];
col_Es = [0.20 0.55 0.80];
esc_nombres = {'E1_lab_soleado', 'E2_lab_nublado', 'E3_finde_soleado', 'E4_volatilidad'};
esc_cortos  = {'Laborable soleado', 'Laborable nublado', 'Finde soleado', 'Volatilidad'};

% Carga del CSV de campana
if isempty(opciones.csv)
    d = dir(fullfile(ruta_res, 'campana_detalle_*.csv'));
    assert(~isempty(d), 'No hay campana_detalle_*.csv en %s', ruta_res);
    [~, k] = max([d.datenum]);
    opciones.csv = d(k).name;
end
T = readtable(fullfile(ruta_res, opciones.csv), 'VariableNamingRule', 'preserve');
if iscategorical(T.Version), T.Version = cellstr(T.Version); end
if iscategorical(T.Escenario), T.Escenario = cellstr(T.Escenario); end
if isstring(T.Version), T.Version = cellstr(T.Version); end
if isstring(T.Escenario), T.Escenario = cellstr(T.Escenario); end
T = T(T.dias_sim == 7, :);                         % solo la semana
fprintf('[FIG] CSV: %s (%d filas de 7 dias)\n', opciones.csv, height(T));
fprintf('[FIG] filas por version: %s=%d  %s=%d  %s=%d  %s=%d\n', ...
    opciones.ref,  sum(strcmp(T.Version, opciones.ref)),  opciones.ver,  sum(strcmp(T.Version, opciones.ver)), ...
    opciones.ver0, sum(strcmp(T.Version, opciones.ver0)), opciones.verS, sum(strcmp(T.Version, opciones.verS)));
if sum(strcmp(T.Version, opciones.ref)) == 0 || sum(strcmp(T.Version, opciones.ver)) == 0
    % si una etiqueta no tiene filas se usan las de la campana a 6,12 EUR/kg
    if sum(strcmp(T.Version, alt.ref)) > 0 && sum(strcmp(T.Version, alt.ver)) > 0
        warning('[FIG] No hay filas de %s / %s en el CSV. Se usan %s / %s / %s / %s.', ...
            opciones.ref, opciones.ver, alt.ref, alt.ver, alt.ver0, alt.verS);
        opciones.ref = alt.ref; opciones.ver = alt.ver; opciones.ver0 = alt.ver0; opciones.verS = alt.verS;
    else
        error('[FIG] No hay filas de %s ni de %s en el CSV.', opciones.ref, alt.ref);
    end
end

% F1 — coste total por escenario, A frente a C
f = [];
try
    f = figure('Name', 'F1 coste por escenario', 'Color', 'w', 'Position', [100 100 900 420]);
    mA = zeros(1, 4); mE = zeros(1, 4);
    hold on
    for ie = 1:4
        sA = strcmp(T.Version, opciones.ref) & strcmp(T.Escenario, esc_nombres{ie});
        sE = strcmp(T.Version, opciones.ver) & strcmp(T.Escenario, esc_nombres{ie});
        mA(ie) = mean(T.Coste_total_H2(sA)); mE(ie) = mean(T.Coste_total_H2(sE));
        x = ie - 0.18; bar(x, mA(ie), 0.34, 'FaceColor', col_A, 'EdgeColor', 'none');
        x = ie + 0.18; bar(x, mE(ie), 0.34, 'FaceColor', col_E, 'EdgeColor', 'none');
        % semillas emparejadas como puntos, unidas por una linea fina
        [~, iA] = sort(T.Semilla(sA)); [~, iE] = sort(T.Semilla(sE));
        yA = T.Coste_total_H2(sA); yA = yA(iA);
        yE = T.Coste_total_H2(sE); yE = yE(iE);
        if isempty(yA) || isempty(yE), error('sin datos en %s', esc_nombres{ie}); end
        n = min(numel(yA), numel(yE));
        for k = 1:n
            plot([ie-0.18, ie+0.18], [yA(k), yE(k)], '-', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
        end
        plot(repmat(ie-0.18, n, 1), yA(1:n), 'o', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', col_A*0.7, 'MarkerSize', 4);
        plot(repmat(ie+0.18, n, 1), yE(1:n), 'o', 'MarkerFaceColor', 'w', 'MarkerEdgeColor', col_E*0.7, 'MarkerSize', 4);
        text(ie, max([yA; yE]) + 45, num_es(mE(ie) - mA(ie), '%+.1f €'), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');
    end
    yline(0, 'k-', 'LineWidth', 0.5);
    set(gca, 'XTick', 1:4, 'XTickLabel', esc_cortos);
    ylabel({'Resultado económico (€ / semana)', 'negativo = ingreso neto por exportación'});
    legend({'Versión A (heurística)', 'Versión C'}, 'Location', 'best');
    grid on; box off
    guardar(f, ruta_img, 'fig_res_coste_escenario.png', opciones.guardar);
catch ME
    cerrar(f); warning('[FIG] F1 no generada (linea %d): %s', ME.stack(1).line, ME.message);
end

% F2 — cascada del ahorro frente a A
f = [];
try
    vers = {opciones.ref, opciones.ver0, opciones.verS, opciones.ver};
    m = nan(1, 4);
    for iv = 1:4
        s = strcmp(T.Version, vers{iv});
        if any(s), m(iv) = mean(T.Coste_total_H2(s)); end
    end
    assert(~any(isnan(m)), 'faltan versiones de la ablacion en el CSV');
    salto = diff(m);                     % lo que aporta cada componente
    acum  = [0, cumsum(salto)];          % ahorro acumulado respecto a A
    etiq  = {'batería → electrolizador', '+ programación (persistencia)', '+ LSTM de precio', 'C frente a A'};
    cols  = {col_E0, col_Es, col_E};
    UMBRAL = 9.33;                       % umbral de relevancia economica (EUR/semana)

    f = figure('Name', 'F2 ablacion', 'Color', 'w', 'Position', [100 100 860 420]);
    hold on
    marca = '';
    esc = max(abs(acum));
    for ie = 1:3
        y0 = acum(ie); y1 = acum(ie+1);
        if abs(salto(ie)) < 0.05 * esc   % etapa sin efecto visible: linea gruesa, si no no se ve
            plot([ie-0.32 ie+0.32], [y0 y0], '-', 'Color', cols{ie}, 'LineWidth', 4);
        else
            patch([ie-0.32 ie+0.32 ie+0.32 ie-0.32], [y0 y0 y1 y1], cols{ie}, 'EdgeColor', 'none');
        end
        plot([ie+0.32, ie+1-0.32], [y1 y1], 'k:', 'LineWidth', 0.8);
        txt = num_es(salto(ie), '%+.1f €');
        if abs(salto(ie)) < UMBRAL, txt = [txt ' *']; marca = '*'; end %#ok<AGROW>
        text(ie, min(y0, y1) - 0.03*esc, txt, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', 'FontSize', 9, 'FontWeight', 'bold');
    end
    patch([3.68 4.32 4.32 3.68], [0 0 acum(4) acum(4)], col_E, 'EdgeColor', 'none');
    text(4, acum(4) - 0.03*esc, num_es(acum(4), '%+.1f €'), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', 'FontSize', 9, 'FontWeight', 'bold');
    yline(0, 'k-', 'LineWidth', 0.8);
    text(0.55, -0.02*esc, num_es(m(1), 'A = %.1f €/semana'), 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', 'FontSize', 9, 'Color', col_A);
    text(4.40, acum(4)/2, num_es(m(4), 'C = %.1f €/semana'), 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontSize', 9, 'Color', col_E);
    if ~isempty(marca)
        text(0.55, min(acum) - 0.16*esc, num_es(UMBRAL, '* por debajo del umbral de relevancia (%.2f €/semana)'), ...
            'HorizontalAlignment', 'left', 'FontSize', 8, 'Color', [0.35 0.35 0.35]);
    end
    xlim([0.5 5.3]); ylim([min(acum) - 0.22*esc, 0.10*esc]);
    set(gca, 'XTick', 1:4, 'XTickLabel', etiq, 'XTickLabelRotation', 12);
    ylabel('Ahorro acumulado frente a A (€ / semana)');
    grid on; box off
    guardar(f, ruta_img, 'fig_res_ablacion.png', opciones.guardar);
catch ME
    cerrar(f); warning('[FIG] F2 no generada (linea %d): %s', ME.stack(1).line, ME.message);
end

% F3 — en que se gasta la energia comprada a la red
f = [];
try
    if isempty(opciones.csv_import)
        d = dir(fullfile(ruta_res, 'descomposicion_import_*.csv'));
        assert(~isempty(d), 'No hay descomposicion_import_*.csv');
        [~, k] = max([d.datenum]);
        opciones.csv_import = d(k).name;
    end
    D = readtable(fullfile(ruta_res, opciones.csv_import), 'VariableNamingRule', 'preserve');
    if isstring(D.Version) || iscategorical(D.Version), D.Version = cellstr(D.Version); end
    if ~any(strcmp(D.Version, opciones.ref)) || ~any(strcmp(D.Version, opciones.ver))
        error('el CSV de descomposicion no tiene filas de %s o %s', opciones.ref, opciones.ver);
    end
    vers = {opciones.ref, opciones.ver0, opciones.ver};
    etiq = {'A', 'C0', 'C'};
    M = zeros(3, 4);
    for iv = 1:3
        s = strcmp(D.Version, vers{iv});
        M(iv, :) = [mean(D.imp_a_EV(s)), mean(D.imp_a_EL(s)), mean(D.imp_a_Comp(s)), mean(D.imp_a_Bateria(s))];
    end
    f = figure('Name', 'F3 destino import', 'Color', 'w', 'Position', [100 100 700 400]);
    hb = bar(M, 'stacked', 'EdgeColor', 'none');
    hb(1).FaceColor = [0.85 0.60 0.20]; hb(2).FaceColor = [0.20 0.45 0.75];
    hb(3).FaceColor = [0.55 0.55 0.55]; hb(4).FaceColor = [0.35 0.70 0.45];
    set(gca, 'XTickLabel', etiq);
    ylabel('Energía importada (kWh / semana)');
    legend({'a vehículos', 'a electrolizador', 'a compresor', 'a batería'}, 'Location', 'northeast');
    for iv = 1:3
        text(iv, sum(M(iv,:)) + 30, sprintf('%.0f kWh', sum(M(iv,:))), 'HorizontalAlignment', 'center', 'FontSize', 9);
    end
    grid on; box off
    guardar(f, ruta_img, 'fig_res_destino_import.png', opciones.guardar);
catch ME
    cerrar(f); warning('[FIG] F3 no generada (linea %d): %s', ME.stack(1).line, ME.message);
end

% F4 y F5 — series hora a hora del dia nublado, necesitan los .mat
f = [];
try
    rA = cargar_mat(ruta_res, opciones.ref, opciones.escenario_dia, opciones.semilla);
    rE = cargar_mat(ruta_res, opciones.ver, opciones.escenario_dia, opciones.semilla);
    t0 = (opciones.dia - 1) * 24; t1 = opciones.dia * 24;
    iA = rA.t_horas >= t0 & rA.t_horas <= t1;
    iE = rE.t_horas >= t0 & rE.t_horas <= t1;
    hA = rA.t_horas(iA) - t0; hE = rE.t_horas(iE) - t0;

    f = figure('Name', 'F4 dia nublado', 'Color', 'w', 'Position', [100 100 900 720]);
    ax1 = subplot(4,1,1);
    plot(hA, rA.Precio(iA), 'k-', 'LineWidth', 1); ylabel('Precio (€/MWh)'); grid on
    yline(149, 'r--', 'umbral 149', 'LabelHorizontalAlignment', 'left');
    ax2 = subplot(4,1,2);
    plot(hA, rA.SOC_Bat(iA), '-', 'Color', col_A, 'LineWidth', 1.2); hold on
    plot(hE, rE.SOC_Bat(iE), '-', 'Color', col_E, 'LineWidth', 1.2);
    yline(60, ':', 'Color', col_E, 'LineWidth', 0.8);
    ylabel('SOC batería (%)'); legend({'A', 'C', 'reserva C (60 %)'}, 'Location', 'best'); grid on
    % P_El y P_Grid ya llegan en kW, P_El en valor absoluto
    ax3 = subplot(4,1,3);
    plot(hA, rA.P_El(iA), '-', 'Color', col_A, 'LineWidth', 1.2); hold on
    plot(hE, rE.P_El(iE), '-', 'Color', col_E, 'LineWidth', 1.2);
    ylabel('Electrolizador (kW)'); grid on
    ax4 = subplot(4,1,4);
    plot(hA, max(rA.P_Grid(iA), 0), '-', 'Color', col_A, 'LineWidth', 1.2); hold on
    plot(hE, max(rE.P_Grid(iE), 0), '-', 'Color', col_E, 'LineWidth', 1.2);
    ylabel('Importación de red (kW)'); xlabel('Hora del día'); grid on
    linkaxes([ax1 ax2 ax3 ax4], 'x'); xlim([0 24]);
    guardar(f, ruta_img, 'fig_res_dia_nublado.png', opciones.guardar);

    f = figure('Name', 'F5 tanque', 'Color', 'w', 'Position', [100 100 900 360]);
    hold on
    fill([0 168 168 0], [0 0 72 72], [1 0.9 0.9], 'EdgeColor', 'none');          % banda critica
    plot(rA.t_horas, rA.LOH_High, '-', 'Color', col_A, 'LineWidth', 1.1);
    plot(rE.t_horas, rE.LOH_High, '-', 'Color', col_E, 'LineWidth', 1.1);
    yline(0, 'k-'); yline(72, 'r--', 'nivel crítico');
    xlabel('Hora de la semana'); ylabel('Tanque de alta (%)'); xlim([0 168]);
    legend({'zona crítica', 'A', 'C'}, 'Location', 'best');
    % los integradores de los tanques no saturan a cero: el tramo negativo es
    % el hidrogeno servido sin inventario, que es lo que mide kg_H2_no_servido
    yl = ylim;
    if yl(1) < 0
        fill([0 168 168 0], [yl(1) yl(1) 0 0], [0.93 0.93 0.93], 'EdgeColor', 'none', ...
            'FaceAlpha', 0.6, 'HandleVisibility', 'off');
        text(3, yl(1)*0.55, 'inventario negativo = H_2 no servido', 'FontSize', 8, ...
            'Color', [0.35 0.35 0.35]);
        uistack(findobj(gca, 'Type', 'line'), 'top');
    end
    grid on; box off
    guardar(f, ruta_img, 'fig_res_tanque_nublado.png', opciones.guardar);
catch ME
    warning('[FIG] F4/F5 no generadas (hacen falta los .mat de %s y %s) (linea %d): %s', opciones.ref, opciones.ver, ME.stack(1).line, ME.message);
end

% F6 — precio e irradiancia de los cuatro escenarios
f = [];
try
    ruta_datos = fullfile(ruta_ems, '..', 'data');
    Tp = readtable(fullfile(ruta_datos, 'entsoe', 'datos_entsoe_unificado_2021_2025.csv'));
    fechas_p = datetime(Tp.timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');   % hora local Madrid
    arch_nasa = fullfile(ruta_datos, 'NASA', 'NASA_07_26.csv');
    op = detectImportOptions(arch_nasa); op.DataLines = [15 Inf];
    Tn = readtable(arch_nasa, op);
    Tn.Properties.VariableNames = {'YEAR','MO','DY','HR','RH2M','PS','ALLSKY','CLRSKY'};
    Tn.ALLSKY(Tn.ALLSKY == -999) = NaN; Tn.CLRSKY(Tn.CLRSKY == -999) = NaN;
    Tn.ALLSKY = fillmissing(Tn.ALLSKY, 'linear'); Tn.CLRSKY = fillmissing(Tn.CLRSKY, 'linear');
    % mismo eje horario que preparar_workspace_simulink: de UTC a hora local
    fn_raw = datetime(Tn.YEAR, Tn.MO, Tn.DY, Tn.HR, 0, 0);
    z = datetime(fn_raw, 'TimeZone', 'UTC'); z.TimeZone = 'Europe/Madrid';
    fn = fn_raw + tzoffset(z);

    dias = {'02-07-2025', '11-02-2025', '13-07-2025', '17-09-2025'};
    P = cell(1,4); A = cell(1,4); C = cell(1,4); hp = cell(1,4); hn = cell(1,4); kt = zeros(1,4);
    for ie = 1:4
        d0 = datetime(dias{ie}, 'InputFormat', 'dd-MM-yyyy');
        ip = fechas_p >= d0 & fechas_p < d0 + days(1);
        in = fn      >= d0 & fn      < d0 + days(1);
        assert(any(ip) && any(in), 'sin datos para %s', dias{ie});
        P{ie} = Tp.precio(ip);   hp{ie} = hour(fechas_p(ip));
        A{ie} = Tn.ALLSKY(in);   C{ie} = Tn.CLRSKY(in);   hn{ie} = hour(fn(in));
        kt(ie) = sum(A{ie}, 'omitnan') / max(sum(C{ie}, 'omitnan'), eps);
    end
    ymax_p = 20 * ceil(max(cellfun(@max, P)) / 20);
    ymin_p = min(0, 20 * floor(min(cellfun(@min, P)) / 20));
    ymax_i = 100 * ceil(max(cellfun(@max, C)) / 100);

    f = figure('Name', 'F6 escenarios', 'Color', 'w', 'Position', [100 100 1020 440]);
    for ie = 1:4
        subplot(2, 4, ie)
        plot(hp{ie}, P{ie}, '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 1.2);
        xlim([0 23]); ylim([ymin_p ymax_p]); grid on; box off
        set(gca, 'XTick', 0:6:18);
        title(sprintf('E%d  %s', ie, esc_cortos{ie}), 'FontWeight', 'normal', 'FontSize', 10);
        text(0.5, ymax_p*0.93, num_es(max(P{ie}) - min(P{ie}), 'recorrido %.0f €/MWh'), 'FontSize', 8, 'Color', [0.35 0.35 0.35]);
        if ie == 1, ylabel('Precio (€/MWh)'); end

        subplot(2, 4, 4 + ie)
        h_area = area(hn{ie}, A{ie}, 'FaceColor', [0.98 0.80 0.35], 'EdgeColor', 'none'); hold on
        h_clr  = plot(hn{ie}, C{ie}, '--', 'Color', [0.55 0.45 0.20], 'LineWidth', 1);
        if ie == 1, h_leg = [h_area, h_clr]; end
        xlim([0 23]); ylim([0 ymax_i]); grid on; box off
        set(gca, 'XTick', 0:6:18);
        text(0.5, ymax_i*0.90, num_es(kt(ie), 'k_t = %.2f'), 'FontSize', 8, 'Color', [0.35 0.35 0.35]);
        xlabel('Hora del día');
        if ie == 1, ylabel('Irradiancia (Wh/m^2)'); end
    end
    % leyenda comun a los cuatro paneles: dentro del primero le robaba altura
    % y descolgaba su eje respecto a los otros tres. Se sube el bloque de ejes
    % para abrirle hueco abajo; si queda justa, tocar DESP_LEY.
    DESP_LEY = 0.065;
    ejes = findobj(f, 'Type', 'axes');
    for ke = 1:numel(ejes)
        pos = ejes(ke).Position;
        pos(4) = pos(4) * (1 - DESP_LEY);
        pos(2) = pos(2) + DESP_LEY;
        ejes(ke).Position = pos;
    end
    lg = legend(h_leg, {'cielo real', 'cielo claro'}, 'Orientation', 'horizontal', ...
        'Box', 'off', 'FontSize', 9);
    lg.Units = 'normalized';
    lg.Position(1) = 0.5 - lg.Position(3)/2;
    lg.Position(2) = 0.008;
    guardar(f, ruta_img, 'fig_met_escenarios.png', opciones.guardar);
catch ME
    cerrar(f); warning('[FIG] F6 no generada (linea %d): %s', ME.stack(1).line, ME.message);
end

% F7 — una semana completa de la version C, necesita el .mat
f = [];
try
    r = cargar_mat(ruta_res, opciones.ver, opciones.escenario_pan, opciones.semilla);
    td = r.t_horas / 24;                       % eje en dias
    tf = max(td);
    P_imp = max(r.P_Grid, 0); P_exp = -min(r.P_Grid, 0);

    f = figure('Name', 'F7 panorama', 'Color', 'w', 'Position', [100 100 950 760]);
    ax1 = subplot(4,1,1);
    area(td, r.P_PV, 'FaceColor', [0.85 0.93 0.80], 'EdgeColor', 'none'); hold on
    plot(td, r.P_El, '-', 'Color', [0.60 0.20 0.60], 'LineWidth', 0.8);
    plot(td, r.P_EV, '-', 'Color', [0.80 0.30 0.20], 'LineWidth', 0.8);
    plot(td, P_imp,  '-', 'Color', [0.10 0.10 0.10], 'LineWidth', 0.8);
    plot(td, -P_exp, '-', 'Color', [0.40 0.70 0.45], 'LineWidth', 0.6);
    ylabel('Potencia (kW)'); grid on
    legend({'PV', 'electrolizador', 'vehículos', 'importación', 'exportación'}, ...
        'Orientation', 'horizontal', 'Location', 'northoutside', 'Box', 'off');

    ax2 = subplot(4,1,2);
    plot(td, r.Precio, '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 0.8);
    ylabel('Precio (€/MWh)'); grid on

    ax3 = subplot(4,1,3);
    plot(td, r.SOC_Bat, '-', 'Color', col_E, 'LineWidth', 1.1); hold on
    yline(60, ':', 'Color', col_E, 'LineWidth', 0.8, 'Label', 'reserva 60 %', 'FontSize', 8);
    ylabel('SOC batería (%)'); ylim([0 100]); grid on

    ax4 = subplot(4,1,4);
    fill([0 tf tf 0], [0 0 72 72], [1 0.92 0.92], 'EdgeColor', 'none'); hold on
    plot(td, r.LOH_High, '-', 'Color', [0.10 0.45 0.70], 'LineWidth', 1.1);
    plot(td, r.LOH_Low,  '-', 'Color', [0.75 0.35 0.75], 'LineWidth', 0.9);
    yline(72, 'r--', 'LineWidth', 0.8);
    ylabel('Tanques de H_2 (%)'); xlabel('Día de la simulación'); grid on
    legend({'zona crítica', 'tanque de alta', 'tanque de baja'}, 'Location', 'best', 'Box', 'off');

    linkaxes([ax1 ax2 ax3 ax4], 'x'); xlim([0 tf]);
    set([ax1 ax2 ax3 ax4], 'XTick', 0:1:ceil(tf));
    guardar(f, ruta_img, 'fig_res_panorama.png', opciones.guardar);
catch ME
    cerrar(f); warning('[FIG] F7 no generada (hace falta el .mat de %s / %s) (linea %d): %s', ...
        opciones.ver, opciones.escenario_pan, ME.stack(1).line, ME.message);
end

fprintf('[FIG] Hecho. Figuras en %s\n', ruta_img);
end

% =====================================================================
function cerrar(f)
% cierra la figura de un bloque que ha fallado, para no dejar ventanas vacias
try
    if exist('f', 'var') && ~isempty(f) && isvalid(f), close(f); end
catch
end
end

function s = num_es(x, fmt)
% numero con coma decimal, como en el texto de la memoria
s = strrep(sprintf(fmt, x), '.', ',');
end

function guardar(f, ruta_img, nombre, si)
if ~si, return; end
set(f, 'PaperPositionMode', 'auto');
print(f, fullfile(ruta_img, nombre), '-dpng', '-r200');
fprintf('[FIG] guardada %s\n', nombre);
end

function r = cargar_mat(ruta_res, version, escenario, semilla)
% busca el .mat de una version, escenario y semilla, y comprueba que la etiqueta
% de dentro coincide
d = dir(fullfile(ruta_res, sprintf('%s_%s*.mat', version, escenario)));
assert(~isempty(d), 'no hay .mat %s_%s*', version, escenario);
for k = 1:numel(d)
    S = load(fullfile(ruta_res, d(k).name));
    if ~isfield(S, 'resultados'), continue; end
    r = S.resultados;
    if strcmp(r.version_ems, version) && r.semilla == semilla && isfield(r, 't_horas')
        r.t_horas = double(r.t_horas(:));
        return
    end
end
error('no hay .mat de %s / %s / semilla %d', version, escenario, semilla);
end
% Los ficheros del EMS se llaman ems_A, ems_B y ems_C, pero las etiquetas de las
% campanas antiguas son A, E, E0 y E_sinLSTM; las figuras usan las de la memoria.
