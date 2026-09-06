function S = analizar_todo(opciones)
% Lanza de una vez todos los analisis que se hacen despues de cada campana, en el
% orden en que interesan: primero el resumen en CSV, que es lo que sobrevive,
% luego la sensibilidad al valor de la energia que queda en la bateria al final,
% la comparacion pareada entre versiones, el hidrogeno servido con el tanque
% vacio y el reparto del dinero de la factura. Cada paso va protegido, asi que si
% uno falla los demas siguen. Se le pasa la version de referencia con la que
% comparar, por ejemplo analizar_todo(struct('referencia','A_semana')).

if nargin < 1, opciones = struct(); end
ruta_ems = fileparts(mfilename('fullpath'));
carpeta  = fullfile(ruta_ems, '..', 'resultados');
def = struct('referencia', 'A', 'h2', true, 'semana', [], 'desde', '');
def.precios_val = {[], 60};
campos = fieldnames(def);
for ii = 1:numel(campos)
    if ~isfield(opciones, campos{ii}), opciones.(campos{ii}) = def.(campos{ii}); end
end
if isempty(opciones.semana)
    opciones.semana = ~isempty(dir(fullfile(carpeta, 'A_semana_E*.mat')));
end

S = struct();
sep = @(t) fprintf('\n\n################ %s ################\n', t);

% 1. resumen en CSV
sep('1/5  resumen_campana  (vuelca los KPIs al CSV)');
try
    [S.detalle, S.resumen] = resumen_campana();
catch ME
    fprintf(2, 'resumen_campana fallo: %s\n', ME.message);
end

% 2. sensibilidad al valor de la energia que queda al final
sep('2/5  valorar_energia_terminal  (sensibilidad del supuesto)');
S.valor = cell(1, numel(opciones.precios_val));
for ip = 1:numel(opciones.precios_val)
    pv = opciones.precios_val{ip};
    if isempty(pv)
        fprintf('\n--- valoracion al precio medio de importacion del dia ---\n');
        o = struct();
    else
        fprintf('\n--- valoracion a %.0f EUR/MWh ---\n', pv);
        o = struct('precio_fijo', pv);
    end
    o.referencia = opciones.referencia;
    try
        S.valor{ip} = valorar_energia_terminal(o);
    catch ME
        fprintf(2, 'valorar_energia_terminal fallo: %s\n', ME.message);
    end
end

% 3. comparacion pareada entre versiones
sep('3/5  analisis_ablacion  (pareado, con Coste_corregido)');
try
    [S.par, S.agg] = analisis_ablacion(struct('referencia', opciones.referencia, ...
        'desde', opciones.desde));
catch ME
    fprintf(2, 'analisis_ablacion fallo: %s\n', ME.message);
end
if opciones.semana && isempty(opciones.desde) && ~strcmp(opciones.referencia, 'A_semana')
    sep('3b/5  analisis_ablacion sobre la SEMANA');
    try
        [S.par7, S.agg7] = analisis_ablacion(struct('referencia', 'A_semana'));
    catch ME
        fprintf(2, 'analisis_ablacion (semana) fallo: %s\n', ME.message);
    end
end

% 4. hidrogeno servido con el tanque ya vacio
if opciones.h2
    sep('4/5  medir_h2_no_servido');
    try
        S.h2 = medir_h2_no_servido();
    catch ME
        fprintf(2, 'medir_h2_no_servido fallo: %s\n', ME.message);
    end
end

% 5. reparto del dinero de la factura
sep('5/5  descomponer_importacion  (a que se dedica cada kWh importado)');
try
    S.dinero = descomponer_importacion();
catch ME
    fprintf(2, 'descomponer_importacion fallo: %s\n', ME.message);
end

% resumen final en dos lineas
fprintf('\n\n================ QUE MIRAR ================\n');
fprintf(' 1. Avisos [RECUENTO]: si hay alguno, la fila TODOS no vale.\n');
fprintf(' 2. Coste_Neto frente a Coste_corregido: si cambian de signo, la\n');
fprintf('    conclusion depende de como se valore el almacenamiento.\n');
fprintf(' 3. Coste_total_H2 anade el hidrogeno que hubo que comprar fuera.\n');
fprintf(' 4. En la ablacion, "dif" frente a "mediana" y el desglose por escenario.\n');
fprintf('===========================================\n');

end
