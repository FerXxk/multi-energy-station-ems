function anadir_al_registro(ruta_csv, fila)
% Anade una fila al CSV donde se van apuntando los entrenamientos, aguantando que
% de una version a otra cambien las columnas. MATLAB no deja anadir una fila con
% columnas distintas, asi que aqui se lee el registro entero, se juntan las
% columnas de las dos tablas rellenando lo que falte y se reescribe, de forma que
% las ejecuciones viejas y las nuevas conviven y se ve que cambio entre ellas. Si
% la union no es posible, no se toca el registro: la fila nueva se guarda aparte
% y se avisa.

T = table();
if exist(ruta_csv, 'file')
    try
        T = readtable(ruta_csv, 'TextType', 'string');
    catch ME
        fprintf(2, '[registro] No se pudo leer %s (%s). Se creara uno nuevo.\n', ...
            ruta_csv, ME.message);
        T = table();
    end
end

try
    if isempty(T)
        T_out = fila;
    else
        cols = union(T.Properties.VariableNames, fila.Properties.VariableNames, 'stable');
        T    = completar_columnas(T, cols, fila);
        fila = completar_columnas(fila, cols, T);
        T_out = [T(:, cols); fila(:, cols)];
    end
    writetable(T_out, ruta_csv);
    fprintf('[registro] %d filas en %s\n', height(T_out), ruta_csv);
catch ME
    [carp, nom, ext] = fileparts(ruta_csv);
    alt = fullfile(carp, sprintf('%s_%s%s', nom, datestr(now, 'yyyymmdd_HHMMSS'), ext));
    writetable(fila, alt);
    fprintf(2, ['[registro] No se pudo fusionar con el registro (%s).\n' ...
                '           Fila guardada en %s\n'], ME.message, alt);
end

end

function T = completar_columnas(T, cols, ref)
% el relleno tiene que ser del mismo tipo que la columna en la otra tabla, o
% vertcat falla al juntar una columna numerica con una de texto
faltan = setdiff(cols, T.Properties.VariableNames);
for i = 1:numel(faltan)
    c = faltan{i};
    tipo_texto = false;
    if nargin >= 3 && ismember(c, ref.Properties.VariableNames)
        v = ref.(c);
        tipo_texto = isstring(v) || iscell(v) || ischar(v);
    end
    if tipo_texto
        if nargin >= 3 && iscell(ref.(c))
            T.(c) = repmat({''}, height(T), 1);
        else
            T.(c) = repmat(string(missing), height(T), 1);
        end
    else
        T.(c) = nan(height(T), 1);
    end
end
end
