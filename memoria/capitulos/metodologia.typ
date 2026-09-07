= Metodología <cap-metodologia>

== Enfoque general

Este capítulo describe cómo se combinan los elementos presentados hasta ahora (el dimensionamiento y los perfiles de demanda del @cap-datos-ev y los modelos de predicción del @cap-lstm) en el sistema de gestión de energía de la estación. El capítulo está organizado alrededor de una única versión final del EMS, la Versión C, y del camino que llevó hasta ella. Se parte del EMS heurístico de referencia heredado de @molero2025ems (Versión A), se resume lo que enseñó el intento de mejorarlo con predicción, y se describe en detalle el diseño final, que separa dos decisiones que la heurística tomaba juntas: de dónde sale la energía que consume el electrolizador y cuándo conviene fabricar el hidrógeno.

El principio metodológico es el de un diseño comparativo controlado. Todas las variantes del EMS se ejecutan sobre exactamente el mismo modelo físico de Simulink, con los mismos perfiles de entrada (fotovoltaica, demanda eléctrica, demanda de hidrógeno y precio), y solo se sustituye el _script_ del bloque de decisión. Las versiones se construyen además de forma incremental: cada una difiere de la anterior en un único punto, con un interruptor por mecanismo. La diferencia observada entre dos tandas se puede atribuir así a un cambio concreto y no a un rediseño global. La Versión C se evalúa desactivando selectivamente cada uno de sus componentes (_ablation study_): la misma lógica con y sin cada uno de ellos.

== Entorno de simulación: la microrred OASIS

El modelo utilizado es la microrred OASIS, implementada en Simulink dentro de `SimugridElectrolinera/` (`init_OASIS.m`, `OASIS.slx`). Esta microrred incluye generación fotovoltaica, un electrolizador PEM, un tanque pulmón de baja presión (`LOH`), un compresor, un tanque surtidor de alta presión (`LOH_High`), una pila de combustible, carga de vehículos eléctricos y demanda de hidrógeno, con las S-Functions `lstm_sol.m` y `lstm_precios.m` ya integradas en el bucle de simulación (@cap-lstm). La @fig-oasis-3d muestra la disposición física que se modela (marquesinas fotovoltaicas sobre los puntos de suministro y recinto técnico con los equipos electroquímicos y los tanques) y la @fig-arquitectura-oasis, los bloques del modelo y las señales que intercambian con el EMS.

La @tbl-planta reúne los parámetros de la instalación simulada, que hasta aquí se han ido justificando por separado en el @cap-estado-arte y el @cap-datos-ev.

#figure(
  table(
    columns: (1.1fr, 1.5fr, 1.6fr),
    align: (left, left, left),
    table.header([*Subsistema*], [*Parámetro*], [*Valor*]),
    [Generación fotovoltaica], [Configuración del array], [24 módulos en serie × 35 ramas en paralelo, ≈508 kWp (@cap-estado-arte)],
    [Batería (BESS)], [Capacidad / potencia], [1 MWh; ≈494 kW (0,5C), 380 V y 1 300 A; estado de carga inicial del 70 %],
    [Electrolizador PEM], [Potencia / consumo específico], [200 kW; ≈50 kWh/kg; entrega a 40 bar],
    [Compresor], [Potencia / consumo específico], [15 kW; 3,6 kWh/kg; etapa de baja a alta presión],
    [Pila de combustible (PEMFC)], [Potencia], [130 kW de diseño (`PmaxFC`); el bloque electroquímico está parametrizado con 120 celdas de 600 cm² y 600 A, y entrega menos],
    [Tanque de baja (`LOH`)], [Volumen / presión], [3,1 m³; 40 bar máximos, 26 bar iniciales; 10,1 kg lleno],
    [Tanque de alta (`LOH_High`)], [Volumen / presión], [0,41 m³; 600 bar máximos, 480 bar iniciales (80 % de nivel al arrancar); 20,0 kg lleno con la ecuación de gas ideal del bloque, 14,2 kg con gas real (@cap-estado-arte)],
    [Cargadores de vehículo eléctrico], [Número / potencia], [2 × 50 kW en corriente continua (@sec-num-cargadores)],
    [Surtidor de hidrógeno], [Número / caudal], [1 módulo a 1,2 kg/min; 700 bar es la presión nominal del depósito del vehículo (SAE J2601), no la del almacenamiento (@cap-estado-arte)],
    [Conexión a red], [Tipo / valoración], [Bidireccional, sin límite de potencia contratada en el modelo; energía valorada al precio horario del mercado diario, sin peajes ni cargos (@sec-metricas)],
  ),
  caption: [Configuración de la estación OASIS tal y como está parametrizada en `OASIS.slx`. Las cifras de hidrógeno almacenado siguen la ecuación de estado del propio bloque, que sobrestima la masa a alta presión; el efecto sobre la lectura de los resultados se discute en el @cap-estado-arte.],
) <tbl-planta>

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 4pt,
    image("../img/electrolinera-iso-NO.png", width: 100%),
    image("../img/electrolinera-iso-NE.png", width: 100%),
    image("../img/electrolinera-iso-SO.png", width: 100%),
    image("../img/electrolinera-iso-SE.png", width: 100%),
  ),
  caption: [Vistas isométricas de la estación OASIS desde los cuatro cuadrantes (noroeste, noreste, suroeste y sureste). Las dos marquesinas fotovoltaicas cubren los dos cargadores de vehículo eléctrico de 50 kW y el surtidor de hidrógeno; el recinto vallado agrupa los contenedores de batería, electrolizador, compresor y pila de combustible, el tanque tampón de baja presión y el bastidor de botellas de alta presión.],
) <fig-oasis-3d>

#page(flipped: true)[
  #figure(
    image("../img/arquitectura_modulos_oasis.png", width: 100%),
    caption: [Arquitectura por módulos del modelo `OASIS.slx`. Los bloques se agrupan por la red que intercambian: consignas del EMS hacia los equipos (trazo discontinuo naranja), medidas de los equipos hacia el EMS (discontinuo gris), potencia eléctrica en el bus de alterna (azul) y flujo de hidrógeno (verde), con los nombres de las señales tal y como aparecen en Simulink. El EMS es un único bloque `MATLAB Function` con once entradas y seis salidas; las dos S-Functions de previsión le entregan `PVPred` y `PrecioPred`.],
  ) <fig-arquitectura-oasis>
]

El grupo de investigación dispone además de un segundo modelo, `AIHRE_Puerto_Negocio1v1.slx`, con una arquitectura de componentes muy similar a la del Caso 2 de Molero Almazán @molero2025ems (electrolizador PEM, compresor, doble tanque de H2, pila de combustible, batería y demanda de H2 externa). Ese modelo no se emplea en este trabajo, que se realiza íntegramente sobre OASIS, y se conserva fuera del árbol de trabajo del repositorio.

== El EMS de referencia — Versión A <sec-ems-referencia>

El EMS heurístico previo de OASIS gestionaba únicamente el electrolizador mediante una máquina de estados de tres etapas (Paro → Standby → Run, señalizada mediante los vectores `EstEl`/`DiscEl`), dejaba la pila de combustible permanentemente en `standby` y no llegaba a asignar consigna alguna a la batería. Como punto de partida se ha portado a esta misma interfaz el EMS heurístico más completo descrito en @molero2025ems (Caso 2, versión 4.2), que sí implementa:

- Reparto dinámico de potencia entre batería y electrolizador según tramos de estado de carga (SOC): 80/20 con SOC bajo, 60/40 con SOC intermedio y 30/70 con SOC alto. El reparto favorece la producción de H2 cuando la batería está casi llena.
- Uso efectivo de la pila de combustible para cubrir déficit, tras la batería, en vez de mantenerla siempre parada.
- Tiempo mínimo de funcionamiento (TMF) de 2 horas para electrolizador y pila, con histéresis y anti-rebote temporal, para evitar conmutaciones rápidas de estos equipos.
- Decisión económica de producción propia de H2 frente a compra externa, comparando el coste de producir un kilogramo localmente (a partir del precio eléctrico instantáneo) con el precio de un suministro externo.

El bloque `MATLAB Function` de `OASIS.slx` tiene 11 entradas y 6 salidas. Entre las entradas está `PrecioPred`, que no alimentaba ninguna decisión, y entre las salidas no hay ninguna de compra externa de H2. Todas las versiones del EMS de este trabajo mantienen esa firma, de modo que sustituyen al _script_ del bloque sin tocar el cableado de Simulink. La adaptación respecto al código de @molero2025ems ha requerido los siguientes cambios, comentados en `codigo/EMS/ems_A.m`:

1. *Conservar la máquina de estados existente.* El EMS de referencia calcula consignas de potencia de forma puramente algebraica, sin máquina de estados; para no modificar los bloques de Simulink ya construidos, la lógica de decisión se ha conservado y se traduce, en un último paso, a los pulsos `DiscEl`/`DiscFC` que gobiernan las transiciones Paro/Standby/Run, usando el TMF como condición de arranque/parada.
2. *Reescalar los umbrales de presión a nivel porcentual.* El EMS original trabaja con presiones absolutas en bar (tanque de alta hasta 900 bar de techo de seguridad). OASIS expresa el nivel de ambos tanques en porcentaje (`LOH`, `LOH_High`), sobre los límites de diseño propios de la instalación. El bloque de tanque de alta empleado en las simulaciones está parametrizado a 600 bar de presión máxima (@cap-estado-arte), frente a los 900 bar de techo de seguridad del tanque de @molero2025ems. Las dos escalas son relativas, así que la @tbl-umbrales-ems no cambia: los porcentajes de la tabla se obtienen como la fracción que cada umbral de Molero Almazán representa sobre su propio rango de diseño (bar/900), y esa fracción se traslada a la escala 0--100% de OASIS.

  Ambas magnitudes miden lo mismo: los bloques de tanque de OASIS calculan la presión a partir del hidrógeno almacenado y entregan el nivel como $"LOH" = P \/ P_max times 100$, es decir, como fracción de presión sobre la presión máxima del tanque, que es la magnitud en la que están expresados los umbrales de @molero2025ems.

  Sí tiene una consecuencia que hay que explicitar: un mismo porcentaje no representa la misma presión absoluta en los dos trabajos. El umbral de banda baja del 76%, por ejemplo, equivale a 680 bar sobre el rango de 900 bar de @molero2025ems y a 456 bar sobre los 600 bar con los que está parametrizado el tanque de OASIS. El reescalado conserva la posición relativa del umbral dentro del rango útil del tanque, y con ella la lógica de decisión del EMS, pero no el punto de operación termodinámico. Dado que todas las versiones comparadas emplean los mismos umbrales, la comparación entre ellas no se ve afectada; sí condiciona la comparación cuantitativa directa con los resultados de @molero2025ems, que se hace por tanto en términos relativos.
3. *Sin puerto de compra externa de H2: decisión económica implementada como constante interna.* Al no existir salida `H2Ext` ni entrada de precio externo en el bloque real, la comparación de coste "producir localmente vs. comprar fuera" que describe @molero2025ems se ha implementado con un precio de referencia externo fijo (`H2_PRECIO_EXT_KG`). Se toma como base el índice ibérico oficial de precio mayorista del H2 verde (Mibgas IBHYX @mibgas_ibhyx2025), 6,12 €/kg en su revisión del 15/07/2025, que sustituye al hipotético "5-6 €/kg" que citaba Molero Almazán; pero ese índice es el precio del hidrógeno en la puerta del electrolizador de referencia, no en la hidrogenera. El hidrógeno que la estación tendría que comprar llega en cisterna y hay que comprimirlo, y con esos dos conceptos añadidos el coste de reposición efectivo se estima en 8 €/kg. La campaña que se reporta en el @cap-resultados usa en la regla ese coste de reposición, `H2_PRECIO_EXT_KG = 8`, con el que producir sale más barato que comprar siempre que el precio spot esté por debajo de unos 149 €/MWh (con los consumos específicos adoptados, 50 kWh/kg del electrolizador y 3,6 kWh/kg del compresor); la misma campaña con el índice sin corregir, 6,12 €/kg (umbral de 114 €/MWh), se ha ejecutado como análisis de sensibilidad (@sec-escenarios). La constante decide si se fuerza el electrolizador y el compresor, pero no hay ninguna salida que module un suministro externo real: si producir localmente no compensa, ese déficit de hidrógeno no se cubre por esta vía en el modelo actual, y en la métrica de coste se valora como coste de oportunidad al precio de reposición de 8 €/kg (@sec-metricas). Añadir un mecanismo físico de compra externa queda como ampliación pendiente; la forma natural de implementarlo es un puerto `H2Ext` alimentado por un suministro discreto en cisterna (_tube trailer_), y como una cisterna entrega centenares de kilogramos de una vez (muy por encima de la capacidad conjunta de los dos tanques de OASIS), la decisión pasaría a ser un problema de reposición con coste fijo de pedido, es decir, una decisión con horizonte.

#figure(
  table(
    columns: (1.6fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Umbral*], [*Molero Almazán (bar)*], [*OASIS (%)*]),
    [Tanque de baja — mínimo para comprimir], [22 / 40], [55],
    [Tanque de baja — techo electrolizador], [38 / 40], [95],
    [Tanque de baja — reserva compresor], [27 / 40], [68],
    [Tanque de alta — techo de seguridad], [900 / 900], [97],
    [Tanque de alta — banda baja (activa H2)], [680 / 900], [76],
    [Tanque de alta — banda baja (desactiva)], [710 / 900], [79],
    [Tanque de alta — nivel crítico], [650 / 900], [72],
  ),
  caption: [Reescalado de los umbrales de nivel de tanque de @molero2025ems (bar, sobre su rango de diseño) a los límites propios de OASIS (%). Cada porcentaje es la fracción que el umbral representa sobre el rango de diseño de *su propio* tanque, y `LOH` es en ambos casos una fracción de presión, por lo que el traslado es dimensionalmente consistente. Lo que se conserva es la posición relativa del umbral dentro del rango útil, no la presión absoluta: el 76 % equivale a 680 bar sobre los 900 bar de @molero2025ems y a 456 bar sobre los 600 bar con los que está parametrizado el tanque de OASIS.],
) <tbl-umbrales-ems>

La potencia máxima de la batería (`PmaxBat`) usaba provisionalmente 100 kW (coincidiendo con el pico de dos cargadores EV de 50 kW) a falta de una cifra real. Con los parámetros reales del bloque de batería de OASIS (@cap-estado-arte: 380 V de tensión de circuito abierto, 1 300 A de corriente máxima de carga/descarga, es decir 0,5C), `PmaxBat` se fija en ≈0,5 MW ($380 "V" times 1300 "A" ≈ 494 "kW"$) en el código de todas las versiones.

Los umbrales de tanque de la @tbl-umbrales-ems son los que se trasladan de @molero2025ems; el resto de constantes que gobiernan la decisión de la Versión A se recogen en la @tbl-parametros-A. Todas ellas se mantienen sin cambios en la Versión B y en la Versión C, de modo que la @tbl-parametros-E solo añade lo propio de esta última.

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, right, left),
    table.header([*Parámetro*], [*Valor*], [*Qué gobierna*]),
    [Reparto excedente batería / electrolizador], [80/20 · 60/40 · 30/70], [Fracción del excedente que va a cada uno según el estado de carga, con saltos discretos en el 40 % y el 80 % (defecto 3 de la @sec-defectos).],
    [`PmaxBat`], [≈494 kW], [Potencia máxima de carga y descarga de la batería, derivada del bloque (380 V × 1 300 A).],
    [Banda de estado de carga], [20 -- 90 %], [Suelo y techo de la batería. Ninguno de los dos llega a tocarse en la campaña semanal.],
    [`PmaxEl` / `PmaxFC`], [200 / 130 kW], [Potencia máxima del electrolizador y consigna máxima de la pila.],
    [TMF], [2 h], [Tiempo mínimo de funcionamiento del electrolizador y de la pila, con anti-rebote en las transiciones Paro/Standby/Run.],
    [Histéresis del electrolizador], [5 %], [Margen único de arranque y mantenimiento sobre el umbral de tanque (defecto 1 de la @sec-defectos).],
    [Consumos específicos], [50 / 3,6 kWh/kg], [Electrolizador y compresor; fijan el coste local del kilogramo con el que se evalúa la decisión económica.],
    [`H2_PRECIO_EXT_KG`], [8 €/kg], [Precio externo de referencia: producir sale a cuenta por debajo de 149 €/MWh. La campaña de sensibilidad lo repite con 6,12 €/kg (114 €/MWh).],
  ),
  caption: [Parámetros de decisión de la Versión A, comunes a las tres versiones comparadas. Los umbrales de nivel de los dos tanques están en la @tbl-umbrales-ems y la configuración física de la instalación, en la @tbl-planta.],
) <tbl-parametros-A>

La @fig-ems-logica resume esa lógica y señala los dos puntos que la Versión C modifica (@sec-ems-final).

#page(flipped: true)[
  #figure(
    image("../img/ems_logica_C.png", width: 100%),
    caption: [Lógica de decisión del EMS. En gris, la lógica común heredada de la Versión A: balance, reparto por estado de carga en la rama de excedente, cobertura del déficit por orden de mérito, decisión económica de producir hidrógeno y máquina de estados. En azul, los dos únicos cambios de la Versión C: la carga del electrolizador y del compresor se ofrece a la batería antes que a la red, y la decisión de producir pasa a ser un planificador de orden de mérito a 24 h que consume el precio publicado del mercado diario, la previsión de precio en las horas no publicadas y la previsión solar. La variante predictiva inyectaba las previsiones en los bloques 2 y 3 de A y no se representa.],
  ) <fig-ems-logica>
]

== Del EMS heurístico al EMS de programación: lo que enseñó la iteración <sec-iteracion>

La pregunta original del trabajo era si la previsión LSTM mejora al EMS heurístico. La forma más directa de responderla es la que se probó primero: una variante de la Versión A, la Versión B (`codigo/EMS/ems_B.m`), que consume las dos previsiones en el mismo punto en que la heurística toma sus decisiones. La previsión solar desplaza el reparto batería/electrolizador cuando anticipa una caída del excedente en las dos horas siguientes. La previsión de precio gobierna un arbitraje de batería dimensionado: se localiza la punta de precio prevista en las doce horas siguientes, se exige que el beneficio neto de comprar ahora y descargar en la punta supere un margen mayor que el error de previsión tras las pérdidas del ciclo, y la potencia de carga se calcula a partir de la energía que falta para llegar cargado a esa punta. Es el mismo diseño que la versión V4 de @molero2025ems. No es la salida cruda de las redes: las S-Functions entregan la señal combinada con su línea base (persistencia de cielo claro y persistencia de 24 h), con los pesos ajustados en validación (@cap-lstm), porque ninguna de las dos redes bate por sí sola a esa línea base en el agregado de 24 horas.

El dimensionado condiciona el resultado, y de ahí sale la propiedad que se le exige a cualquier regla que consuma una previsión. Una regla que traduzca «el precio va a subir» en una acción de magnitud fija, sin comprobar que haya excedente ni que el diferencial cubra las pérdidas, empeora el coste, y lo empeora más cuanto mejor es la previsión. La acción disparada por una previsión tiene por tanto que estar condicionada a esas dos comprobaciones y su magnitud tiene que salir del margen económico disponible, no de una constante: el valor de una previsión lo determina la regla que la consume, no la previsión por sí sola.

La variante predictiva quedó indistinguible de la Versión A en coste, con la previsión real y también con la perfecta —el propio precio y la propia irradiancia futuros, entregados a las S-Functions en modo oráculo—, y la superó de forma sistemática en las métricas de servicio de hidrógeno, con una mejora que escala con la calidad de la previsión (@cap-resultados). El oráculo es la cota superior: si con error nulo no gana, ninguna mejora de la previsión puede hacer que gane (@sec-escenarios). Dos medidas adicionales cerraron la línea del arbitraje de precio. La primera es que la previsión de precio, aun teniendo un error medio competitivo, comprime la amplitud del precio a entre el 36 % y el 55 % de la real en los días con recorrido: es la consecuencia esperable de una combinación convexa que minimiza el error medio, y arruina cualquier decisión que dependa de la magnitud de la punta. La segunda es estructural: la estación exporta 10,6 veces la energía que importa, e importa a 121--136 €/MWh mientras exporta a unos 40. El hueco que vale dinero en esta instalación está entre importar y exportar, no entre horas caras y baratas de importación.

Esa segunda medida indicaba dónde mirar, y la descomposición de la importación por destinos lo confirmó: entre el 74 % y el 78 % de la energía que la Versión A compra a la red va al electrolizador, y en los instantes en que la compra la batería está al 85 % de media y nunca por debajo del 69 %. La batería se llena con excedente que después se exporta a 40 €/MWh, mientras el electrolizador consume red a 120. A esto se añade que en el escenario nublado el electrolizador compra a 149,5 €/MWh (8,0 €/kg de hidrógeno, por encima del precio externo de referencia) porque el test económico heredado evalúa el coste de comprimir, no el de electrolizar, cuando el tanque de baja está por encima de su reserva. Son los defectos 6 y 7 de la @sec-defectos, y ninguna previsión los veía: la información necesaria (estado de carga, nivel de tanque y precio instantáneo) estaba ya en las entradas de la Versión A.

Una última observación reordena el papel de la previsión de precio. En el mercado diario de OMIE @omie_mercado_diario la sesión se celebra a las 12:00 CET y los precios horarios del día siguiente se publican hacia las 13:00. Un operador conoce por tanto con certeza los precios del resto del día en curso y, desde las 13:00, también los del día siguiente: entre 11 y 35 horas del horizonte no hay que predecirlas. Queda por prever la parte final del horizonte, la madrugada del día siguiente durante la mañana, y solo ese tramo. El diseño final incorpora esa información publicada como dato, y reserva la red neuronal para el tramo no publicado.

== Qué se corrige del EMS heredado y qué queda anotado <sec-defectos>

Al revisar en detalle el código del EMS de @molero2025ems heredado en la Versión A (`codigo/EMS/ems_A.m`) se identificaron siete puntos en los que el código no se corresponde del todo con su propia descripción textual, o en los que una decisión de diseño resulta cuestionable con independencia de si hay predicción o no. Los cinco primeros se detectaron por inspección del código y quedan recogidos en la @tbl-defectos-anotados; los dos últimos, al medir a dónde iba cada kilovatio-hora importado, son los que tienen peso económico y se detallan a continuación.

#enum(
  start: 6,
  [*La batería no alimenta al electrolizador.* En la rama de déficit la batería cubre la carga de los vehículos y, después, la decisión económica añade hasta 200 kW de electrolizador y el compresor. Esa carga nueva no se le ofrece a la batería: la absorbe la red, aunque la batería esté llena. Es el defecto con más peso económico de los siete, y el que corrige la Versión C.],
  [*Test económico del compresor aplicado al electrolizador.* Cuando el tanque de baja está por encima de su reserva, el coste local del kilogramo se calcula solo con el consumo del compresor (3,6 kWh/kg), de modo que el test pasa hasta precios superiores a 2 000 €/MWh; pero si pasa, fuerza también el electrolizador a plena potencia. El umbral económico de la regla (149 €/MWh con 8 €/kg; 114 con 6,12) solo actúa con el tanque de baja por debajo del 68 %.],
)

#figure(
  table(
    columns: (auto, 1fr, 2fr),
    align: (center, left, left),
    table.header([*Nº*], [*Defecto*], [*Qué hace el código heredado*]),
    [1], [Histéresis del electrolizador], [El texto de @molero2025ems describe dos umbrales, uno de arranque y otro de mantenimiento; su código emplea un único umbral del 5 % para ambos casos.],
    [2], [Tiempo mínimo de funcionamiento incondicional], [El TMF fuerza la potencia mínima con independencia del precio de red, de modo que el electrolizador puede quedar consumiendo red cara hasta agotarlo.],
    [3], [Conmutación discreta del reparto], [El reparto de potencia batería/electrolizador según el estado de carga salta de forma discreta en SOC = 40 % y SOC = 80 %, en lugar de interpolar entre esos puntos característicos.],
    [4], [Compresor sin protección temporal], [Se activa y desactiva de forma puramente algebraica según el nivel de los tanques, sin el tiempo mínimo, la histéresis y el anti-rebote que sí tienen el electrolizador y la pila.],
    [5], [Decisión económica de H2 todo-o-nada], [Cuando producir localmente resulta más barato que el precio externo de referencia, la potencia forzada salta directamente al 100 % del máximo disponible, en vez de escalar con el margen de ahorro.],
  ),
  caption: [Defectos del EMS heredado que se dejan anotados, sin corregir ni evaluar en este trabajo, detectados por inspección del código de `ems_A.m`. La numeración es la que emplea el texto al referirse a ellos.],
) <tbl-defectos-anotados>

Los defectos 1 a 5 de la @tbl-defectos-anotados se dejan anotados y no se corrigen ni se evalúan: hacerlo abriría la pregunta «¿ayuda corregir el EMS heredado?», distinta de la que el trabajo se plantea, y exigiría campañas adicionales. El 6 se corrige en la Versión C. El 7 se corrige en la decisión programada de C, pero no en su regla de emergencia, que hereda la de la Versión A (@sec-ems-final). Anotarlos tiene una consecuencia sobre la interpretación de los resultados: la comparación enfrenta variantes de una misma lógica de partida imperfecta, no una implementación óptima con otra, y una parte de la diferencia observada podría venir de que un cambio esquive incidentalmente alguno de los defectos no corregidos. Eso se tiene en cuenta al discutir, en el @cap-resultados, cómo el uso de la batería para el electrolizador interactúa con el defecto 3.

== El EMS final — Versión C <sec-ems-final>

La Versión C (`codigo/EMS/ems_C.m`; en las etiquetas de los ficheros de resultados esta versión conserva el nombre `E` con el que se desarrolló, igual que la Versión B conserva `B_prima2`, por trazabilidad con los registros de la campaña) parte de la Versión A y le hace dos cambios, cada uno con su interruptor. Todo lo demás —parámetros, umbrales, rama de excedente, TMF, histéresis y máquina de estados— es idéntico, para que cada diferencia observada sea atribuible a un cambio concreto. La idea que los une es separar dos decisiones que la heurística tomaba a la vez y con la misma regla: de dónde sale la energía que consume el electrolizador, y cuándo conviene fabricar el hidrógeno.

=== La batería alimenta al electrolizador

En la rama de déficit, la carga discrecional que crea la decisión de producir hidrógeno (electrolizador más compresor) se ofrece a la batería antes que a la red, mientras el estado de carga esté por encima de una reserva fija:

```matlab
P_disc = abs(min(RefEl, 0)) + max(0, Compresor);      % carga que ha creado la decision de H2
if (P_disc > 0) && (SOC > SOC_RESERVA)                 % SOC_RESERVA = 60 %
    aporte = min(P_disc, PmaxBat - abs(RefBat));
    RefBat = RefBat + aporte;                          % RefBat > 0 = descarga
end
```

El bloque tiene diez líneas y no consume ninguna previsión. Corrige el defecto 6: la energía que antes se exportaba a 40 €/MWh pasa a desplazar una compra a 120. La reserva del 60 % protege la cobertura de la carga de los vehículos; con un piso fijo de ese nivel queda disponible el 79 % de la energía que el electrolizador compraba a la red en la Versión A. Una reserva que variase con la previsión solar aportaría por tanto poco sobre la fija, y por eso la Versión C la deja constante.

=== Programación: el electrolizador produce en las horas más baratas que hacen falta

La decisión de producir hidrógeno deja de ser la puerta instantánea de la Versión A («producir si el precio está por debajo del umbral económico y el tanque de alta por debajo del 79 %») y pasa a ser una regla de orden de mérito sobre un horizonte de 24 horas, evaluada en cada paso:

1. Se estima la demanda de hidrógeno prevista como media móvil exponencial del caudal medido, con una constante de tiempo de 24 h. No existe puerto de previsión de demanda; es la hipótesis mínima y se declara como limitación.
2. Se estima cuánto excedente fotovoltaico gratis podrá absorber el electrolizador en el horizonte, a partir de la previsión solar `PVPred` convertida a potencia por forma (escalando la irradiancia prevista con los picos observados) y de la carga actual persistida.
3. Se calcula el hidrógeno que falta: reponer el tanque de alta hasta su objetivo (79 %) más la demanda prevista en el horizonte, menos el inventario del tanque de baja por encima de la reserva del compresor. Restado el excedente previsto, queda la energía que habrá que comprar a la red, y de ahí el número $n$ de horas de electrolizador a plena potencia, redondeado a bloques del TMF (2 h) para no arrancarlo y dejarlo a medias.
4. Se produce en la hora actual si está entre las $n$ más baratas del horizonte, es decir, si el número de horas futuras con precio previsto estrictamente menor que el actual es inferior a $n$.
5. Se conservan las dos puertas de la Versión A: nunca se produce por encima del precio del hidrógeno externo (el umbral económico, ahora evaluado con el coste completo de electrolizar y comprimir), y en nivel crítico del tanque de alta se produce igual que en A.

La propiedad que hace defendible esta regla, después de lo aprendido en la @sec-iteracion, es que solo usa el orden de los precios. Contar cuántas horas futuras son más baratas que la actual es invariante a cualquier transformación monótona de la previsión: multiplicar el precio previsto por 0,36 no cambia ni una decisión. Por tanto la sub-dispersión que invalidó el arbitraje no invalida la programación. La regla se autolimita en energía y no en potencia: compra exactamente las horas que faltan, y con el tanque lleno no produce aunque el precio sea nulo.

=== Qué hace cada previsión, y por qué

Las dos redes del @cap-lstm entran en la Versión C con funciones distintas, y se declaran por separado.

- *La previsión de precio alarga la información disponible.* El precio del mercado diario publicado a las 13:00 fija con certeza entre 11 y 35 horas del horizonte. La S-Function `lstm_precios.m` incorpora un modo mercado diario que, en cada hora simulada, sustituye por el precio real los horizontes ya publicados —el resto del día en curso y, a partir de las 13:00, todo el día siguiente— y deja la previsión combinada de la red para el tramo no publicado, que son las primeras horas de la madrugada siguiente cuando se evalúa por la mañana. Es estrictamente causal: solo se usan precios ya publicados en ese instante. El modo tiene una segunda variante que rellena el tramo no publicado con la persistencia de 24 horas en vez de con la red, y que sirve de línea base para medir la aportación de la LSTM de precio. Esto es distinto del modo oráculo, que entrega el precio real de las 24 horas siguientes a cualquier hora y no es desplegable.
- *La previsión solar valora el excedente que viene.* Estima, a partir de la forma y los picos de la irradiancia prevista, cuánta energía fotovoltaica sobrante podrá absorber el electrolizador en las próximas 24 horas, y esa cantidad se descuenta de la que hay que comprar. Decide sobre todo en el día nublado, donde la red debe anunciar que no habrá excedente; y es también donde el modelo solar tiene su mayor error (@cap-lstm), de modo que un fallo de la previsión se traduciría en comprar de menos y dejar el tanque corto.

Ninguna de las dos previsiones fija una potencia. Las dos entran como dato de un planificador cuya ejecución sigue en manos de los bloques heredados, y ahí está la diferencia con la primera variante predictiva: la previsión informa una decisión con margen económico, en lugar de disparar una acción de magnitud fija.

=== Parámetros y lo que no lleva

#figure(
  table(
    columns: (auto, auto, 1fr),
    align: (left, right, left),
    table.header([*Parámetro*], [*Valor*], [*Justificación*]),
    [`SOC_RESERVA`], [60 %], [Nivel de batería por debajo del cual no se alimenta al electrolizador. Medido sobre A: con ese nivel el 79 % de lo que el electrolizador compraba a la red podía salir de la batería; el suelo del 20 % para la carga de vehículos no se toca.],
    [`N_PLAN_H`], [24 h], [Horizonte del planificador, el de las S-Functions.],
    [`N_TMF_H`], [2 h], [Las horas se compran en bloques del tiempo mínimo de funcionamiento.],
    [`LOH_OBJ`], [79 %], [Objetivo de inventario del tanque de alta, el mismo umbral de desactivación de A.],
    [`LOH_OBJ_MAX`], [90 %], [Por encima de este nivel no se compra red para hidrógeno.],
    [`CAP_HIGH_KG`, `CAP_LOW_KG`], [20,0 / 10,1 kg], [Capacidades de los dos tanques con la ecuación de gas ideal del bloque, a 600 y 40 bar. El planificador las usa para convertir niveles de tanque en kilogramos.],
    [`H2_PRECIO_EXT_KG`], [8 €/kg], [Idéntico a A: techo de 149 €/MWh (114 en la campaña de sensibilidad a 6,12 €/kg).],
  ),
  caption: [Parámetros propios de la Versión C. Todos los demás son los de la Versión A.],
) <tbl-parametros-E>

Tres cosas que la Versión C no incluye, y que se declaran como líneas futuras en el @cap-conclusiones: la reserva de batería es fija y no depende de la previsión solar; el objetivo de inventario del tanque es fijo, cuando la previsión de un día nublado permitiría subirlo la víspera; y la regla de emergencia en nivel crítico hereda el test económico de la Versión A, con el defecto 7 incluido, de modo que en el escenario nublado la estación sigue comprando hidrógeno caro cuando el tanque está en crítico.

=== Diseño del análisis de contribución

La Versión C se evalúa como un único modelo con sus componentes activados por etapas, todas sobre el mismo horizonte y los mismos pares escenario-semilla:

#figure(
  table(
    columns: (auto, auto, auto, 1fr),
    align: (left, center, left, left),
    table.header([*Tanda*], [*Batería → electrolizador*], [*Programación*], [*Qué aísla*]),
    [`C0`], [sí], [no (regla de A)], [El techo sin previsión: cuánto vale que la batería alimente al electrolizador.],
    [`C_p`], [sí], [precio publicado + persistencia], [Cuánto vale programar con información trivial.],
    [`C`], [sí], [precio publicado + LSTM], [Cuánto añade la red neuronal de precio sobre la persistencia.],
  ),
  caption: [Análisis de contribución de la Versión C. Las tres tandas usan el mismo fichero `ems_C.m`; `C0` desactiva el planificador con un interruptor, y las dos últimas difieren únicamente en el modo de la S-Function de precio (`C_p`, planificador con persistencia en el tramo no publicado; `C`, con la LSTM). En las etiquetas de los ficheros de resultados son `E0`, `E_sinLSTM` y `E`. La previsión solar está presente en las tres y no se aísla.],
) <tbl-ablacion-E>

Cada tanda tiene un criterio de aceptación comprobable antes de mirar ningún coste: la descarga de batería debe ser mucho mayor que en A (la batería se descarga a propósito para el electrolizador) y el error de previsión de precio a una hora debe ser exactamente cero en las dos últimas, porque la primera hora del horizonte siempre está publicada. Las predicciones sobre el resultado de cada contraste se dejaron escritas antes de simular, y en el @cap-resultados se contrastan una a una.

== Métricas de comparación <sec-metricas>

Para comparar cuantitativamente las versiones se emplean las siguientes métricas, calculadas sobre el mismo horizonte de simulación:

- *Coste neto de la energía* (€): energía importada de la red valorada al precio horario, menos la exportada al mismo precio. Es la función objetivo del Caso 1 de @molero2025ems, sin peajes ni cargos, y como allí debe leerse como indicador comparativo y no de facturación.
- *Coste corregido por el valor terminal* (€): el anterior, descontando el valor de la energía que queda almacenada al final del horizonte respecto al inicio (batería y tanques), para no penalizar a la estrategia que termina con más reservas. La batería se valora al precio medio de exportación (unos 40 €/MWh) porque en una instalación que exporta 10,6 veces lo que importa el kilovatio-hora sobrante acaba exportándose, no desplazando una compra; el hidrógeno, a su precio de reposición, 8 €/kg.
- *Coste total con hidrógeno* (€): el coste corregido más el hidrógeno servido con el tanque vacío valorado a 8 €/kg, el coste de reposición con transporte y compresión, que es el coste de oportunidad de no tenerlo y el mismo precio con el que la regla decide si produce (@sec-ems-referencia). Solo el control de horizonte semanal de la variante predictiva conserva en la regla el índice mayorista de 6,12 €/kg; la campaña de sensibilidad (@sec-escenarios) muestra que esa constante cambia el coste semanal en menos de medio euro. Es la métrica principal del trabajo, y las tres se reportan siempre juntas.
- *Autoconsumo renovable* (%) y *autosuficiencia energética* (%): fracción de la generación PV consumida localmente, y fracción de lo consumido que se cubre con generación propia. Se reportan juntas porque una estrategia puede mejorar una y empeorar la otra.
- *Servicio de hidrógeno*: nivel medio y mínimo del tanque de alta, porcentaje de tiempo por debajo del nivel crítico e hidrógeno no servido (kg). Como se justifica en @cap-datos-ev, la franja útil del tanque es menor que un repostaje completo, por lo que el tiempo en nivel crítico mide sobre todo la velocidad de recuperación y la capacidad de anticiparse, no la ausencia de incidencias.
- *Número de conmutaciones* del electrolizador y de la pila, y *energía ciclada* por la batería (kWh cargados más descargados), como indicadores de desgaste. No se convierten a coste porque no se dispone de curvas de degradación de los equipos de OASIS; se usan para comprobar que la versión económicamente mejor no lo es a costa de un régimen sensiblemente más agresivo.

Contraste estadístico. Todas las comparaciones son pareadas por escenario y semilla (@cap-resultados), y la diferencia se reporta con su media, su mediana, el número de pares en que la versión gana y el $p$-valor del test de rangos con signo de Wilcoxon. Se abandonó el $t$-test pareado al comprobar que en varias tandas tres semillas del escenario nublado dominaban la media, con medias cinco y veinte veces mayores que la mediana, y el contraste sobre la media no describía por tanto a la población de semillas. Además, se fija un umbral de relevancia económica: la dispersión del coste semanal de la propia Versión A entre dos grupos de semillas, 9,33 € por semana. Una diferencia estadísticamente significativa por debajo de ese umbral se declara como tal, significativa y operativamente nula.

La decisión económica de la @sec-ems-referencia fuerza el electrolizador siempre que el precio esté por debajo del umbral económico —114 €/MWh con el índice mayorista, 149 con el coste de reposición— y el tanque de alta por debajo del 79 %, y si el tanque de baja está por encima de su reserva el umbral equivalente sube por encima de 2 000 €/MWh. De esa lectura del código se sigue un criterio de falsación, fijado antes de simular: el electrolizador tiene que aparecer forzado la mayor parte del tiempo, las métricas de hidrógeno tienen que resultar poco discriminantes y la previsión solar tiene que tener poco margen para modificar nada; si la campaña mostrase lo contrario, la interpretación de la regla heredada sería incorrecta. Los tres puntos se confirman, y llevar el tercero hasta el final es lo que obliga a medir a dónde iba la importación y conduce a los defectos 6 y 7.

== Escenarios de simulación <sec-escenarios>

Siguiendo el mismo criterio de horizonte adoptado en @molero2025ems, las simulaciones se plantean sobre días representativos en lugar de periodos mensuales o anuales, y se priorizan el ajuste y la comparación de la lógica del EMS frente a un análisis estadístico de largo plazo. Los escenarios no se eligen al azar sino para cruzar las dos variables que gobiernan la decisión del EMS (el recurso solar y el régimen de precio) y cubrir además los dos perfiles de demanda:

#figure(
  table(
    columns: (auto, auto, auto, 1fr),
    align: (left, left, left, left),
    table.header([*Escenario*], [*Fecha*], [*Perfil*], [*Qué somete a prueba*]),
    [E1 · laborable soleado], [02-07-2025], [laborable], [Excedente fotovoltaico máximo con precio plano (71--130 €/MWh): reparto entre batería y electrolizador sin señal económica que lo distorsione.],
    [E2 · laborable nublado], [11-02-2025], [laborable], [Estrés de recurso ($k_t = 0.36$) con punta de precio de 194 €/MWh a las 20 h: el caso en que la estación no tiene excedente y el hidrógeno hay que comprarlo caro o no servirlo.],
    [E3 · fin de semana soleado], [13-07-2025], [fin de semana], [Irradiancia máxima del año en fin de semana, con precio de 0--4 €/MWh a mediodía: excedente y energía casi gratis a la vez, y perfil de demanda distinto.],
    [E4 · volatilidad], [17-09-2025], [laborable], [Mayor diferencial de precio de 2025 (24 → 252 €/MWh): el escenario con más recorrido para decidir cuándo producir.],
  ),
  caption: [Escenarios de la campaña de simulación. Cada uno se ejecuta con varias semillas del generador de demanda y para cada versión del EMS, con las mismas semillas en todas ellas.],
) <tbl-escenarios>

#figure(
  image("../img/fig_met_escenarios.png", width: 100%),
  caption: [Los cuatro escenarios en su fecha: precio horario del mercado diario (arriba) e irradiancia horizontal real frente a la de cielo claro (abajo), con el índice de claridad $k_t$ del día. Las cuatro columnas comparten escala, de modo que la comparación entre ellas es directa.],
) <fig-met-escenarios>

Las semillas responden a que el perfil de demanda es estocástico: el número de vehículos, sus horas de llegada y la energía o el hidrógeno de cada sesión se muestrean de las distribuciones del @cap-datos-ev. Comparar dos versiones sobre una única realización confundiría la diferencia entre estrategias con el ruido de una tirada concreta; si se repiten las mismas semillas en todas las versiones, cada par de resultados es directamente comparable.

La campaña se organiza en dos horizontes. La comparación de la Versión A con la variante predictiva se hizo sobre 24 horas con diez semillas por escenario (40 pares), horizonte adecuado para la dinámica eléctrica. La Versión C se evalúa sobre una semana continua con cinco semillas por escenario (20 pares), y ese horizonte es el principal por dos razones: la cadena de hidrógeno tiene constantes de tiempo de horas y el tanque de alta arranca cada simulación en su condición inicial, y —más importante— sobre un día el uso de la batería se confunde con el transitorio del estado de carga inicial (del 70 % al 83 %), que en la semana se lava. Con cinco semillas el contraste semanal tiene menos potencia que el diario: en la campaña de 24 horas no resolvió diferencias de 1 a 3 €, y las que se esperan de C son de decenas de euros.

A esa matriz se añaden dos experimentos que no forman parte de la comparación pareada y que sirven para interpretarla. El primero es el oráculo: repetir una tanda entregando a las S-Functions el precio y la irradiancia reales de las 24 horas siguientes en lugar de una predicción. Su resultado es la cota superior de lo que el mecanismo puede extraer de la información; si con error nulo no mejora, ninguna mejora de la previsión puede hacer que mejore. El segundo es la sensibilidad al precio del hidrógeno. El análisis se ha ejecutado con la constante de la regla al coste de reposición con transporte, 8 €/kg (umbral de producción de 149 €/MWh), que es la campaña que se reporta, y se ha repetido completa con el índice mayorista sin corregir, 6,12 €/kg (umbral de 114 €/MWh). Entre una y otra cambia cuántas horas filtra la regla, cuánto electrolizador hay que alimentar y cuántas horas tiene el planificador para elegir, así que la comparación de ambas dice cuánto dependen las conclusiones de ese parámetro, que gobierna tres cuartas partes de la importación. Además, la energía terminal y el hidrógeno no servido se recalculan en posproceso a distintos precios de valoración para comprobar que el signo de las conclusiones no depende de ese supuesto. Los dos se plantean sobre el horizonte semanal, por la razón ya expuesta.

La ejecución de estas simulaciones y la comparación cuantitativa de resultados se presentan en el @cap-resultados.
