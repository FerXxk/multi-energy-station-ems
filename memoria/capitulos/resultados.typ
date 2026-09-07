= Resultados <cap-resultados>

// Cifras de la campaña con la constante de la regla a 8 EUR/kg (tandas *_8 del 04-09).

Este capítulo presenta la ejecución de la campaña descrita en el @cap-metodologia y la comparación cuantitativa. Se documenta primero cómo se produjeron los resultados (la cadena de _scripts_, el diseño de repeticiones y las comprobaciones de validez) y después las cifras, en el mismo orden del capítulo anterior: el resultado de la variante predictiva, el diagnóstico que reorientó el trabajo y la Versión C con el análisis de contribución de sus componentes.

== Cadena de ejecución <sec-cadena-ejecucion>

Cada simulación es el resultado de encadenar seis piezas, todas ellas en el repositorio del trabajo:

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (center, left, left),
    table.header([*\#*], [*Script*], [*Función*]),
    [1], [`preparar_workspace_simulink.m`], [Construye `datos_OASIS.mat` a partir de los CSV crudos de NASA POWER y ENTSO-E: normaliza las _features_ de las dos redes con los mismos parámetros con que se entrenaron, genera la irradiancia a 1 s con ruido de nubes de semilla fija (42) y guarda las series horarias de precio y de cielo claro. Se ejecuta una sola vez.],
    [2], [`Demanda_Coches_Aleatoria.m`], [Genera el perfil estocástico de demanda de vehículos de una semilla dada, `perfil_EV_s<n>.mat`. Se invoca automáticamente si el perfil de la semilla no existe; para horizontes de varios días, `construir_demanda_multidia.m` encadena perfiles según el día de la semana real.],
    [3], [`init_OASIS.m`], [Recorta todas las series al periodo simulado más 168 h de precalentamiento (el _lookback_ de la red de precio) y las publica en el _workspace_ base, de donde las leen los bloques _From Workspace_ del modelo.],
    [4], [`OASIS.slx`], [El modelo. El EMS vive en un bloque `MATLAB Function` y las dos previsiones en sendas S-Functions, `lstm_sol.m` y `lstm_precios.m`.],
    [5], [`guardar_resultados_ems.m`], [Calcula los KPIs de una simulación a partir de las señales registradas y guarda un `.mat` con las series completas y el bloque de indicadores.],
    [6], [`campana_simulacion.m`], [Recorre la matriz escenarios × semillas, orquestando los pasos 2 a 5.],
  ),
  caption: [Cadena de _scripts_ que produce cada simulación de la campaña.],
) <tbl-cadena-scripts>

La agregación posterior corre a cargo de `resumen_campana.m`, que recopila todos los `.mat` de resultados y construye una fila por simulación y otra por versión × escenario, y de `analisis_ablacion.m`, que compara cada versión contra una referencia emparejando por escenario y semilla y descarta automáticamente las tandas de otro horizonte. `descomponer_importacion.m` reparte la energía importada entre sus cuatro destinos (vehículos, electrolizador, compresor y batería) en proporción al consumo instantáneo de cada uno, y calcula el precio ponderado al que compra cada destino. `medir_reserva_ociosa.m` construye el contrafactual: cuánta de la importación destinada al electrolizador podría haber salido de la batería sin bajar de un nivel de estado de carga dado.

Cada variante del EMS es un archivo separado que difiere del anterior en los puntos estrictamente necesarios, y cada tanda tiene un criterio de aceptación que detecta un bloque mal pegado antes de mirar ningún coste: una descarga de batería nula delata un error de signo.

== Diseño de repeticiones y comparación pareada <sec-diseno-pareado>

El perfil de demanda es estocástico: una única realización no permite distinguir el efecto de la estrategia de control del ruido de la tirada. La campaña se organiza como una matriz de cuatro escenarios (@tbl-escenarios) por varias semillas, con una propiedad que gobierna todo el análisis posterior: la semilla $n$ genera exactamente el mismo perfil de demanda en todas las versiones del EMS, el mismo número de vehículos, las mismas horas de llegada y las mismas energías por sesión.

Esto permite comparar de forma pareada: en lugar de contrastar la media de una versión contra la media de otra, se calcula la diferencia semilla a semilla. El ruido de demanda, común a los dos miembros de cada par, se cancela en la diferencia, y el contraste gana potencia de forma considerable. Todas las diferencias de este capítulo son pareadas y se expresan en el sentido versión menos referencia; se reportan con su media, su mediana, el recuento de pares en que la versión gana y el $p$-valor del test de rangos con signo de Wilcoxon, por las razones expuestas en @sec-metricas.

Cada simulación de 24 h cubre 86 401 muestras por señal con paso de integración de 1 s, y las de una semana, siete veces más; el EMS se evalúa a ese paso y las dos S-Functions de previsión emiten una nueva predicción de 24 valores una vez por hora simulada.

== Alcance de lo ejecutado <sec-alcance>

La @tbl-alcance resume las tandas que sostienen los resultados de este capítulo. Todas las comparaciones se hacen dentro de un mismo horizonte.

#figure(
  table(
    columns: (auto, auto, auto, 1fr),
    align: (left, left, right, left),
    table.header([*Tanda*], [*Horizonte*], [*Pares*], [*Qué es*]),
    [A], [24 h], [40], [EMS heurístico de referencia (@sec-ems-referencia).],
    [B], [24 h], [40], [Variante predictiva: previsiones inyectadas en las reglas de A, con arbitraje dimensionado (@sec-iteracion).],
    [B con oráculo], [24 h], [40], [La misma variante con previsión perfecta.],
    [A, B], [7 días], [20], [Control de horizonte de la comparación anterior (regla a 6,12 €/kg).],
    [A, C0, C\_p, C], [7 días], [20], [Análisis de contribución de la Versión C (@tbl-ablacion-E), contra A a 7 días, con la constante de la regla a 8 €/kg.],
    [A, C0, C\_p, C a 6,12 €/kg], [7 días], [20], [Sensibilidad a la constante económica de la regla (@sec-res-sensibilidad).],
  ),
  caption: [Tandas ejecutadas. Los pares son combinaciones escenario × semilla; las semillas son las mismas en todas las tandas de un mismo horizonte. Todas las tandas llevan en la regla el coste de reposición de 8 €/kg salvo el control de horizonte de B, que conserva el índice de 6,12; la @sec-res-sensibilidad muestra que esa constante cambia el coste semanal en menos de medio euro.],
) <tbl-alcance>

== Verificación previa de los resultados <sec-verificacion-resultados>

La @fig-res-panorama muestra una semana completa de simulación con la Versión C: es la referencia visual sobre la que se leen tanto las comprobaciones de esta sección como el mecanismo que describen las siguientes.

#figure(
  image("../img/fig_res_panorama.png", width: 100%),
  caption: [Una semana completa del escenario laborable soleado con la Versión C, semilla 1. De arriba abajo: potencias en el bus de alterna (fotovoltaica, electrolizador, carga de vehículos, importación y exportación de red), precio horario del mercado diario, estado de carga de la batería con su reserva del 60 % y nivel de los dos tanques de hidrógeno con la zona crítica sombreada.],
) <fig-res-panorama>

El residuo máximo del balance de potencia del nudo de alterna, que `guardar_resultados_ems.m` reconstruye en cada instante y normaliza por la escala de potencia de la instalación, es del orden de $10^(-15)$ %. El error de la previsión de precio a una hora es exactamente cero en las tandas con oráculo y en las dos tandas de C con el modo mercado diario, lo que funciona como control del diseño pareado.

Los integradores de los dos tanques de `OASIS.slx` tienen desactivada la saturación de salida, de modo que el inventario puede bajar de cero si una realización de la demanda agota el tanque antes de que el electrolizador reponga, y el nivel del tanque de alta se hace negativo en algunas simulaciones del escenario nublado. En esas tiradas el modelo sirve un hidrógeno que físicamente no tiene. El efecto se cuantifica con el indicador de hidrógeno no servido, es decir, los kilogramos dispensados con el inventario en negativo, y se valora al precio externo dentro de la métrica principal, de modo que una versión que deja el tanque vacío paga por ello. Activar la saturación queda como corrección pendiente del modelo.

== El resultado de la variante predictiva <sec-res-iteracion>

La @tbl-res-B recoge la comparación de la variante predictiva contra A, sobre 24 horas y 40 pares, con la previsión real y con la perfecta. La lectura está en la @sec-iteracion; aquí se dejan las cifras.

#figure(
  table(
    columns: (1.4fr, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    table.header([*Versión − A, 24 h*], [*Coste total con H₂ (€/día)*], [*mediana*], [*gana*], [*$p$ rangos*]),
    [B (variante predictiva)], [−0,13], [+0,11], [15/40], [0,17],
    [B con oráculo], [−0,67], [+0,08], [18/40], [0,85],
  ),
  caption: [Variante predictiva frente a la Versión A (24 h, 40 pares), sobre la métrica principal. Ninguna de las dos diferencias es significativa y ambas quedan muy por debajo del umbral de relevancia. Sobre el coste neto, sin hidrógeno, la diferencia es de +0,06 € (mediana +0,22, 9/40) para B y de +2,42 € (mediana +0,23, 13/40) con oráculo; esa media procede del escenario nublado, donde el arbitraje con previsión perfecta compra más red (+25 kWh/día) y a cambio deja menos hidrógeno sin servir, y la mediana es la cifra que describe a la población.],
) <tbl-res-B>

Dos cifras completan el cuadro. La primera es la sub-dispersión de la previsión de precio: en el escenario nublado el recorrido previsto es el 36 % del real (31,9 frente a 88,5 €/MWh), y el 55 % en promedio, de modo que el test económico del arbitraje, que exige un beneficio neto mínimo tras pérdidas, casi nunca se activa con la previsión real, y cuando se activa con la perfecta no compensa. La segunda es que sobre la semana (control de horizonte, con la regla a 6,12 €/kg) la variante predictiva pierde 1,02 € en 19 de 20 pares frente a un recibo de 391: ampliar el horizonte no mejora el resultado del arbitraje.

Donde la previsión sí mejora de forma sistemática es en el servicio de hidrógeno. Todas las variantes predictivas evaluadas a lo largo del trabajo mantienen el tanque de alta más lleno y pasan menos tiempo en nivel crítico que A, en los dos horizontes y con $p < 0,05$ en casi todas las celdas; para B, +0,07 puntos de nivel medio (39/40) y −0,11 puntos de tiempo crítico (28/40). Y el efecto escala con la calidad de la previsión: con oráculo pasa a +0,92 y −1,08, entre diez y trece veces más, y el hidrógeno no servido baja de tres eventos en A a dos, y a cero en la implementación sin dimensionar del arbitraje, que es la que más energía movía. En el escenario nublado la previsión perfecta llega a reducir el tiempo crítico 18,9 puntos, el mayor efecto de la previsión medido en el trabajo, en el mismo escenario en que el modelo de precio está más sub-disperso.

== El diagnóstico: a dónde va la importación <sec-res-diagnostico>

La descomposición de la importación de A por destinos, sobre la semana, da el resultado que reorienta el trabajo:

#figure(
  table(
    columns: (1.4fr, auto, auto, auto),
    align: (left, right, right, right),
    table.header([*Destino de la importación (A, semana)*], [*kWh*], [*%*], [*Precio ponderado (€/MWh)*]),
    [Vehículos], [279], [21], [—],
    [Electrolizador], [*1 006*], [*76*], [121,5],
    [Compresor], [29], [2], [—],
    [Batería], [7], [< 1], [—],
    [Total importado], [1 321], [100], [121,5],
  ),
  caption: [Destino de la energía importada por la Versión A sobre una semana, medias de 20 simulaciones. En el mismo periodo la estación exporta 14 012 kWh a 39,3 €/MWh de media: un ratio de 10,6 a 1 en energía y de 3 a 1 en precio.],
) <tbl-res-import>

#figure(
  image("../img/fig_res_destino_import.png", width: 70%),
  caption: [Destino de la energía importada de la red, media semanal, para la Versión A y para las dos etapas de la Versión C. En A tres cuartas partes van al electrolizador; en C ese bloque se reduce a la mitad porque lo alimenta la batería.],
) <fig-res-destino>

En los instantes en que A importa para el electrolizador la batería está al 85,1 % de estado de carga de media y nunca baja del 69,1 %; ni el techo del 90 % ni el suelo del 20 % se tocan en toda la campaña semanal. El contrafactual de `medir_reserva_ociosa.m` indica que, con un piso del 60 %, el 79 % de esa importación podría haberse servido desde la batería y que la exportación posterior repone el 90 % de lo desviado, de modo que el flujo es sostenible y no consume una reserva. Por escenario, el electrolizador compra a 114 €/MWh en el laborable soleado, 112 en el fin de semana, 93 en el volátil y 149 en el nublado, donde compra en horas de hasta 194 €/MWh pese al umbral de 149 que la regla dice respetar: corresponde al defecto 7 de la @sec-defectos.

== La Versión C <sec-res-E>

=== Frente a la heurística de referencia

#figure(
  table(
    columns: (1.5fr, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    table.header([*C − A, semana, 20 pares*], [*media*], [*mediana*], [*gana*], [*$p$ rangos*]),
    [Coste total con hidrógeno (€)], [*−52,3 (−13,9 %)*], [−46,9], [20/20], [$9,6 dot 10^(-5)$],
    [Coste corregido (€)], [−56,8], [−53,9], [20/20], [$9,6 dot 10^(-5)$],
    [Coste neto (€)], [−67,7 (−17,3 %)], [−71,3], [20/20], [$9,6 dot 10^(-5)$],
    [Importación (kWh)], [−717 (−54 %)], [−667], [20/20], [$9,6 dot 10^(-5)$],
    [Autosuficiencia (puntos)], [+6,7 (87,7 → 94,3)], [+6,3], [20/20], [$9,6 dot 10^(-5)$],
    [Energía descargada por la batería (kWh)], [539 → 1 208 (×2,2)], [], [], [],
    [Tiempo en nivel crítico (puntos)], [+4,0], [+2,1], [0/20], [$9,6 dot 10^(-5)$],
    [Nivel mínimo del tanque de alta (puntos)], [−3,5], [−2,4], [2/20], [$6,7 dot 10^(-4)$],
    [Hidrógeno no servido (kg/semana, escenario nublado)], [0,82 → 3,07], [], [], [solo en ese escenario],
  ),
  caption: [Versión C frente a la Versión A sobre una semana. Negativo es mejor en las tres filas de coste y en la importación. Las tres métricas de coste coinciden en signo y orden, y la diferencia supera en cinco veces el umbral de relevancia de 9,33 € por semana.],
) <tbl-res-E>

#figure(
  image("../img/fig_res_coste_escenario.png", width: 95%),
  caption: [Coste total con hidrógeno por escenario y semana, Versión A frente a Versión C. Cada punto es una semilla; las líneas unen los pares con la misma demanda. Un valor negativo es un ingreso neto por la exportación.],
) <fig-res-coste>

La mejora aparece en los cuatro escenarios: −49,0 € en el laborable soleado, −57,0 en el nublado, −36,8 en el fin de semana y −66,2 en el volátil, en los cinco pares de cada uno. El orden no lo fija el excedente disponible para reponer, sino el precio al que compraba el electrolizador: el ahorro es mayor donde más caro compraba. El ahorro son los kilovatios-hora que pasan de la red a la batería multiplicados por el margen de precio, y esa cantidad manda sobre el excedente disponible.

Conviene situar la magnitud de esa diferencia, porque un porcentaje de mejora solo significa algo si se sabe contra qué se mide. La referencia no es una regla ingenua construida para perder, sino la heurística más avanzada del trabajo antecedente @molero2025ems, ya validada sobre su propia microrred: incorpora de partida el reparto dinámico entre batería y electrolizador según el estado de carga, el tiempo mínimo de funcionamiento con histéresis y anti-rebote en los equipos electroquímicos, la gestión de los dos niveles de presión con su compresor y la decisión económica de producir frente a comprar (@sec-ems-referencia). Es decir, la Versión A ya trae los mecanismos que distinguen a un EMS de reglas maduro de un simple reparto por prioridades, y las dos versiones comparadas están construidas sobre ese mismo código con un único bloque de diferencia. Que sobre esa base quede un 14 % del recibo sin capturar, y que se recupere con un cambio de diez líneas en el orden en que se usa la batería, es lo que da valor al resultado: el margen no estaba donde lo dejaría una heurística mal hecha, sino en una decisión que la regla de referencia tomaba correctamente por separado y no coordinaba. Los siete puntos de la @sec-defectos matizan esta lectura sin invertirla: la referencia es una implementación buena pero no óptima, y por eso el trabajo declara cuál de sus defectos corrige (el 6, y el 7 solo en la decisión programada) y cuáles deja intactos en ambas versiones.

El precio de la mejora está en las tres últimas filas. La batería cicla 2,2 veces más energía, y la degradación no está modelada; el párrafo siguiente acota lo que eso puede valer. Y el servicio de hidrógeno empeora en el escenario nublado: el tiempo en nivel crítico sube 9,3 puntos y el hidrógeno no servido pasa de 0,82 a 3,07 kg por semana, lo que representa el 1,8 % de la demanda de esa semana frente al 0,5 % de A. Esa penalización está incluida en el coste total, y por eso en ese escenario el coste corregido mejora 75 € y el total solo 57; pero es un dato de operación que la métrica de coste no debe ocultar. El mecanismo no es el uso de la batería en sí: la pila de combustible no arranca en ninguna de las 40 simulaciones. Es su interacción con el defecto 3 de la @sec-defectos: al amanecer con la batería por debajo del 80 %, el reparto por tramos asigna al electrolizador el 40 % del excedente en vez del 70 %, y en el día nublado no hay horas baratas para compensarlo.

El ciclado adicional solo puede acotarse en euros de forma aproximada. La Versión C descarga 669 kWh más por semana que A, dos tercios de un ciclo completo de la batería de 1 MWh. Una cuenta contable ingenua, con una inversión del orden de 300 €/kWh repartida entre los 3 000 a 4 000 ciclos de vida del ion-litio estacionario @faisal2018ess, asigna a cada ciclo completo entre 75 y 100 €, y al ciclado adicional de C entre 50 y 67 € por semana: del orden del ahorro de 52 €. Esa cuenta supone, sin embargo, que la batería muere por ciclos, y a este ritmo no lo hace: A completa unos 28 ciclos al año y C unos 63, de modo que agotar 3 500 ciclos llevaría más de medio siglo, muy por encima de la vida por calendario de 10 a 15 años que fija el final de la batería con las dos estrategias. Cuando domina el calendario, el coste marginal de un ciclo adicional es una fracción pequeña del contable y el ahorro de C se mantiene. Cuál es esa fracción no puede afirmarse sin un modelo de degradación por profundidad de descarga, como el que emplea @techno_economic_charging para dimensionar la batería de una estación de carga rápida; es la sensibilidad más importante que queda por hacer.

#figure(
  image("../img/fig_res_dia_nublado.png", width: 95%),
  caption: [Un día del escenario nublado, hora a hora, para la misma semilla: precio, estado de carga de la batería, potencia del electrolizador e importación de red. En C la batería baja hasta la reserva del 60 % alimentando al electrolizador y la importación desaparece en esas horas; en A la batería se mantiene llena y el electrolizador consume red.],
) <fig-res-dia>

#figure(
  image("../img/fig_res_tanque_nublado.png", width: 95%),
  caption: [Nivel del tanque de alta a lo largo de la semana nublada, misma semilla, con la zona crítica sombreada. C pasa más tiempo en la zona crítica que A.],
) <fig-res-tanque>

=== Contribución de cada componente

#figure(
  table(
    columns: (1.6fr, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    table.header([*Contraste, coste total con H₂ (€/semana)*], [*media*], [*mediana*], [*gana*], [*$p$ rangos*]),
    [C0 (solo batería → electrolizador) − A], [*−47,1*], [−45,4], [20/20], [$9,6 dot 10^(-5)$],
    [C\_p (+ programación con persistencia) − C0], [−5,1], [−3,0], [19/20], [$6,4 dot 10^(-4)$],
    [C (+ programación con LSTM) − C\_p], [*0,00*], [0,00], [—], [idénticas],
  ),
  caption: [Análisis de contribución de la Versión C. Las dos últimas tandas son idénticas a precisión de máquina en los 40 indicadores de los 20 pares.],
) <tbl-res-ablacion>

Alimentar el electrolizador desde la batería explica el 90 % de la mejora y supera el criterio de falsación —mejorar en los dos escenarios con excedente suficiente para reponer—, así como las predicciones de magnitud: la importación destinada al electrolizador cae un 48 % (se previó al menos un 40 %) y la energía descargada sube 811 kWh semanales (se previeron unos 1 000).

La programación añade 5,1 € por semana, significativa pero por debajo del umbral de relevancia. El mecanismo no está en el precio al que compra el electrolizador, que se mantiene (123,2 → 122,9 €/MWh), sino en el volumen: compra menos (−45 kWh) y produce algo menos de hidrógeno (−0,5 kg). En el escenario nublado sigue pagando 147 €/MWh porque la regla de emergencia en nivel crítico, que hereda el test económico de A con su defecto 7, actúa el 70 % del tiempo; el planificador solo manda fuera de esa banda, y ahí la batería ya cubre casi todo. El escenario volátil es, de hecho, donde menos aporta (−1,9 €).

La red neuronal de precio no cambia ningún resultado: su efecto es exactamente cero. La explicación está en la @sec-iteracion: entre las 13:00 y las 24:00 las 24 horas del horizonte están publicadas, y por la mañana lo único no publicado son las primeras horas de la madrugada siguiente, las más baratas del día tanto para la red como para la persistencia, y por eso ninguna de las dos señales cambia nunca el orden de mérito. La previsión solar sí interviene en el planificador y no se ha aislado; su contribución está dentro de los 5,1 € de la programación.

=== Sensibilidad a los precios del hidrógeno <sec-res-sensibilidad>

El primer supuesto variado es la constante de la regla. El análisis se ha ejecutado dos veces, con `H2_PRECIO_EXT_KG` a 8 €/kg (umbral de 149 €/MWh, la campaña que se reporta) y a 6,12 €/kg (umbral de 114). El cambio mueve el coste semanal de A 0,12 € de media (−0,49 € en el nublado y cero en los otros tres escenarios) y el de C 0,02 €, de modo que las diferencias pareadas de la @tbl-res-E y la @tbl-res-ablacion cambian, como mucho, en la primera decimal. La razón es el defecto 7 de la @sec-defectos: con el tanque de baja por encima del 68 % el test heredado evalúa solo el coste de comprimir, y el umbral económico casi nunca es el que decide. El nublado, único escenario con precios entre 114 y 149 €/MWh en horas de déficit, es también donde A ya compraba a 149 por esa misma vía.

El segundo supuesto es el precio de valoración. Las conclusiones de la @tbl-res-E tampoco dependen de la valoración de la energía terminal ni del hidrógeno: el coste neto, el corregido y el total coinciden en signo y en orden de magnitud, y la diferencia de C es un orden de magnitud mayor que el efecto de valorar la batería al precio de importación en vez de al de exportación. No ocurría lo mismo en la comparación de la variante predictiva, donde el signo del coste corregido sobre la semana cambiaba según el precio de valoración entre 2,8 y 104 €/MWh; esa fragilidad es una de las razones por las que la semana se presenta allí como control de horizonte y no como evidencia principal.
