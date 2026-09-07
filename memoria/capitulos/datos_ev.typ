= Datos de carga EV y dimensionamiento de la estación <cap-datos-ev>

El diseño de una estación de repostaje multi-energía requiere datos reales de uso para justificar tanto la potencia de los cargadores como su número. En este capítulo se describe el dataset de demanda de vehículos eléctricos (EV) del que se parte y se justifica el dimensionamiento de la estación propuesta.

== Dataset de referencia: DESL-EPFL

=== Descripción del dataset

Se ha utilizado el dataset *Level-3-EV-charging-dataset* publicado por el Laboratorio de Sistemas Eléctricos Distribuidos de la EPFL (DESL-EPFL) @desl_epfl_dataset. Sus características principales se resumen en la @tbl-dataset:

#figure(
  table(
    columns: (1fr, 1.5fr),
    align: (left, left),
    table.header([*Propiedad*], [*Valor*]),
    [Tipo de cargador], [Level 3 (DC fast), 172.5 kW máximo],
    [Enchufes], [5 (2×CCS, 1×CHAdeMO, 1×Type 2, 1×Tesla DC)],
    [Sesiones totales], [1 878 registradas / 1 875 válidas],
    [Período], [Abril 2022 — Julio 2023 (≈15 meses)],
    [Resolución temporal], [1 minuto (medidas), sesión (resumen)],
    [Ubicación], [Suiza (zona CET/CEST)],
    [Licencia], [MIT],
  ),
  caption: [Características principales del dataset DESL-EPFL],
) <tbl-dataset>

El dataset incluye dos archivos principales: *Session_data.xlsx* (1 878 sesiones con hora de llegada, salida, energía cargada, SOC de llegada y salida, y potencia máxima) y *Measurement_data.xlsx* (64 277 mediciones a 1 minuto de resolución con potencia, SOC y energía acumulada).

=== Distribución de llegadas

La @fig-llegadas muestra la distribución temporal de llegadas de los EV a lo largo del día. Se observa un patrón bimodal con picos sobre las 8:00 h (llegadas matutinas) y las 17:00-18:00 h (llegadas vespertinas), coherente con un uso de tipo público/urbano donde los usuarios cargan durante las horas de actividad diurna.

#figure(
  image("../img/datos_ev/llegadas_por_hora.png", width: 80%),
  caption: [Distribución de llegadas de EV por hora del día. Dataset DESL-EPFL.],
) <fig-llegadas>

=== Energía por sesión

La @fig-energia muestra la distribución de energía cargada por sesión. La media es de 32.2 kWh y la mediana de 29.4 kWh, con un rango típico de 10-50 kWh. Este valor es menor que la capacidad completa de las baterías modernas (50-80 kWh), lo que indica que los usuarios no cargan al 100% en cada visita, sino que realizan recargas parciales.

#figure(
  image("../img/datos_ev/energia_por_sesion.png", width: 80%),
  caption: [Distribución de energía cargada por sesión. Media: 32.2 kWh, mediana: 29.4 kWh.],
) <fig-energia>

=== Estado de carga (SOC)

La @fig-soc representa los valores de SOC de llegada y salida. Los EV llegan con un SOC medio del 34% (rango típico 15-50%) y se van con un SOC medio del 79% (rango típico 65-95%). Esto confirma que la energía media transferida por sesión es de aproximadamente 45 puntos porcentuales de SOC, consistente con la energía observada.

#figure(
  image("../img/datos_ev/soc_llegada_salida.png", width: 80%),
  caption: [Distribución del estado de carga (SOC) de llegada y salida.],
) <fig-soc>

== Comparación Level 2 vs Level 3

=== Definición de niveles

La clasificación en niveles (_Level 1/2/3_) procede de la práctica norteamericana asociada a la norma SAE J1772 y es la que se emplea habitualmente en la literatura de datasets de recarga, incluidos los utilizados en este capítulo. No debe confundirse con los cuatro *modos* de carga que define la norma IEC 61851 (@cap-estado-arte), que es una taxonomía distinta y no equivalente: los modos describen el esquema de protección y comunicación del punto de recarga, no su nivel de potencia. La @tbl-niveles resume las características de cada nivel en la clasificación por potencia.

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    table.header([*Nivel*], [*Tipo*], [*Potencia*], [*Tiempo de carga típico*]),
    [Level 1], [CA monofásica], [1.4 — 1.9 kW], [8 — 24 h],
    [Level 2], [CA trifásica], [6 — 22 kW], [2 — 8 h],
    [Level 3], [CC (DC fast)], [50 — 350 kW], [10 — 60 min],
  ),
  caption: [Clasificación de cargadores de EV por nivel de potencia (convención SAE J1772).],
) <tbl-niveles>

=== Comparación con datos reales

Para comparar ambos niveles con medidas, y no con valores de catálogo, se han utilizado dos datasets públicos:

- *Caltech ACN-Data* (Level 2): ≈54 cargadores CA de 6.6 kW en el campus de Caltech, USA. 2 449 sesiones válidas de 2020 @caltech_acndata.
- *DESL-EPFL* (Level 3): 2 cargadores CCS de 172.5 kW en Suiza. De las 1 878 sesiones CCS registradas se descartaron 3 por energía nula o marcas de tiempo inconsistentes, de modo que quedan 1 875 sesiones válidas de abril 2022 a julio 2023 @desl_epfl_dataset.

La @tbl-comparacion recoge las características de los dos niveles y la @tbl-comparativa-real, las métricas medidas sobre esos datasets.

#figure(
  table(
    columns: (1.2fr, 1fr, 1fr),
    align: (left, left, left),
    table.header([*Característica*], [*Level 2 (CA)*], [*Level 3 (CC)*]),
    [Tensión], [208/240 V AC], [200-1000 V DC],
    [Corriente máxima], [32-80 A], [100-500 A],
    [Potencia típica], [6-22 kW], [50-172.5 kW],
    [Conector], [Type 1 / Type 2], [CCS / CHAdeMO / NACS],
    [Uso típico], [Residencial / workplace], [Estación de servicio / corredor],
    [Coste instalación], [1 000-5 000 €], [25 000-100 000 €],
    [Impacto red], [Bajo], [Moderado-Alto],
  ),
  caption: [Comparación entre cargadores Level 2 y Level 3.],
) <tbl-comparacion>

#figure(
  table(
    columns: (2fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Métrica*], [*Level 2 (Caltech)*], [*Level 3 (DESL-EPFL)*]),
    [Potencia del cargador], [≈6.6 kW], [172.5 kW],
    [Sesiones analizadas], [2 449], [1 875],
    [Energía media por sesión], [8.2 kWh], [32.2 kWh],
    [Energía mediana por sesión], [5.5 kWh], [29.4 kWh],
    [Duración media], [306 min (5.1 h)], [33 min],
    [Duración mediana], [290 min (4.8 h)], [30 min],
    [Potencia media real], [2.5 kW], [62.4 kW],
    [Sesiones/día], [11.5], [8.5],
  ),
  caption: [Comparación de métricas reales entre Level 2 y Level 3, medidas sobre los datasets Caltech (Level 2) y DESL-EPFL (Level 3).],
) <tbl-comparativa-real>

El Level 3 es 9.3 veces más rápido que el Level 2 para una sesión típica y entrega 3.9 veces más energía por sesión (32.2 kWh frente a 8.2 kWh). La causa es el caso de uso: en Level 2 el usuario deja el coche conectado toda la jornada laboral (parking de trabajo), mientras que en Level 3 espera cerca del vehículo y busca una recarga rápida. Los patrones de llegada lo confirman: el Level 2, en un campus universitario, tiene un único pico matutino (8-10 h) correspondiente a la llegada al trabajo, mientras que el Level 3 presenta el patrón bimodal de la @fig-llegadas, con un máximo a las 8:00 y otro, más acusado, a las 17:00-18:00.

Ambos niveles difieren también en el perfil de potencia dentro de la sesión. En Level 2 la potencia es constante durante toda la sesión (curva rectangular); en Level 3 la batería sigue una curva CC-CV (_constant current — constant voltage_): carga a potencia constante hasta aproximadamente el 80 % de SOC y después la potencia decae exponencialmente hasta completar la carga @ev_battery_cccv. La @fig-comparativa-potencia muestra la distribución de potencia media por sesión, con una media del Level 3 (≈62 kW) casi diez veces superior a la del Level 2 (≈6 kW). La @fig-comparativa-energia-duracion muestra el efecto de la curva CC-CV: en Level 2 la relación entre energía y duración es lineal, mientras que en Level 3 aparece una dispersión mayor por el tramo CV y por la variabilidad de potencia que solicita cada modelo de EV.

#figure(
  image("../img/datos_ev/comparativa_potencia.png", width: 85%),
  caption: [Distribución de potencia media por sesión: Level 2 vs Level 3.],
) <fig-comparativa-potencia>

#figure(
  image("../img/datos_ev/comparativa_energia_duracion.png", width: 95%),
  caption: [Relación energía vs duración: Level 2 (izq) vs Level 3 (der).],
) <fig-comparativa-energia-duracion>

== Justificación de la potencia del cargador (50 kW)

=== Criterio de selección de 50 kW

La potencia del cargador DC de la estación multi-energía se ha fijado en 50 kW según los siguientes criterios:

1. *Posicionamiento estratégico.* El rango de potencias DC comerciales se extiende desde 50 kW (carga rápida de entrada) hasta 350 kW (ultra-rápida). Los 50 kW equilibran coste, tiempo de espera y eficiencia de la red:

  - Frente a 22 kW (Level 2 máximo): 50 kW reduce el tiempo de carga en un factor 2.3× y permite atender más usuarios por día.
  - Frente a 150+ kW (ultra-rápida): 50 kW evita la necesidad de transformadores de media tensión y reduce el coste de instalación en un factor 5-10×.

2. *Tiempo de carga competitivo.* Con la energía media observada en el dataset DESL-EPFL (32.2 kWh), un cargador de 50 kW completa la recarga en:

  $ t = E / P = 32.2 "kWh" / 50 "kW" = 0.644 "h" ≈ 39 "min" $

  Ese tiempo no es comparable al de un repostaje convencional, ni al de un FCEV, que la propia estación resuelve en menos de cinco minutos. Sí es coherente, en cambio, con el uso real observado: la duración mediana de sesión en el dataset DESL-EPFL es de 30 minutos, es decir, los usuarios ya aceptan de hecho paradas de ese orden en estaciones de carga rápida. Para una recarga parcial típica de 20 kWh (del 30% al 70% de SOC), el tiempo baja además a 24 minutos.

3. *Alineación con la demanda real.* La @fig-comparativa-potencia muestra que la potencia media real en el dataset DESL-EPFL es de 62.4 kW, pero con una distribución amplia donde muchas sesiones operan por debajo de 50 kW (debido a la limitación de potencia del propio EV o a la fase CV de la curva de carga). La potencia mediana por sesión queda por debajo de los 50 kW, de modo que un cargador de esa potencia no limita a la mayoría de las sesiones observadas; las que sí exceden esa potencia se ven alargadas proporcionalmente, no impedidas.

4. *Impacto en la red eléctrica.* Un cargador de 50 kW demanda una corriente de aproximadamente 72 A a 400 V trifásica:

  $ I = P / (sqrt(3) × V) = 50000 / (sqrt(3) × 400) ≈ 72 "A" $

  Esta corriente es gestionable con un transformador de distribución de baja tensión estándar (250 kVA), sin necesidad de infraestructura de media tensión. Cargas de 150+ kW requerirían transformadores dedicados y acometidas de media tensión, lo que incrementa el coste de instalación.

5. *Ratio de rotación.* Con una duración media de 39 min y 2 cargadores, la capacidad teórica máxima de la estación es:

  $ "Capacidad" = 2 "cargadores" × 60 "min/h" / 39 "min/sesión" ≈ 3.1 "sesiones/h" $

  En un horario de operación de 14 h (8:00-22:00), esto da una capacidad teórica de ≈43 sesiones/día. Sin embargo, la demanda real observada en el dataset es de 8-9 sesiones/día, lo que implica una utilización del ≈20%. Este margen permite absorber picos de demanda sin tiempos de espera excesivos.

6. *Escalabilidad y futuro.* 50 kW es una potencia que permite cargos de 10% a 80% SOC en la mayoría de EVs modernos (baterías de 40-80 kWh) en un tiempo razonable. A medida que la flota de EVs evolucione hacia baterías de mayor capacidad, los cargadores de 50 kW seguirán cubriendo recargas parciales como la de 20 kWh en 24 minutos calculada más arriba.

=== Comparación con alternativas

La @tbl-alternativas compara las opciones de potencia consideradas.

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, left, right, right, right),
    table.header([*Potencia*], [*Tipo*], [*Tiempo (32.2 kWh)*], [*Capacidad teórica/día*], [*Coste aprox.*]),
    [22 kW], [Level 2], [≈1 h 28 min], [≈19], [2 000-5 000 €],
    [*50 kW*], [*DC fast*], [*≈39 min*], [≈43], [*25 000-40 000 €*],
    [150 kW], [DC fast], [≈13 min], [≈130], [80 000-120 000 €],
    [350 kW], [Ultra-rápida], [≈5.5 min], [≈304], [150 000-250 000 €],
  ),
  caption: [Comparación de opciones de potencia para el cargador DC. Tiempo calculado con $t=E/P$ y la energía media del dataset (32.2 kWh) para las cuatro potencias, de forma consistente con el cálculo de la sección anterior. Capacidad teórica máxima con 2 cargadores operando 14 h (8:00-22:00) sin tiempos muertos entre sesiones — un límite superior, no la demanda esperada.],
) <tbl-alternativas>

Los 50 kW son la opción preferible para una estación de tamaño pequeño/medio: ofrecen un tiempo de carga competitivo (39 min) con un coste de instalación razonable (25 000-40 000 €), sin requerir infraestructura de media tensión. Alternativas de mayor potencia (150-350 kW) solo se justifican en estaciones de alto tráfico (corredores de alta velocidad, gasolineras de alto volumen) donde el ratio de rotación es crítico; la capacidad teórica de ≈43 sesiones/día a 50 kW queda muy por encima de la demanda real observada (8-9/día, @tbl-dimensionamiento) y no llega a ser una limitación.

=== Validación con el dataset

La @fig-duracion-sesion muestra que la mayoría de las sesiones en el dataset DESL-EPFL duran entre 20 y 45 minutos, lo que es consistente con el tiempo de carga a 50 kW calculado anteriormente. Las sesiones muy cortas (< 15 min) corresponden a recargas parciales de EVs que ya tenían un SOC alto, y las sesiones muy largas (>60 min) representan vehículos que permanecieron conectados más tiempo del necesario.

#figure(
  image("../img/datos_ev/duracion_sesion.png", width: 80%),
  caption: [Distribución de duración de sesiones en DESL-EPFL. Media: 33 min, mediana: 30 min.],
) <fig-duracion-sesion>

== Dimensionamiento de la estación

=== Número de cargadores EV <sec-num-cargadores>

Un primer acercamiento consistiría en fijar el número de cargadores igual al del dataset de referencia (DESL-EPFL cuenta con 2 puntos CCS). Sin embargo, ese razonamiento es circular: el dataset tiene 2 cargadores porque así se instalaron en Suiza, no porque 2 sea el número que la demanda de este trabajo requiere. El número de cargadores se dimensiona aquí mediante un análisis de teoría de colas (modelo M/M/c) sobre la tasa de llegadas real observada en el dataset.

*Tasa de llegadas en hora punta.* La distribución horaria de llegadas del dataset (@fig-llegadas) tiene su máximo a las 18:00, con una probabilidad de 8.32 % de las llegadas diarias. Con una media global de 8.48 sesiones/día, esto da una tasa de llegadas en la hora más cargada de:

$ lambda_"pico" = 8.48 × 0.0832 ≈ 0.71 "EV/h" $

*Tiempo de servicio.* Con la energía media del dataset (32.2 kWh) y un cargador de 50 kW, el tiempo medio de sesión es $t = 32.2/50 ≈ 38.7$ min, es decir $mu ≈ 1.55$ servicios/hora por cargador.

*Comparación M/M/c.* La @tbl-colas compara el tiempo de espera medio en cola (fórmula de Erlang C) para distintos números de cargadores en la hora punta.

#figure(
  table(
    columns: (1fr, 1fr, 1fr),
    align: (center, center, center),
    table.header([*Cargadores (c)*], [*Ocupación (ρ)*], [*Espera media en cola*]),
    [1], [45.5 %], [≈ 32.3 min],
    [*2*], [*22.8 %*], [*≈ 2.1 min*],
    [3], [15.2 %], [≈ 0.2 min],
  ),
  caption: [Espera media en cola en la hora punta (18:00) según el número de cargadores, modelo M/M/c con λ = 0.71 EV/h y μ = 1.55 servicios/h.],
) <tbl-colas>

#figure(
  image("../img/colas_espera_cargadores.png", width: 75%),
  caption: [Espera media en cola $W_q$ (Erlang C) frente al número de cargadores, para λ = 0.71 EV/h y μ = 1.55 servicios/h. El salto entre $c=1$ y $c=2$ (de ≈33 min a ≈2 min) sustenta la elección de 2 cargadores; a partir de $c=3$ la mejora es marginal.],
) <fig-colas>

Con un solo cargador, un usuario que llega en hora punta espera de media más de media hora: un tiempo inaceptable para una parada de repostaje en carretera, donde la propuesta de valor frente a un FCEV o una gasolinera es precisamente la rapidez. Pasar a 2 cargadores reduce la espera media a poco más de 2 minutos, una mejora de un orden de magnitud. Un tercer cargador solo aportaría 2 minutos adicionales de mejora, a cambio de duplicar la inversión en electrónica de potencia y ocupar más espacio en la parcela. Se adoptan por tanto 2 cargadores, el punto donde la mejora marginal en calidad de servicio deja de justificar el coste adicional.

@tbl-dimensionamiento resume el resultado junto con los datos de partida.

#figure(
  table(
    columns: (2fr, 1fr),
    align: (left, right),
    table.header([*Parámetro*], [*Valor*]),
    [Sesiones/día (laborable, DESL-EPFL)], [8.3],
    [Sesiones/día (fin de semana, DESL-EPFL)], [9.1],
    [Llegadas en hora punta (18:00)], [≈0.71 EV/h],
    [Potencia del cargador], [50 kW],
    [Duración media por sesión a 50 kW], [≈39 min],
    [Espera media en cola, c=1], [≈32.3 min],
    [Espera media en cola, c=2], [≈2.1 min],
    [Número de cargadores EV dimensionados], [2],
    [Capacidad diaria estimada (lab)], [≈8 sesiones],
    [Capacidad diaria estimada (finde)], [≈9 sesiones],
  ),
  caption: [Dimensionamiento de cargadores EV, basado en el análisis de colas de la @tbl-colas.],
) <tbl-dimensionamiento>

El sistema de colas FIFO implementado en la generación de perfiles de demanda (@cap-datos-ev) es coherente con este análisis: modela explícitamente la espera cuando ambos cargadores están ocupados, en vez de asumir disponibilidad instantánea.

La demanda de 8-9 sesiones/día es representativa de una estación de servicio de carretera de tamaño pequeño/medio en Europa. El dataset DESL-EPFL, aunque capturado en Suiza, refleja un uso público/urbano con penetración de EV alta, lo que produce una demanda conservadora (no excesiva) para un emplazamiento de autopista en España donde la penetración de EV es actualmente menor. El análisis de colas anterior usa esta tasa de llegadas como referencia de partida: las 8-9 sesiones/día observadas suponen una utilización del ≈20% de la capacidad teórica, y conviene repetir el análisis con una tasa de llegadas actualizada si la flota de EVs crece de forma significativa.

=== Número de surtidores de hidrógeno

El surtidor de hidrógeno se ha dimensionado con 1 módulo de repostaje a 1.2 kg/min (72 kg/h). Considerando que un Toyota Mirai alberga aproximadamente 5.6 kg de H₂ a 700 bar, un repostaje completo dura unos 4.7 minutos. En condiciones ideales de operación continua (sin tiempos de maniobra ni conexión), la estación podría atender hasta 10-12 vehículos/hora. Esa capacidad de dispensación es sobradamente suficiente para la flota FCEV actual; el surtidor no es el cuello de botella de la estación: lo son, como se muestra a continuación, la producción y el almacenamiento.

Esta capacidad de dispensación no debe confundirse con la capacidad de producción. El electrolizador de OASIS (200 kW, ≈50 kWh/kg, @cap-estacion) produce como máximo:

$ dot(m)_"H2,max" = 200 "kW" / 50 "kWh/kg" = 4 "kg/h" $

es decir, 18 veces menos que el caudal de dispensación (72 kg/h). Un único repostaje completo (5.6 kg) que se dispensa en menos de 5 minutos necesita después 1 h 24 min de electrolizador funcionando a máxima potencia para reponerse:

$ t_"reposición" = 5.6 "kg" / 4 "kg/h" ≈ 1.4 "h" $

Esta asimetría no es necesariamente un problema si la demanda de FCEV es tan esporádica como se asume, pero afirmarlo requiere un balance explícito de producción, consumo y almacenamiento, y no solo la observación de que la flota es pequeña. Ese balance se plantea a continuación con los parámetros de OASIS.

*Término de producción.* Con los parámetros del generador de perfiles de este capítulo (entre 4 y 8 FCEV al día y entre 3 y 5 kg por repostaje), la demanda diaria de hidrógeno se sitúa entre 12 y 40 kg/día. A un caudal máximo de 4 kg/h, el electrolizador necesita entre 3 y 10 horas a plena potencia (200 kW) solo para reponer el consumo del día, lo que equivale a un consumo eléctrico de 600 a 2000 kWh diarios dedicados en exclusiva a hidrógeno. Sobre un generador fotovoltaico de ≈500 kWp en Sevilla (@cap-estacion), cuya producción diaria es del orden de 2-3 MWh, el extremo alto de ese rango absorbe la mayor parte del recurso solar disponible y compite directamente con la carga de los vehículos eléctricos y con la recarga de la batería. Además, la ventana útil de excedente fotovoltaico, del orden de 5 a 7 horas en torno al mediodía, es más corta que las 10 h que exigiría el escenario de 40 kg/día, por lo que en ese caso parte de la producción tendría que hacerse forzosamente con energía de red, y la decisión económica "producir localmente o no cubrir el déficit" descrita en Metodología pasa a ser determinante.

*Término de almacenamiento.* La instalación almacena hidrógeno en dos etapas (@cap-estacion): un tanque tampón de baja presión de 3,1 m³ hasta 40 bar, que contiene del orden de 10 kg cuando está lleno, y el tanque de alta de 0,41 m³, que con las densidades de gas real recogidas en @cap-estacion almacenaría unos 14,2 kg a los 600 bar con los que está parametrizado el modelo. El primer dato relevante es que el grueso de la reserva está en el tanque de baja, no en el de alta: el de alta es un depósito de dispensación, no un almacén.

El segundo es que la franja realmente utilizable del tanque de alta es estrecha. Los umbrales del EMS lo mantienen entre su nivel crítico (72 %) y su techo de seguridad (97 %), y esos porcentajes son fracciones de presión (@cap-metodologia): sobre 600 bar equivalen a operar entre 432 y 582 bar, es decir, entre unos 11,0 y 14,0 kg de gas real. Quedan por tanto del orden de 3 kg de hidrógeno disponibles antes de tocar el nivel crítico, menos que un único repostaje completo de un Toyota Mirai (5,6 kg). Basta con que un solo vehículo llegue con el depósito vacío para llevar `LOH_High` por debajo del umbral crítico. El tanque de alta no actúa, en consecuencia, como colchón entre repostajes consecutivos: la continuidad del servicio depende en tiempo real de la cadena tanque de baja → compresor → electrolizador, y el tiempo de reposición relevante no es el de llenar un tanque vacío sino el de recuperar la franja de operación tras cada evento.

Debe tenerse presente al leer los resultados que los bloques de tanque del modelo emplean la ecuación de los gases ideales (@cap-estacion), que a estas presiones sobrestima la masa almacenada en torno a un 50 %. Las cifras de este balance, calculadas con densidades de gas real, son por tanto más exigentes que las que producirá la simulación: si el nivel del tanque de alta ya resulta ajustado en simulación, en una instalación real lo sería más.

De este balance se derivan dos consecuencias que condicionan la lectura del capítulo de Resultados. La primera es que es esperable que `LOH_High` cruce el nivel crítico tras cada evento de demanda de H2 significativo: el indicador de porcentaje de tiempo en nivel crítico definido en Metodología medirá sobre todo la velocidad de recuperación del sistema y la capacidad del EMS para anticiparse, no la ausencia de incidencias. La segunda es que el dimensionamiento actual (200 kW de electrolizador, 3,1 m³ de tanque tampón y 0,41 m³ de tanque de alta, con una reserva conjunta del orden de 24 kg frente a una demanda diaria de 12 a 40 kg) queda acotado al escenario de baja demanda que aquí se simula: en el extremo alto del rango, la estación dispone de menos de un día de autonomía. Extrapolar a una flota FCEV más densa exige un estudio de sensibilidad conjunto sobre los volúmenes de ambos tanques y la potencia del electrolizador, que queda como línea de trabajo futura.

== Generación de perfiles de demanda

=== Metodología

A partir del dataset DESL-EPFL se extrajeron las distribuciones mostradas en las @fig-llegadas, @fig-energia y @fig-soc. Estas distribuciones se utilizaron como entradas del generador de perfiles de demanda (`Demanda_Coches_Aleatoria.m`), que implementa:

1. *Muestreo de llegadas.* La hora de llegada de cada EV se muestrea de la distribución empírica del dataset, en vez de una distribución uniforme.

2. *Muestreo de energía.* La energía necesaria por cada EV se muestrea de la distribución real (media: 32.2 kWh), no de un rango arbitrario.

3. *Cálculo de duración.* La duración de cada sesión se calcula dividiendo la energía muestreada entre la potencia del cargador (50 kW), y la potencia instantánea sigue la curva CC-CV.

4. *Sistema de colas FIFO.* Cada cargador se modela como un servidor en un sistema de colas. Si todos los cargadores están ocupados, el EV espera hasta que se libere uno. Esto produce perfiles de demanda temporalmente coherentes.

=== Escalado

El análisis de colas de la @sec-num-cargadores concluye de forma independiente que la estación necesita 2 cargadores, y ese número coincide con el de la instalación de la que procede el dataset. Por tanto, el factor de escala es 1 y no es necesario ajustar el número de sesiones diarias. En caso de evaluar un dimensionamiento diferente (por ejemplo, 4 cargadores), el generador permite configurar `N_postes_EV` y aplica un factor de escala lineal sobre el número de sesiones; las distribuciones horarias y de energía se mantienen invariables.

=== Resultados

La @fig-sesiones muestra la distribución de sesiones por día de la semana en el dataset. Se observa que los fines de semana tienen una demanda ligeramente superior (9.1 sesiones/día) respecto a los laborables (8.3 sesiones/día), lo que es coherente con un uso de tipo público/ocio, en el que el usuario dispone de más margen horario.

#figure(
  image("../img/datos_ev/sesiones_por_dia.png", width: 80%),
  caption: [Sesiones por día de la semana. Laborables en azul, fines de semana en rojo.],
) <fig-sesiones>

La @fig-potencia-simulada muestra un ejemplo de perfil de potencia demandada por los cargadores EV a lo largo de 24 horas en un día laborable. Se aprecian los pulsos individuales de carga con la forma característica de la curva CC-CV: fase de potencia constante (50 kW) seguida de un decaimiento exponencial. Cuando ambos cargadores están activos simultáneamente, la potencia total alcanza 100 kW.

#figure(
  image("../img/datos_ev/potencia_ev_ejemplo.png", width: 90%),
  caption: [Perfil de potencia demandada por los cargadores EV (modo laborable). Cada pulso corresponde a una sesión de carga con curva CC-CV.],
) <fig-potencia-simulada>

=== Descripción del proceso de generación

El generador de perfiles de demanda (`Demanda_Coches_Aleatoria.m`) produce dos archivos `.mat` conteniendo timeseries de 24 horas con resolución de 1 segundo: uno para cargadores EV y otro para el surtidor de hidrógeno. Cada archivo contiene perfiles para modo laborable y fin de semana. A continuación se describe el proceso completo.

*1. Muestreo de parámetros por sesión.*

Para cada EV que llega a la estación, se muestrean los siguientes parámetros de las distribuciones empíricas del dataset DESL-EPFL:

- *Hora de llegada*: se extrae de la distribución de llegadas por hora (ponderada por probabilidad), con un minuto aleatorio dentro de esa hora. Esto reproduce el patrón bimodal real de llegadas, con picos a primera hora de la mañana y a última hora de la tarde (@fig-llegadas).

- *Energía necesaria*: se muestrea de la lista de energías reales del dataset (media: 32.2 kWh, mediana: 29.4 kWh). No se asume una distribución paramétrica.

- *SOC de llegada*: se muestrea de la distribución de SOC reales (media: 33.7%), limitado al rango 5-90% para evitar valores extremos.

- *Capacidad de batería*: se asigna aleatoriamente entre 50 y 80 kWh, un rango que representa la variedad de vehículos del mercado actual.

- *SOC de salida*: se calcula como $"SOC"_"ini" + (E / C_"bat") × 100$, limitado al 95%.

*2. Sistema de colas FIFO.*

Una vez muestreados los parámetros de todos los EVs del día, se aplica un sistema de colas FIFO con $N$ servidores en paralelo (por defecto $N = 2$):

- Los EVs se ordenan por hora de llegada.
- Cada EV se asigna al cargador que se libere antes.
- Si todos los cargadores están ocupados, el EV espera en cola.
- El tiempo de inicio real es $max(t_"llegada", t_"libre")$.
- La salida se produce al completar la carga.

Este sistema produce perfiles de demanda temporalmente coherentes: en horas pico puede haber 2 EVs simultáneos (con 2 cargadores), y en horas valle puede haber 0. El análisis de esperas permite evaluar la calidad de servicio.

*3. Curva de carga CC-CV.*

La potencia instantánea de cada cargador se modela con una curva CC-CV (Corriente Constante - Voltaje Constante), que es el perfil real de carga de las baterías de litio:

- *Fase CC*: potencia constante de 50 kW hasta que la batería alcanza el 80% de SOC. Esta fase representa la mayor parte de la energía entregada.

- *Fase CV*: decaimiento exponencial de la potencia con constante de tiempo $τ = (t_"total" - t_"CC") / 3$. La potencia sigue la ley $P(t) = P_"max" × e^(-(t - t_"CC") / τ)$.

La duración total de la sesión se resuelve por bisección para que la integral de la curva CC-CV iguale la energía necesaria muestreada.

*4. Generación de demanda H₂.*

El perfil de hidrógeno se genera con el mismo procedimiento que EV pero con simplificaciones debidas a la ausencia de datasets públicos de sesiones de repostaje FCEV:

- *Número de FCEV*: entre 4 y 8 (configurable), determinado aleatoriamente.
- *Hora de llegada*: se muestrea de la misma distribución bimodal que los EV (DESL-EPFL), ya que los FCEV siguen patrones de desplazamiento similares. Si no hay datos disponibles, se usa una distribución uniforme entre 7:00 y 21:00 como fallback.
- *Cantidad de H₂*: entre 3 y 5 kg por repostaje (estimado para un Toyota Mirai con tanque de 5.6 kg).
- *Duración*: calculada como $"kg" / "caudal"$ con caudal de 1.2 kg/min (0.02 kg/s).
- *Cola FIFO*: igual que para EV, con 1 surtidor.

El vector resultante almacena el caudal instantáneo en kg/s (0.02 kg/s por vehículo activo). La limitación principal es la ausencia de un dataset de referencia para llegadas FCEV; la distribución bimodal heredada de los EV es una aproximación razonable pero debe validarse con datos de ElaadNL u otras fuentes cuando estén disponibles.

== Limitaciones del dataset

El dataset DESL-EPFL presenta dos limitaciones que deben tenerse en cuenta al interpretar los resultados:

En primer lugar, corresponde a una única estación en Suiza, con patrones de movilidad y penetración de EV propios de Europa central que pueden diferir del contexto español. Los horarios de actividad en España son generalmente más tardíos (comidas sobre las 14:00-15:00 h, cierre de jornada sobre las 19:00-20:00 h) frente a los patrones más concentrados en la mañana y primera tarde que muestra el dataset. Esto no invalida el trabajo, pero los resultados deben interpretarse como una aproximación al comportamiento esperable en el emplazamiento real.

En segundo lugar, el perfil de hidrógeno se genera sin datos reales de sesiones de repostaje FCEV, al no existir datasets públicos disponibles para este tipo de vehículo. Las llegadas se modelan con la misma distribución bimodal que los EV como aproximación razonable, dado que ambos tipos de vehículo siguen patrones de desplazamiento similares. Esta aproximación debe validarse con datos de ElaadNL u otras fuentes cuando estén disponibles.

== Referencias de datos

El dataset DESL-EPFL está disponible en https://github.com/DESL-EPFL/Level-3-EV-charging-dataset bajo licencia MIT. Las distribuciones extraídas se encuentran en `codigo/data/desl_epfl/` y son utilizadas por el script `Demanda_Coches_Aleatoria.m` para generar perfiles de demanda realistas en cada ejecución de la simulación.
