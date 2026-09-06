= Estado del arte <cap-estado-arte>

Este capítulo revisa el contexto tecnológico y científico en el que se enmarca el presente trabajo. Se analiza el estado actual de las estaciones de repostaje multi-energía, los componentes que las integran (generación fotovoltaica, electrólisis PEM, almacenamiento de hidrógeno, pilas de combustible, almacenamiento en baterías y carga de vehículos eléctricos), las estrategias de gestión energética aplicadas a microrredes, y el uso de redes neuronales recurrentes de tipo LSTM para la predicción de irradiancia solar y precio de la electricidad.

== Contexto: transición energética y movilidad limpia

La descarbonización del sector transporte es un objetivo central de la transición energética. En Europa, el transporte representa aproximadamente una cuarta parte (≈25%) de las emisiones totales de gases de efecto invernadero. El transporte por carretera concentra en torno al 72% de dicha fracción @eea2023transport. Para alcanzar la neutralidad climática en 2050 fijada por el Pacto Verde Europeo @europeangreendeal, es necesario electrificar la movilidad y desarrollar las infraestructuras de recarga y repostaje que la soporten.

Dos tecnologías vehiculares limpias coexisten en este escenario: los vehículos eléctricos de batería (BEV, _Battery Electric Vehicles_) y los vehículos de pila de combustible de hidrógeno (FCEV, _Fuel Cell Electric Vehicles_). Ambos complementan sus fortalezas en segmentos de mercado distintos: los BEV son más eficientes y económicos en trayectos urbanos cortos y medios; los FCEV ofrecen mayor autonomía y repostaje más rápido en trayectos de larga distancia y para vehículos pesados @iea2023hydrogen.

En España, la Hoja de Ruta del Hidrógeno @miteco2020h2 fija para 2030 el objetivo de instalar entre 100 y 150 hidrogeneras de acceso público y de alcanzar 4 GW de potencia instalada de electrólisis, con un hito intermedio de 300--600 MW en 2024. En el vector eléctrico, el Plan Nacional Integrado de Energía y Clima (PNIEC 2023--2030) fija 5,5 millones de vehículos eléctricos en circulación en 2030 @pniec2024, y el reglamento europeo AFIR @afir2023 establece los objetivos vinculantes de despliegue de infraestructura de recarga que España debe cumplir. Este contexto crea una demanda creciente de instalaciones que combinen ambos vectores energéticos bajo un mismo techo.

== Estaciones de repostaje multi-energía

=== Concepto y ventajas

Una estación de repostaje multi-energía (MERS, _Multi-Energy Refueling Station_) es una instalación que combina, bajo un único sistema de gestión, dos o más vectores energéticos para la movilidad. En su configuración más avanzada integra: generación fotovoltaica, almacenamiento en baterías, electrólisis para producción local de hidrógeno, almacenamiento de hidrógeno a baja y alta presión, pila de combustible y cargadores de vehículos eléctricos @tahir2024hybridstation.

Las ventajas de integrar ambos vectores en una misma instalación son múltiples:

- *Aprovechamiento compartido de la generación renovable*: la instalación fotovoltaica puede destinar el excedente solar tanto a cargar baterías como a producir hidrógeno, con lo que aprovecha al máximo la energía local.
- *Reducción del coste de la infraestructura de conexión a la red*: al compartir el punto de conexión entre cargadores EV y electrolizador, se reduce la demanda pico sobre la red y el coste del transformador.
- *Flexibilidad ante la volatilidad del precio spot*: la pila de combustible puede actuar como respaldo generando electricidad en horas de precio alto, mientras que el electrolizador consume en horas de precio bajo.
- *Servicio integral al usuario*: un único emplazamiento puede atender tanto a conductores de BEV como de FCEV, y reduce el tiempo de desplazamiento hacia infraestructura especializada.

=== Proyectos de referencia

A nivel europeo, el proyecto H2ME (_Hydrogen Mobility Europe_), financiado por la _Fuel Cells and Hydrogen Joint Undertaking_ bajo los acuerdos 671438 y 700350, es la mayor demostración europea de vehículos ligeros e infraestructura de hidrógeno: se planteó desplegar 1 500 vehículos y 49 estaciones de repostaje en Alemania, Francia, Dinamarca, Suecia y Reino Unido entre 2015 y 2022 @speers2018h2me. Los resultados intermedios publicados del proyecto son especialmente relevantes para este trabajo porque documentan operación real y no simulada: 102 vehículos de pila de combustible acumulaban 625 300 km recorridos y 7 900 kg de hidrógeno dispensados sin ningún incidente de seguridad, con tiempos de repostaje de 2 a 3 minutos, y la estación de 700 bar de Kolding (Dinamarca) alcanzó una disponibilidad del 98,2% despachando 900 kg en su primer año @speers2018h2me. La hoja de ruta europea del hidrógeno sitúa el transporte por carretera como uno de los segmentos de despliegue prioritario de esta infraestructura @fchju2019roadmap.

A nivel nacional, Repsol inauguró en enero de 2025 la estación H2GO Repsol Morro Jable (Fuerteventura), la primera estación multi-energía y autosuficiente de Canarias: combina diésel renovable, un punto de recarga eléctrica de 50 kW, hidrógeno verde y combustibles tradicionales, con generación fotovoltaica (75 kW), baterías de litio (250 kW) y una pila de hidrógeno de 88 kW que garantizan la autosuficiencia energética de la propia instalación @repsolh2go2025. El conjunto es una combinación de componentes muy similar a la de OASIS, aunque a menor escala y sin electrolizador propio (el H2 se suministra ya producido, no se genera in situ). La Hoja de Ruta del Hidrógeno del Gobierno de España contempla además una red de en torno a un centenar de hidrogeneras en el país para 2030 @miteco2020h2.

En el ámbito académico, @roslan2024technoeconomic evalúan en HOMER Pro una estación de recarga de vehículo eléctrico alimentada por fotovoltaica y eólica con baterías de ion-litio, tanque de hidrógeno, electrolizador y pila de combustible, en tres emplazamientos de Malasia, y obtienen un coste neto actualizado (NPC) de entre 1,4 y 3,4 millones de dólares y un coste de la energía (COE) de entre 0,03 y 0,16 \$/kWh según la ubicación. En el plano del control, @zhu2024pvh2dempc modelan una microrred de corriente continua PV--hidrógeno a nivel de convertidor, con controladores locales para el campo fotovoltaico, el electrolizador y la pila de combustible coordinados mediante control predictivo económico distribuido, y muestran que este alcanza un comportamiento económico comparable al del control centralizado equivalente con una carga computacional y una oscilación de potencia sensiblemente menores.

== Generación fotovoltaica

La energía solar fotovoltaica es la fuente de generación renovable más adecuada para alimentar una estación de repostaje de carretera por varias razones: su modularidad (se puede dimensionar a la escala exacta de la carga), su bajo mantenimiento y, en el caso de España, el elevado recurso solar disponible @solargis2023.

La potencia generada por un sistema FV depende de la irradiancia incidente sobre el panel ($G$ en W/m²), la temperatura de la célula ($T_c$), la eficiencia del módulo ($η$) y el área activa ($A$):

$
  P_"PV" = η · A · G · (1 - β_T (T_c - T_"ref"))
$

donde $β_T ≈ 0.004$ °C⁻¹ es el coeficiente de temperatura de potencia y $T_"ref" = 25$ °C. La irradiancia en el plano del generador (POA) se obtiene a partir de la irradiancia horizontal global (GHI, registrada por NASA POWER en este trabajo) aplicando modelos de transposición como el de Perez @perez1990modeltransposition.

La predicción de irradiancia permite al EMS anticipar la operación del electrolizador: si se predice alta irradiancia para las próximas horas, el EMS puede planificar la producción de hidrógeno con anticipación y evitar curtailment solar.

=== Dimensionamiento real del generador PV de OASIS

Los apartados que siguen van fijando, junto a cada tecnología, los parámetros con los que está construida la estación OASIS de este trabajo; la @tbl-planta los reúne todos y la @fig-oasis-3d muestra su disposición física. El bloque PV de `OASIS.slx` está parametrizado con un array de $N_s = 24$ módulos en serie y $N_p = 35$ ramas en paralelo, cada módulo caracterizado por una tensión en el punto de máxima potencia $V_"mp" = 34.6$ V, corriente de cortocircuito $I_"sc" = 18.57$ A, tensión de circuito abierto $V_"oc" = 41.7$ V, a una temperatura de referencia de 300 K (27 °C). Tomando una relación típica $I_"mp"/I_"sc" ≈ 0.94$ para módulos de silicio cristalino (dato no incluido en la parametrización del bloque), la potencia nominal por módulo es $P_"mod" ≈ V_"mp" · I_"mp" ≈ 34.6 · 17.5 ≈ 605$ W, y la potencia pico del array:

$
  P_"PV,pico" = N_s · N_p · P_"mod" ≈ 24 · 35 · 605 ≈ 508 "kWp"
$

Esta estimación es coherente con el pico de generación real observado en el propio modelo (≈500 kW el 15 de agosto de 2025), por lo que se toma ≈500 kWp como capacidad instalada de OASIS en el resto de este trabajo.

== Electrólisis PEM para producción de hidrógeno verde

=== Principio de funcionamiento

El hidrógeno verde se produce mediante electrólisis del agua utilizando energía eléctrica renovable. En la electrólisis PEM (_Proton Exchange Membrane_), una membrana de intercambio protónico separa los electrodos (ánodo y cátodo) y actúa simultáneamente como electrolito y barrera de gas @grigoriev2020pem. Las semirreacciones son:

$
   "Ánodo:" & quad "H"_2"O" → 1/2 "O"_2 + 2"H"^+ + 2e^- \
  "Cátodo:" & quad 2"H"^+ + 2e^- → "H"_2
$

La reacción global es:

$
  "H"_2"O" → "H"_2 + 1/2 "O"_2 quad ("ΔH" = +286 "kJ/mol")
$

La energía eléctrica mínima teórica para esta reacción es de 39.4 kWh/kg H₂ (límite termodinámico). Los electrolizadores PEM comerciales actuales operan en el rango de 47--55 kWh/kg H₂ @irena2020green, lo que corresponde a una eficiencia eléctrica del 70--84%.

=== Ventajas del PEM frente al alcalino

Los electrolizadores PEM son preferibles frente a los alcalinos en aplicaciones acopladas a generación renovable por varias razones @buttler2018electrolysis @shivakumar2019pem:

- *Respuesta dinámica rápida*: el _stack_ PEM responde en milisegundos y admite un rango de carga de aproximadamente el 5 al 100 % de su potencia nominal, frente a los segundos y el 20--100 % del alcalino. La carga mínima del alcalino está limitada por la seguridad y no por la electrónica de potencia: su diafragma es permeable a los gases disueltos, de modo que a carga baja el _cruce de gases_ (`crossover`) de hidrógeno hacia el compartimento de oxígeno se aproxima al límite inferior de inflamabilidad, lo que obliga a mantener ese suelo de operación. Esta es la propiedad decisiva para acoplar el electrolizador a un campo fotovoltaico, cuya potencia varía con la nubosidad en cuestión de segundos.
- *Alta densidad de corriente*: los _stacks_ PEM operan en torno a 1--2 A/cm² frente a 0,2--0,4 A/cm² del alcalino. El efecto práctico se aprecia mejor en el área de celda necesaria para una misma producción: del orden de cientos de cm² en PEM frente a varios m² en alcalino, de donde resultan equipos mucho más compactos y aptos para instalación contenedorizada.
- *Alta pureza del hidrógeno producido*: entre el 99,9 % y el 99,9999 % según la configuración. El alcalino alcanza valores comparables: la ventaja del PEM no está en el valor final sino en partir de un cruce de gases mucho menor, lo que permite llegar a calidad de pila de combustible (norma ISO 14687) con un tren de acondicionamiento (separador, desoxidante catalítico y secador) integrado en el propio equipo, sin una unidad de purificación externa.
- *Presión diferencial*: los equipos PEM comerciales entregan hidrógeno típicamente a 30 bar, con un rango habitual de 20 a 40 bar, y evitan así una primera etapa de compresión mecánica. Como límite de diseño, la literatura sitúa la presión de celda del PEM por debajo de 70 bar frente a los 30 bar del alcalino @irena2020green. En OASIS el electrolizador entrega a 40 bar, que es exactamente la presión máxima del tanque tampón (@sec-tanque-lp), de modo que la compresión solo interviene en la etapa siguiente.

=== Curva de polarización

El comportamiento eléctrico del electrolizador PEM se caracteriza por su curva de polarización $U(i)$ (tensión de celda frente a densidad de corriente), que incluye las pérdidas de activación, óhmicas y de concentración @ursua2012pem:

$
  U = E_"rev" + η_"act" + η_"ohm" + η_"conc"
$

donde $E_"rev" ≈ 1.23$ V es la tensión reversible a condiciones estándar. En el rango de operación nominal, la potencia consumida es aproximadamente proporcional a la corriente, lo que permite modular la producción de hidrógeno regulando la potencia eléctrica de entrada entre el 10% y el 100% de la potencia nominal.

== Almacenamiento de hidrógeno

El hidrógeno recorre la instalación en dos etapas de presión encadenadas, con un compresor entre ellas. La @fig-cadena-h2 resume esa cadena, los equipos que la componen y los umbrales de nivel con los que el EMS decide sobre cada tanque; los tres apartados siguientes desarrollan cada etapa.

#figure(
  image("../img/cadena_hidrogeno.svg", width: 100%),
  caption: [Cadena de producción, almacenamiento y dispensación de hidrógeno de OASIS. El electrolizador entrega a la presión máxima del tanque tampón, de modo que la compresión solo interviene en la etapa siguiente. Los umbrales que acompañan a cada tanque son los que gobiernan la decisión del EMS y se justifican en el @cap-metodologia; `LOH` y `LOH_High` son fracciones de la presión máxima de su propio tanque, no de la masa almacenada.],
) <fig-cadena-h2>

=== Almacenamiento a baja presión (buffer) <sec-tanque-lp>

El hidrógeno producido por el electrolizador PEM se almacena inicialmente en un depósito tampón a presión relativamente baja. El de OASIS tiene un volumen de 3,1 m³ y una presión máxima de 40 bar, con una presión inicial de simulación de 26 bar (parámetros leídos del bloque `Low Press Tank` del modelo). Este depósito actúa como acumulador entre la producción discontinua (dependiente de la generación solar) y la demanda de compresión hacia el tanque de alta presión. Su función es desacoplar ambas operaciones y evitar arranques y paradas frecuentes del compresor.

=== Compresión hacia alta presión

Para el repostaje de vehículos de célula de combustible a 700 bar (estándar SAE J2601 para turismos) o 350 bar (vehículos pesados), es necesario comprimir el hidrógeno desde la presión de almacenamiento intermedia hasta la presión de dispensación. Se utilizan compresores de diafragma o compresores iónicos, con consumos típicos de 2--5 kWh/kg H₂ @sdanghi2019compression.

=== Almacenamiento a alta presión

El depósito de alta presión alimenta directamente el surtidor. Los depósitos comerciales para estaciones de servicio son cilindros de acero o fibra de carbono con volúmenes de 100--500 L. La masa almacenada es:

$
  m_"H2" = ρ(P, T) · V
$

donde la densidad $ρ$ del hidrógeno a alta presión se obtiene de la ecuación de van der Waals o tablas NIST; a presión atmosférica es de solo 0.09 kg/m³. El tanque de alta de OASIS tiene un volumen de 0,41 m³ y el bloque empleado en las simulaciones lo parametriza a 600 bar de presión máxima y 480 bar de presión inicial. Conviene precisar qué son los 700 bar que se asocian habitualmente a este tipo de instalación: son la presión nominal de servicio del depósito del *vehículo*, la que fija el estándar de repostaje SAE J2601 para turismos, y no la presión que basta con tener almacenada. Llenar un depósito hasta esa presión exige un diferencial a favor, y por eso las estaciones reales de 70 MPa almacenan en cascada por encima de 850 bar o interponen un compresor de refuerzo (_booster_) entre el almacenamiento y el surtidor; el tanque de alta del que este trabajo hereda los umbrales tiene, de hecho, un techo de seguridad de 900 bar @molero2025ems. Con los 600 bar del bloque, un repostaje completo no llegaría a la presión nominal del vehículo. El modelo no representa esa restricción: el surtidor se resuelve como un caudal másico que sale del tanque de alta, sin comprobación de la presión disponible. El efecto del reescalado de los umbrales sobre esos 600 bar se discute en @cap-metodologia.

Tomando como referencia los valores habituales de densidad para H₂ gaseoso a 15 °C (23,3 kg/m³ a 350 bar y ≈39,3 kg/m³ a 700 bar @sdanghi2019compression) y estimando por extrapolación lineal entre ambos puntos ≈29,2 kg/m³ a 480 bar y ≈34,7 kg/m³ a 600 bar, el tanque almacenaría del orden de 14,2 kg a los 600 bar de su presión máxima y 12,0 kg en su condición inicial de 480 bar. Nótese que se trata de una extrapolación fuera del intervalo definido por los dos puntos de referencia, y no de una interpolación: para un dimensionamiento definitivo procede tomar la densidad directamente de tablas NIST.

Una limitación del modelo condiciona la lectura de los resultados: los bloques de tanque de OASIS calculan la presión a partir de la cantidad de hidrógeno almacenado mediante la ecuación de los gases ideales, sin factor de compresibilidad. A 600 bar y 15 °C el hidrógeno real tiene una densidad de ≈34,7 kg/m³ frente a los ≈50,5 kg/m³ que predice el gas ideal, es decir, el modelo sobrestima en torno a un 45% la masa que cabe en el tanque lleno. La autonomía de hidrógeno que se observe en simulación es, por tanto, optimista respecto a la de una instalación real; corregirla exigiría sustituir la ecuación de estado del bloque por una de gas real (van der Waals, Noble-Abel o tabla NIST), lo que se propone como línea de trabajo futuro.

== Pila de combustible (PEMFC)

La pila de combustible de membrana de intercambio protónico (PEMFC) realiza el proceso inverso al electrolizador: combina hidrógeno y oxígeno atmosférico para generar electricidad, con agua y calor como únicos subproductos @larminie2003fuelcells:

$
  "H"_2 + 1/2 "O"_2 → "H"_2"O" + "Electricidad" + "Calor"
$

La tensión teórica de celda es de 1.23 V (a condiciones estándar), pero en operación real se reduce a 0.6--0.8 V por las mismas pérdidas de activación, óhmicas y de concentración que en el electrolizador. La eficiencia eléctrica de las PEMFC comerciales es del 50--60%, con posibilidad de cogeneración (calor + electricidad) hasta el 85%.

En el contexto de una estación de repostaje multi-energía, la pila de combustible tiene dos roles complementarios: actuar como generador de respaldo cuando la generación solar es insuficiente y el precio de la red es elevado, y proporcionar energía de arranque cuando la batería está descargada. El pico eléctrico a cubrir en modo isla no es solo el de los cargadores EV (2 × 50 kW = 100 kW): hay que sumar el consumo propio del compresor (15 kW) si estuviera operando en ese instante, más un margen de seguridad que cubra la degradación del equipo y la incertidumbre de dimensionamiento. Por ello, la FC de OASIS se ha dimensionado a 130 kW (100 kW de pico EV + 15 kW de compresor + ≈10 % de margen, redondeado a un tamaño de módulo comercial), en vez de a los 100 kW que cubrirían el pico de EV con margen cero. Este valor es el criterio de diseño que emplean los tres EMS de este trabajo como `PmaxFC`. El bloque electroquímico del modelo, en cambio, está parametrizado con 120 celdas de 600 cm² y una corriente máxima de 600 A, lo que corresponde a una potencia de salida sensiblemente menor; escalar el bloque hasta los 130 kW de diseño queda pendiente sobre el modelo físico, y mientras no se haga la consigna `RefFC` puede quedar saturada por el propio bloque antes de alcanzar el valor que solicita el EMS.

== Almacenamiento electroquímico (BESS)

Los sistemas de almacenamiento en batería (BESS, _Battery Energy Storage Systems_) proporcionan la respuesta rápida que la pila de combustible y el electrolizador no pueden ofrecer por sus tiempos de arranque. En microrredes de transporte, las baterías de ion-litio son la tecnología dominante por su alta densidad de energía (150--250 Wh/kg), alta eficiencia de ciclo (95--98%) y vida útil de 2000--4000 ciclos @faisal2018ess.

La función principal del BESS en una MERS es la gestión de los picos de potencia de los cargadores de EV: cuando dos cargadores de 50 kW operan simultáneamente (100 kW pico), el BESS puede absorber el excedente de generación solar o descargar para reducir la potencia importada de la red. El dimensionamiento óptimo del BESS en una estación de carga rápida se ha formulado como un problema de programación lineal entera mixta que minimiza el coste total anualizado incorporando la caracterización probabilística de la demanda de carga, la degradación de la batería y —de forma determinante— el término de potencia contratada de la tarifa @techno_economic_charging. En la escala temporal larga, la batería y el hidrógeno se reparten el trabajo en lugar de competir por la misma función: la primera cubre la respuesta rápida y los ciclos diarios, mientras que el almacenamiento en hidrógeno aporta la densidad energética y la duración que las baterías convencionales no alcanzan @integration_batteries, que es precisamente la división de tareas sobre la que se construye el EMS de este trabajo.

El bloque de batería de `OASIS.slx` sigue el modelo de circuito equivalente descrito en el manual de Simugrid, parametrizado con tensión de circuito abierto $V_"bt,0" = 380$ V, capacidad máxima de 1 MWh, constante de polarización $K = 0.000739$ V, amplitud de la zona exponencial $A = 20.314$ V, resistencia interna $R = 0.00027 med Omega$, corriente máxima de carga/descarga de 1 300 A y un estado de carga inicial del 70%. La capacidad en amperios-hora que el bloque utiliza internamente se deriva de los dos primeros parámetros, $C_120 = 1 "MWh" \/ 380 "V" ≈ 2632$ Ah. De la tensión y la corriente máxima se obtiene el límite de potencia del bloque:

$
  P_"max,BESS" = V_"bt,0" · I_"max" = 380 "V" · 1300 "A" ≈ 494 "kW"
$

Ese límite equivale a 0,5C sobre la capacidad de 1 MWh, un valor habitual en baterías estacionarias de ion-litio, y queda por encima tanto del mayor consumo simultáneo que la estación puede presentar (100 kW de cargadores, 200 kW de electrolizador y 15 kW de compresor) como de la mayor carga que recibe con excedente (en torno a 400 kW, el 80 % de un pico fotovoltaico de 500 kW). En la práctica, por tanto, la saturación de potencia de la batería no llega a activarse en las simulaciones de este trabajo, y el reparto de potencia entre batería y electrolizador descrito en @cap-metodologia queda gobernado por los umbrales de estado de carga. La capacidad de 1 MWh sí es dimensionalmente coherente con la instalación: equivale a unas dos horas de generación fotovoltaica a potencia pico, y a unos cuatro días de la demanda diaria de carga eléctrica estimada en @cap-datos-ev. Un dimensionamiento fino del BESS —que no se aborda aquí— debería partir del término de potencia contratada de la tarifa y del perfil de demanda de los cargadores @techno_economic_charging, y no del límite interno del bloque de simulación.

== Infraestructura de carga eléctrica (EV)

La norma IEC 61851 establece cuatro modos de carga para vehículos eléctricos, de los cuales los más relevantes para estaciones públicas son el Modo 3 (carga CA trifásica, hasta 22 kW) y el Modo 4 (carga CC rápida, 50--350 kW). La adopción creciente de sistemas DC fast charging (Level 3 según la clasificación norteamericana SAE J1772) responde a la demanda del usuario de tiempos de recarga compatibles con una parada en carretera @charin2022.

El impacto de los cargadores DC rápidos sobre la red de distribución es significativo: un único cargador de 150 kW demanda una corriente de ≈217 A a 400 V trifásico, lo que puede provocar caídas de tensión, desbalances de fase y picos de potencia que saturen el transformador de distribución. La inestabilidad de red asociada a los picos súbitos de carga, las pérdidas eléctricas y la sobrecarga de los equipos de alta tensión son, de hecho, la motivación explícita de buena parte de los trabajos que integran generación renovable y almacenamiento en la propia estación @roslan2024technoeconomic. La integración de BESS y gestión dinámica de carga (DLM, _Dynamic Load Management_) son estrategias clave para mitigar este impacto @leemput2014ev.

La @tbl-cargadores-comparacion resume las características de los principales estándares de carga rápida DC actuales:

#figure(
  table(
    columns: (1.2fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center, center),
    table.header([*Estándar*], [*Potencia máx.*], [*Conector*], [*Tensión DC*], [*Mercado*]),
    [CCS1 (SAE J1772)], [350 kW], [CCS Combo 1], [200--1000 V], [EEUU / Corea],
    [CCS2 (IEC 62196)], [350 kW], [CCS Combo 2], [200--1000 V], [Europa],
    [CHAdeMO 3.0], [900 kW], [CHAdeMO], [500 V], [Japón],
    [NACS (Tesla)], [250 kW], [NACS], [50--1000 V], [EEUU (adoptado por SAE como J3400)],
    [GB/T 20234.3], [250 kW], [GB/T], [200--750 V], [China],
  ),
  caption: [Principales estándares de carga rápida DC para vehículos eléctricos.],
) <tbl-cargadores-comparacion>

== Microrredes y sistemas de gestión de energía

=== Concepto de microrred

Una microrred (_microgrid_) es un sistema eléctrico de pequeña escala que agrupa fuentes de generación distribuida, almacenamiento y cargas, capaz de operar tanto conectado a la red (_grid-connected_) como en modo isla (_islanded_). La norma IEEE 1547.4 define los requisitos para la operación de microrredes en baja y media tensión @ieee1547_4.

En una microrred para movilidad, los componentes típicos son: generación renovable (PV, eólico), almacenamiento a corto plazo (baterías), almacenamiento a largo plazo (hidrógeno), cargas controlables (electrolizador, compresor) y cargas no controlables (cargadores EV, demanda H2) @ton2012microgrid. La arquitectura concreta de OASIS (componentes, potencias y señales que intercambian con el EMS) se describe en el @cap-metodologia (@fig-arquitectura-oasis).

=== Estrategias de gestión energética (EMS)

El Sistema de Gestión de Energía (EMS, _Energy Management System_) es el componente de software que coordina todos los flujos de potencia en la microrred para minimizar el coste operacional (energía importada de la red), maximizar el autoconsumo renovable y garantizar la calidad de servicio (evitar cortes de carga) @olivares2014trends.

Las estrategias de EMS se clasifican en tres grandes categorías:

*Estrategias reactivas o basadas en reglas (_rule-based_)*: toman decisiones en tiempo real en función de umbrales predefinidos del estado del sistema (nivel del tanque, SOC de la batería, excedente solar). Son deterministas, fáciles de implementar e interpretar, y robustas frente a incertidumbre. Su limitación principal es que, en su forma básica, no incorporan información predictiva y por tanto no pueden anticiparse a eventos futuros; la vía natural de mejora es enriquecer las reglas con previsiones de generación y demanda sin abandonar la estructura heurística @pascual2015ruleems. Este trabajo parte de esa vía y mide cuánto aporta.

*Estrategias de control predictivo basado en modelos (MPC, _Model Predictive Control_)*: formulan el problema de gestión como una optimización a horizonte deslizante, e incorporan predicciones de generación, precio y demanda para calcular la secuencia de acciones óptima @garcia1989mpc. Ofrecen una mejor calidad de solución que las estrategias reactivas a costa de mayor complejidad computacional y dependencia de la calidad de las predicciones.

*Estrategias basadas en aprendizaje automático*: utilizan técnicas de aprendizaje por refuerzo (RL, _Reinforcement Learning_) o redes neuronales para aprender políticas de control óptimas a partir de experiencia histórica. La revisión de @perera2021rl sobre aplicaciones del aprendizaje por refuerzo en sistemas energéticos, que abarca 283 trabajos repartidos en siete categorías de aplicación, observa que predominan los métodos actor-crítico, que los métodos _batch_ están infrautilizados pese a la disponibilidad de datos históricos y —lo más relevante para este trabajo— que la comparación sistemática frente a métodos competidores sigue siendo escasa. Son especialmente prometedoras en entornos con alta variabilidad e incertidumbre, pero requieren grandes volúmenes de datos y pueden presentar comportamientos imprevisibles en condiciones no vistas durante el entrenamiento.

En el presente trabajo la capa base es también una heurística de reglas, y las previsiones LSTM de irradiancia y precio entran como dato de una decisión con margen económico (cuándo producir hidrógeno) en lugar de disparar acciones de magnitud fija. Cuánto aporta cada pieza, previsión y reglas, se mide por separado en el @cap-resultados.

=== EMS en instalaciones multi-energía: revisión bibliográfica

@garciatorres2015mpch2 formulan la gestión de una microrred basada en hidrógeno con almacenamiento híbrido como un problema de control predictivo que maximiza el beneficio económico minimizando simultáneamente la degradación de los equipos de almacenamiento, modelando la dinámica continua y discreta mediante _mixed logic dynamics_ y resolviendo el problema resultante como un MIQP. Es un antecedente directo del enfoque de este trabajo en dos sentidos: incorpora explícitamente el desgaste de los equipos como objetivo (y no solo el coste), y procede del mismo grupo de investigación que el modelo de partida. @apostolou2019hrs revisan el estado de las estaciones de repostaje de hidrógeno y su infraestructura, y señalan que el coste de producción y compresión del hidrógeno sigue siendo el factor dominante en la viabilidad de estas instalaciones, lo que justifica que la decisión económica «producir localmente o comprar fuera» ocupe un lugar central en el EMS.

En cuanto a la integración conjunta de ambos vectores en una misma instalación, @tahir2024hybridstation proponen un marco de diseño de estación híbrida que atiende simultáneamente carga de vehículo eléctrico y repostaje de hidrógeno evaluando múltiples atributos de diseño, lo que confirma que el problema de coordinar ambos servicios bajo un único sistema de gestión sigue siendo una línea abierta.

== Predicción de irradiancia solar con redes neuronales

La predicción de irradiancia solar a horizonte de 24 horas es un problema bien establecido en la literatura de aprendizaje automático aplicado a energías renovables. Las redes LSTM han demostrado ser especialmente eficaces en este dominio por su capacidad de capturar dependencias temporales a múltiples escalas @wang2019lstmsolar.

@aslam2021solar revisan los métodos de aprendizaje profundo aplicados a la predicción de carga eléctrica y de generación renovable en microrredes inteligentes, y sitúan las arquitecturas recurrentes —LSTM y GRU (_Gated Recurrent Unit_)— entre las que mejor capturan la dependencia temporal de estas series frente a los enfoques estadísticos clásicos y a las redes _feedforward_.

El uso de los productos de reanálisis NASA POWER como fuente de datos de irradiancia, en lugar de medidas en tierra, ha sido validado de forma independiente. @quansah2022nasapower los contrastan contra 22 estaciones sinópticas a lo largo de 35 años de registro y obtienen coeficientes de correlación de 0,59 a 0,94, errores cuadráticos medios de 0,13 a 0,46 kWh/m²/día y errores porcentuales medios del 1,11% al 6,34%, con el mejor acuerdo en las zonas de menor actividad convectiva. Un error de esa magnitud es aceptable para una aplicación de EMS, donde a la predicción le basta con ser suficientemente buena para discriminar entre días soleados y nublados; hay que tenerlo presente, en todo caso, porque se suma al error del propio modelo de predicción.

== Predicción del precio spot de electricidad

La predicción del precio horario de la electricidad en el mercado mayorista es un problema de complejidad elevada, caracterizado por: alta variabilidad, presencia de picos extremos (_price spikes_), régimen marcadamente no estacionario y fuerte dependencia de variables exógenas (demanda, mix de generación, precio del gas natural) @weron2014electricity.

Los modelos LSTM y sus variantes (BiLSTM, TCN, Transformer) han desplazado progresivamente a los modelos estadísticos clásicos (ARIMA, SARIMA) y econométricos (GARCH) en las aplicaciones de predicción de precio de electricidad, especialmente a partir de 2018. @lago2021benchmarking realizan el benchmark más completo hasta la fecha y comparan 27 métodos diferentes sobre 8 mercados europeos: los modelos basados en redes neuronales profundas superan a los clásicos en 6 de los 8 mercados, con una reducción media del MAE del 12--28%.

La incorporación de variables meteorológicas (irradiancia, temperatura, viento) como features del modelo de precio es una práctica consolidada en el mercado español, donde la alta penetración renovable hace que el precio spot esté fuertemente correlacionado con la generación solar y eólica @ziel2018daprices. Esta es precisamente la estrategia seguida en el modelo LSTM de precio del @cap-lstm, que combina el precio histórico con variables meteorológicas NASA y el índice de capacidad FV instalada.

El problema de los precios negativos @janke2019negative merece mención específica: en el mercado OMIE, los precios negativos se producen cuando la generación renovable supera la demanda (habitualmente en horas nocturnas de alta eólica o festivos con alta solar). Estos episodios son difícilmente predecibles con modelos estadísticos y requieren tratamiento especial en el EMS: en lugar de intentar predecirlos con precisión, es más efectivo diseñar el EMS para ser oportunista (cargar baterías y producir hidrógeno cuando el precio cae por debajo de un umbral predefinido, independientemente de la predicción exacta).

== Simulación de microrredes con Simulink/Simscape

La validación de sistemas de gestión de energía previo a su implantación real se realiza típicamente mediante simulación en herramientas como MATLAB/Simulink, Modelica/Dymola o HOMER @HOMER. Simulink, con su biblioteca Simscape Electrical, proporciona bloques de circuito para modelar buses AC/DC, inversores, baterías, electrolizadores y pilas de combustible con distintos niveles de fidelidad @simulink_simscape.

La plataforma utilizada en este trabajo, Simugrid, es un entorno de simulación de microrredes desarrollado específicamente para modelar sistemas de almacenamiento y gestión de energía en el contexto de la movilidad sostenible. Su característica diferencial es la integración nativa de bloques de S-Functions en MATLAB que permiten conectar modelos de aprendizaje automático (como los LSTM desarrollados en este trabajo) directamente con el bucle de simulación de Simulink, y posibilitan así la validación de estrategias de EMS que incorporan predicciones en tiempo real.

Simugrid es la librería complementaria del libro _Model Predictive Control of Microgrids_ @bordons2020mpcmicrogrids, de C. Bordons, F. García-Torres y M. A. Ridao (este último, tutor de este TFG), publicado por Springer Nature dentro de la serie _Advances in Industrial Control_. La librería, desarrollada en el Dpto. de Ingeniería Automática de la Universidad de Sevilla, proporciona los modelos matemáticos de batería, pila de combustible, electrolizador y generación renovable en los que se apoya el bloque OASIS empleado en este trabajo, así como ejemplos de controladores MPC.

== Posicionamiento del presente trabajo

A la vista de la revisión bibliográfica anterior, el presente trabajo combina tres elementos que apenas se encuentran tratados de forma conjunta en la literatura revisada:

1. *Integración de múltiples vectores energéticos* (EV + H2) bajo un único EMS en una estación de repostaje de carretera, con generación fotovoltaica local.

2. *Medida de lo que aporta la predicción dentro de un EMS de reglas*: dos modelos LSTM de irradiancia solar y precio, validados frente a líneas base no triviales e integrados en el bucle de Simulink mediante S-Functions, y una cadena de medida (comparación pareada por semilla, oráculo, descomposición de la importación por destinos y ablación por componentes) que separa la mejora atribuible a la previsión de la atribuible al diseño de las reglas que la consumen.

3. *Validación simulada con perfiles de demanda EV basados en datos reales* (dataset DESL-EPFL Level 3 DC fast charging), en lugar de perfiles sintéticos simplificados.

La combinación de estos tres elementos, en el contexto de la arquitectura de la estación OASIS y el entorno de Sevilla (alta irradiancia, precio spot español), constituye la contribución de este trabajo. Su resultado principal —que en esta instalación el margen económico estaba en el orden en que se usa la batería, y no en predecir mejor un precio que el mercado diario ya publica— se desarrolla en el @cap-metodologia y el @cap-resultados.
