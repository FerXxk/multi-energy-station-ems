= La estación OASIS: arquitectura y dimensionamiento <cap-estacion>

El modelo utilizado es la microrred OASIS, implementada en Simulink dentro de `SimugridElectrolinera/` (`init_OASIS.m`, `OASIS.slx`). Esta microrred incluye generación fotovoltaica, un electrolizador PEM, un tanque pulmón de baja presión (`LOH`), un compresor, un tanque surtidor de alta presión (`LOH_High`), una pila de combustible, carga de vehículos eléctricos y demanda de hidrógeno, con las S-Functions `lstm_sol.m` y `lstm_precios.m` ya integradas en el bucle de simulación (@cap-lstm). La @fig-oasis-3d muestra la disposición física que se modela (marquesinas fotovoltaicas sobre los puntos de suministro y recinto técnico con los equipos electroquímicos y los tanques) y la @fig-arquitectura-oasis, los bloques del modelo y las señales que intercambian con el EMS.

La @tbl-planta reúne los parámetros de la instalación simulada, y los apartados siguientes justifican el dimensionamiento de cada subsistema; el número y la potencia de los cargadores se derivan del análisis de demanda del @cap-datos-ev.

#figure(
  table(
    columns: (1.1fr, 1.5fr, 1.6fr),
    align: (left, left, left),
    table.header([*Subsistema*], [*Parámetro*], [*Valor*]),
    [Generación fotovoltaica], [Configuración del array], [24 módulos en serie × 35 ramas en paralelo, ≈508 kWp (@sec-dim-pv)],
    [Batería (BESS)], [Capacidad / potencia], [1 MWh; ≈494 kW (0,5C), 380 V y 1 300 A; estado de carga inicial del 70 %],
    [Electrolizador PEM], [Potencia / consumo específico], [200 kW; ≈50 kWh/kg; entrega a 40 bar],
    [Compresor], [Potencia / consumo específico], [15 kW; 3,6 kWh/kg; etapa de baja a alta presión],
    [Pila de combustible (PEMFC)], [Potencia], [130 kW de diseño (`PmaxFC`); el bloque electroquímico está parametrizado con 120 celdas de 600 cm² y 600 A, y entrega menos],
    [Tanque de baja (`LOH`)], [Volumen / presión], [3,1 m³; 40 bar máximos, 26 bar iniciales; 10,1 kg lleno],
    [Tanque de alta (`LOH_High`)], [Volumen / presión], [0,41 m³; 600 bar máximos, 480 bar iniciales (80 % de nivel al arrancar); 20,0 kg lleno con la ecuación de gas ideal del bloque, 14,2 kg con gas real (@sec-dim-h2)],
    [Cargadores de vehículo eléctrico], [Número / potencia], [2 × 50 kW en corriente continua (@sec-num-cargadores)],
    [Surtidor de hidrógeno], [Número / caudal], [1 módulo a 1,2 kg/min; 700 bar es la presión nominal del depósito del vehículo (SAE J2601), no la del almacenamiento (@sec-dim-h2)],
    [Conexión a red], [Tipo / valoración], [Bidireccional, sin límite de potencia contratada en el modelo; energía valorada al precio horario del mercado diario, sin peajes ni cargos (@sec-metricas)],
  ),
  caption: [Configuración de la estación OASIS tal y como está parametrizada en `OASIS.slx`. Las cifras de hidrógeno almacenado siguen la ecuación de estado del propio bloque, que sobrestima la masa a alta presión; el efecto sobre la lectura de los resultados se discute en la @sec-dim-h2.],
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

== Dimensionamiento de los subsistemas

Los parámetros de la @tbl-planta se leen de la parametrización de `OASIS.slx` y de `init_OASIS.m`. Los apartados que siguen los justifican subsistema a subsistema, señalando en cada caso qué valores son de diseño de este trabajo y cuáles se heredan del modelo de partida.

=== Generador fotovoltaico <sec-dim-pv>

El bloque PV de `OASIS.slx` está parametrizado con un array de $N_s = 24$ módulos en serie y $N_p = 35$ ramas en paralelo, cada módulo caracterizado por una tensión en el punto de máxima potencia $V_"mp" = 34.6$ V, corriente de cortocircuito $I_"sc" = 18.57$ A, tensión de circuito abierto $V_"oc" = 41.7$ V, a una temperatura de referencia de 300 K (27 °C). Tomando una relación típica $I_"mp"/I_"sc" ≈ 0.94$ para módulos de silicio cristalino (dato no incluido en la parametrización del bloque), la potencia nominal por módulo es $P_"mod" ≈ V_"mp" · I_"mp" ≈ 34.6 · 17.5 ≈ 605$ W, y la potencia pico del array:

$
  P_"PV,pico" = N_s · N_p · P_"mod" ≈ 24 · 35 · 605 ≈ 508 "kWp"
$

Esta estimación es coherente con el pico de generación real observado en el propio modelo (≈500 kW el 15 de agosto de 2025), por lo que se toma ≈500 kWp como capacidad instalada de OASIS en el resto de este trabajo.

=== Electrolizador PEM <sec-dim-el>

El electrolizador PEM está parametrizado con una potencia nominal de 200 kW y un consumo específico de ≈50 kWh/kg, que queda dentro del rango de 47--55 kWh/kg de los equipos comerciales recogido en el @cap-estado-arte. A plena potencia produce, por tanto, del orden de 4 kg/h de hidrógeno. Ambos valores se heredan del modelo de partida y no son resultado de un dimensionamiento de este trabajo. En OASIS el electrolizador entrega a 40 bar, que es exactamente la presión máxima del tanque tampón (@sec-tanque-lp), de modo que la compresión solo interviene en la etapa siguiente.

=== Almacenamiento de hidrógeno <sec-dim-h2>

El tanque tampón de baja presión de OASIS (@sec-tanque-lp) tiene un volumen de 3,1 m³ y una presión máxima de 40 bar, con una presión inicial de simulación de 26 bar (parámetros leídos del bloque `Low Press Tank` del modelo).

El tanque de alta de OASIS tiene un volumen de 0,41 m³ y el bloque empleado en las simulaciones lo parametriza a 600 bar de presión máxima y 480 bar de presión inicial. Conviene precisar qué son los 700 bar que se asocian habitualmente a este tipo de instalación: son la presión nominal de servicio del depósito del *vehículo*, la que fija el estándar de repostaje SAE J2601 para turismos, y no la presión que basta con tener almacenada. Llenar un depósito hasta esa presión exige un diferencial a favor, y por eso las estaciones reales de 70 MPa almacenan en cascada por encima de 850 bar o interponen un compresor de refuerzo (_booster_) entre el almacenamiento y el surtidor; el tanque de alta del que este trabajo hereda los umbrales tiene, de hecho, un techo de seguridad de 900 bar @molero2025ems. Con los 600 bar del bloque, un repostaje completo no llegaría a la presión nominal del vehículo. El modelo no representa esa restricción: el surtidor se resuelve como un caudal másico que sale del tanque de alta, sin comprobación de la presión disponible. El efecto del reescalado de los umbrales sobre esos 600 bar se discute en @cap-metodologia.

Tomando como referencia los valores habituales de densidad para H₂ gaseoso a 15 °C (23,3 kg/m³ a 350 bar y ≈39,3 kg/m³ a 700 bar @sdanghi2019compression) y estimando por extrapolación lineal entre ambos puntos ≈29,2 kg/m³ a 480 bar y ≈34,7 kg/m³ a 600 bar, el tanque almacenaría del orden de 14,2 kg a los 600 bar de su presión máxima y 12,0 kg en su condición inicial de 480 bar. Nótese que se trata de una extrapolación fuera del intervalo definido por los dos puntos de referencia, y no de una interpolación: para un dimensionamiento definitivo procede tomar la densidad directamente de tablas NIST.

Una limitación del modelo condiciona la lectura de los resultados: los bloques de tanque de OASIS calculan la presión a partir de la cantidad de hidrógeno almacenado mediante la ecuación de los gases ideales, sin factor de compresibilidad. A 600 bar y 15 °C el hidrógeno real tiene una densidad de ≈34,7 kg/m³ frente a los ≈50,5 kg/m³ que predice el gas ideal, es decir, el modelo sobrestima en torno a un 45% la masa que cabe en el tanque lleno. La autonomía de hidrógeno que se observe en simulación es, por tanto, optimista respecto a la de una instalación real; corregirla exigiría sustituir la ecuación de estado del bloque por una de gas real (van der Waals, Noble-Abel o tabla NIST), lo que se propone como línea de trabajo futuro.

=== Pila de combustible <sec-dim-fc>

El pico eléctrico a cubrir en modo isla no es solo el de los cargadores EV (2 × 50 kW = 100 kW): hay que sumar el consumo propio del compresor (15 kW) si estuviera operando en ese instante, más un margen de seguridad que cubra la degradación del equipo y la incertidumbre de dimensionamiento. Por ello, la FC de OASIS se ha dimensionado a 130 kW (100 kW de pico EV + 15 kW de compresor + ≈10 % de margen, redondeado a un tamaño de módulo comercial), en vez de a los 100 kW que cubrirían el pico de EV con margen cero. Este valor es el criterio de diseño que emplean los tres EMS de este trabajo como `PmaxFC`. El bloque electroquímico del modelo, en cambio, está parametrizado con 120 celdas de 600 cm² y una corriente máxima de 600 A, lo que corresponde a una potencia de salida sensiblemente menor; escalar el bloque hasta los 130 kW de diseño queda pendiente sobre el modelo físico, y mientras no se haga la consigna `RefFC` puede quedar saturada por el propio bloque antes de alcanzar el valor que solicita el EMS.

=== Batería (BESS) <sec-dim-bess>

El bloque de batería de `OASIS.slx` sigue el modelo de circuito equivalente descrito en el manual de Simugrid, parametrizado con tensión de circuito abierto $V_"bt,0" = 380$ V, capacidad máxima de 1 MWh, constante de polarización $K = 0.000739$ V, amplitud de la zona exponencial $A = 20.314$ V, resistencia interna $R = 0.00027 med Omega$, corriente máxima de carga/descarga de 1 300 A y un estado de carga inicial del 70%. La capacidad en amperios-hora que el bloque utiliza internamente se deriva de los dos primeros parámetros, $C_120 = 1 "MWh" \/ 380 "V" ≈ 2632$ Ah. De la tensión y la corriente máxima se obtiene el límite de potencia del bloque:

$
  P_"max,BESS" = V_"bt,0" · I_"max" = 380 "V" · 1300 "A" ≈ 494 "kW"
$

Ese límite equivale a 0,5C sobre la capacidad de 1 MWh, un valor habitual en baterías estacionarias de ion-litio, y queda por encima tanto del mayor consumo simultáneo que la estación puede presentar (100 kW de cargadores, 200 kW de electrolizador y 15 kW de compresor) como de la mayor carga que recibe con excedente (en torno a 400 kW, el 80 % de un pico fotovoltaico de 500 kW). En la práctica, por tanto, la saturación de potencia de la batería no llega a activarse en las simulaciones de este trabajo, y el reparto de potencia entre batería y electrolizador descrito en @cap-metodologia queda gobernado por los umbrales de estado de carga. La capacidad de 1 MWh sí es dimensionalmente coherente con la instalación: equivale a unas dos horas de generación fotovoltaica a potencia pico, y a unos cuatro días de la demanda diaria de carga eléctrica estimada en @cap-datos-ev. Un dimensionamiento fino del BESS —que no se aborda aquí— debería partir del término de potencia contratada de la tarifa y del perfil de demanda de los cargadores @techno_economic_charging, y no del límite interno del bloque de simulación.

== El segundo modelo del grupo de investigación

El grupo de investigación dispone además de un segundo modelo, `AIHRE_Puerto_Negocio1v1.slx`, con una arquitectura de componentes muy similar a la del Caso 2 de Molero Almazán @molero2025ems (electrolizador PEM, compresor, doble tanque de H2, pila de combustible, batería y demanda de H2 externa). Ese modelo no se emplea en este trabajo, que se realiza íntegramente sobre OASIS, y se conserva fuera del árbol de trabajo del repositorio.
