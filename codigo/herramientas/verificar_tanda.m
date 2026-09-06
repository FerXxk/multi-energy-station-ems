function verificar_tanda(T, etiqueta)
% Pasa cuatro comprobaciones rapidas a la tabla que devuelve campana_simulacion
% para cazar tandas que no valen: bateria que no se descarga nunca, balance
% electrico que no cierra, inventario de hidrogeno en negativo y simulaciones
% que acabaron con error. Se llama como verificar_tanda(T, 'C').

if isempty(T)
    fprintf(2, '[VERIFICACION] La tanda "%s" no devolvio ninguna fila.\n', etiqueta);
    return;
end
n = height(T); desc = nan(n,1); bal = nan(n,1); loh = nan(n,1);
for i = 1:n
    if iscell(T.KPI), k = T.KPI{i}; else, k = T.KPI(i); end
    if ~isstruct(k) || isempty(fieldnames(k)), continue; end
    if isfield(k,'E_Bat_desc'),              desc(i) = k.E_Bat_desc; end
    if isfield(k,'balance_pct'),             bal(i)  = k.balance_pct; end
    if isfield(k,'pct_tiempo_LOH_negativo'), loh(i)  = k.pct_tiempo_LOH_negativo; end
end
fprintf('\n===== VERIFICACION DE "%s" (%d simulaciones) =====\n', etiqueta, n);
fprintf('  Descarga de bateria : media %.2f kWh | min %.2f | %d sims a CERO\n', ...
    mean(desc,'omitnan'), min(desc), sum(desc == 0));
fprintf('  Balance electrico   : max %.2e %%\n', max(bal));
fprintf('  LOH < 0             : %d sims (max %.2f %% del tiempo)\n', ...
    sum(loh > 0), max([loh; 0]));
if any(desc == 0)
    fprintf(2, ['  >> Hay simulaciones con descarga cero: revisa el signo del\n' ...
        '     excedente en el bloque del EMS y repite la tanda.\n']);
end
if max(bal) > 3
    fprintf(2, '  >> El balance electrico no cierra. Revisa signos y unidades.\n');
end
if ~isempty(T.Error) && any(~cellfun(@isempty, T.Error))
    fprintf(2, '  >> %d simulaciones terminaron con error.\n', sum(~cellfun(@isempty, T.Error)));
end
fprintf('=========================================================\n');
end
