# Guion de defensa — TFG

**Estrategias de gestión energética para una estación de repostaje multi-energía: cuantificación de la mejora aportada por la predicción con redes LSTM**

Fernando Román Hidalgo · Tutor: Miguel Ángel Ridao Carlini · Dpto. de Ingeniería de Sistemas y Automática · ETSI, Universidad de Sevilla

Duración medida sobre el texto real de este guion: **19:54** a 135 palabras/minuto (ritmo de defensa pausado), **18:09** a 148 ppm, que es el ritmo al que se acaba hablando con dos o tres ensayos. 19 diapositivas + 5 de reserva.

---

## Cómo usar este documento

Cada diapositiva tiene tres partes: **[PANTALLA]** es lo que se proyecta, **[DICES]** es el texto hablado —y lo único que cuenta para el cronómetro—, y **[ENTREGA]** es una indicación de puesta en escena que NO se pronuncia. El texto hablado está en las notas del orador del .pptx, así que lo tienes también en el portátil durante la defensa.

No memorices palabra por palabra: memoriza la primera frase de cada diapositiva y las frases ancla del final. El resto se improvisa solo si tienes el hilo.

---

## Mapa de tiempos

| # | Diapositiva | Bloque | Duración | Acumulado |
|---|---|---|---|---|
| 1 | Estrategias de gestión energética para una estación de repostaje multi-energía | — | 0:29 | 0:29 |
| 2 | El marco ya pone fechas; la infraestructura sigue separada por vector | PLANTEAMIENTO | 1:26 | 1:55 |
| 3 | La estación OASIS, modelada en Simulink | PLANTEAMIENTO | 0:36 | 2:31 |
| 4 | El EMS decide tres cosas, y es lo único que cambia entre versiones | PLANTEAMIENTO | 0:59 | 3:30 |
| 5 | La demanda sale de sesiones reales de carga rápida, no de una hipótesis | DATOS | 1:01 | 4:31 |
| 6 | Y los datos de entrenamiento, de dos fuentes públicas alineadas hora a hora | DATOS | 0:56 | 5:27 |
| 7 | Dos redes con la misma arquitectura y parada temprana por validación | MODELOS LSTM | 0:50 | 6:17 |
| 8 | El problema: ninguna de las dos redes bate sola a su línea base | MODELOS LSTM | 1:12 | 7:29 |
| 9 | La solución: proyección física y ponderación con el naive | MODELOS LSTM | 1:08 | 8:37 |
| 10 | Cuatro escenarios que cruzan recurso solar y régimen de precio | COMPARACIÓN | 0:49 | 9:26 |
| 11 | Cuatro piezas sostienen todas las cifras que vienen a continuación | COMPARACIÓN | 1:33 | 10:59 |
| 12 | Versión A: la referencia ya es una heurística madura | LOS TRES EMS | 0:54 | 11:53 |
| 13 | Versión B: la previsión mejora sistemáticamente el servicio de hidrógeno | LOS TRES EMS | 1:11 | 13:04 |
| 14 | La batería estaba al 85 % mientras el electrolizador compraba red | LOS TRES EMS | 1:14 | 14:18 |
| 15 | Versión C: separar de dónde sale la energía de cuándo conviene producir | LOS TRES EMS | 1:12 | 15:30 |
| 16 | Versión C: −13,9 % de coste semanal, en los veinte pares evaluados | LOS TRES EMS | 1:11 | 16:41 |
| 17 | Y la mejora se puede atribuir pieza a pieza | LOS TRES EMS | 1:14 | 17:55 |
| 18 | Limitaciones | LIMITACIONES | 0:49 | 18:44 |
| 19 | Conclusiones | CONCLUSIONES | 1:10 | 19:54 |

**Marcas de control:** al terminar la 9 (la solución de las LSTM) deberías ir por **8:30**; al terminar la 14 (el diagnóstico), por **14:15**. Si vas más de un minuto por encima en cualquiera de las dos, aplica los recortes del final.

---

## 1 · Estrategias de gestión energética para una estación de repostaje multi-energía  —  0:29

**[PANTALLA]**  Título, autor, tutor, departamento, titulación y marca de la Universidad de Sevilla. Fondo oscuro.

**[DICES]**

> Buenos días. Gracias, presidente.
>
> Soy Fernando Román Hidalgo y presento el Trabajo Fin de Grado «Estrategias de gestión energética para una estación de repostaje multi-energía», dirigido por el catedrático Miguel Ángel Ridao Carlini, del Departamento de Ingeniería de Sistemas y Automática.
>
> La charla tiene tres movimientos: el planteamiento y los datos, los dos modelos de predicción, y los tres gestores de energía que comparo.

**[ENTREGA — no se dice en voz alta]** No leas el título: ya está en pantalla. Anuncia la estructura y levanta la vista.

---

## 2 · El marco ya pone fechas; la infraestructura sigue separada por vector  —  1:26

*Bloque: PLANTEAMIENTO · 1 de 7*

**[PANTALLA]**  Tres cifras de contexto: 25 % · 100 – 150 · 5,5 M. Línea de fuentes citadas. dos columnas: Vehículo eléctrico de batería · Vehículo de pila de combustible.

> **Bloque de énfasis:** Los dos dependen de una infraestructura hoy separada, y eso fragmenta la inversión. La estación multi-energía los integra — y con ella el reto pasa a ser de operación: decidir, en cada instante, de dónde sale cada kilovatio.

**[DICES]**

> El transporte es una cuarta parte de las emisiones de gases de efecto invernadero de la Unión, y casi tres cuartas partes de esa fracción son transporte por carretera. Es uno de los focos que el Pacto Verde Europeo tiene que cerrar para dos mil cincuenta.
>
> El marco regulatorio ya pone fechas. La Hoja de Ruta del Hidrógeno española fija entre cien y ciento cincuenta hidrogeneras públicas para dos mil treinta, y sitúa los corredores de repostaje verde como línea prioritaria. El PNIEC fija cinco millones y medio de vehículos eléctricos para esa misma fecha, y el reglamento europeo AFIR convierte el despliegue de recarga en objetivos vinculantes.
>
> El problema es esa fragmentación: cada vector arrastra hoy su propia infraestructura y su propia inversión.
>
> Y ya hay precedentes de integrarlas. Repsol inauguró en enero de dos mil veinticinco la estación de Morro Jable, en Fuerteventura: fotovoltaica, baterías, pila de hidrógeno y recarga eléctrica. Es prácticamente la combinación de componentes de OASIS, a menor escala y sin electrolizador propio.
>
> Con esa integración el reto deja de ser de dimensionamiento y pasa a ser de operación: decidir, en cada instante, de dónde sale cada kilovatio.

**[ENTREGA — no se dice en voz alta]** Las dos referencias que demuestran que has investigado —H2ME y Morro Jable— van habladas, no en pantalla. Morro Jable es tu mejor baza: casi los mismos componentes que OASIS.

---

## 3 · La estación OASIS, modelada en Simulink  —  0:36

*Bloque: PLANTEAMIENTO · 1 de 7*

**[PANTALLA]**  Figura `electrolinera-iso-NE.png`. seis cifras de planta numeradas sobre la maqueta: ≈500 kWp · 1 MWh · 200 kW · 40 / 600 bar · 130 kW · 2 × 50 kW.

**[DICES]**

> Esta es la instalación: la microrred OASIS del departamento, modelada en Simulink sobre la librería Simugrid. Quinientos kilovatios pico de fotovoltaica en marquesina, una batería de un megavatio-hora, un electrolizador PEM de doscientos kilovatios, dos tanques de hidrógeno a distinta presión con su compresor, una pila de combustible y dos cargadores rápidos.
>
> De todas estas cifras, dos están dimensionadas en este trabajo y no heredadas: la potencia del cargador y su número. Las justifico enseguida con los datos de demanda.

**[ENTREGA — no se dice en voz alta]** No recites la tabla: está en pantalla. Lo que aportas hablando es la distinción entre heredado y dimensionado.

---

## 4 · El EMS decide tres cosas, y es lo único que cambia entre versiones  —  0:59

*Bloque: PLANTEAMIENTO · 1 de 7*

**[PANTALLA]**  Figura `arquitectura_modulos_oasis.png`. tres decisiones numeradas: Sobra sol · Falta energía · En todo momento.

> **Bloque de énfasis:** Objetivo del trabajo: medir qué parte de la mejora es de la predicción y qué parte de las reglas que la consumen.

**[DICES]**

> El gestor de energía es un único bloque de Simulink con once entradas y seis salidas, y toma tres decisiones.
>
> Cuando sobra sol, cómo repartir el excedente entre cargar la batería y producir hidrógeno. Cuando falta, en qué orden cubrir el déficit: batería, pila, red. Y en todo momento, si conviene producir hidrógeno o reponerlo desde fuera, comparando el coste del kilogramo producido aquí con su precio de reposición.
>
> Todas las versiones que voy a comparar mantienen exactamente esta firma. Cambia el script del bloque de decisión y nada más: el mismo modelo físico, los mismos perfiles de entrada, la misma semilla de demanda.
>
> Y el objetivo del trabajo no es solo mejorar ese gestor, sino poder atribuir la mejora: cuánto viene de la predicción y cuánto de las reglas que la consumen.

**[ENTREGA — no se dice en voz alta]** «Solo cambia el bloque de decisión» es tu primer blindaje metodológico.

---

## 5 · La demanda sale de sesiones reales de carga rápida, no de una hipótesis  —  1:01

*Bloque: DATOS · 2 de 7*

**[PANTALLA]**  Figuras: `llegadas_por_hora.png` y `energia_por_sesion.png` y `colas_espera_cargadores.png`. tres líneas de apoyo bajo las figuras.

**[DICES]**

> El primer bloque de datos sirve para dimensionar, y fija dos parámetros de la instalación.
>
> La fuente es DESL-EPFL, sesiones reales de carga rápida: mil ochocientas setenta y cinco válidas, con una energía media de treinta y dos coma dos kilovatios-hora y ocho sesiones y media al día. Lo contrasto con Caltech, que es carga lenta, para comprobar que son familias distintas.
>
> De ahí salen las dos decisiones. Los cincuenta kilovatios del cargador, porque cubren una sesión media en treinta y nueve minutos sin exigir transformador de media tensión. Y el número de cargadores por teoría de colas, un modelo eme-eme-ce sobre la hora punta: con dos, la espera se mantiene acotada.
>
> Con esas mismas distribuciones se genera el perfil de demanda de cada simulación. Es estocástico, y eso importará en la comparación.

**[ENTREGA — no se dice en voz alta]** Este bloque es trabajo tuyo de principio a fin. Cuéntalo con calma: es lo que justifica que la instalación sea creíble.

---

## 6 · Y los datos de entrenamiento, de dos fuentes públicas alineadas hora a hora  —  0:56

*Bloque: DATOS · 2 de 7*

**[PANTALLA]**  Tabla.

> **Bloque de énfasis:** El split es temporal, nunca aleatorio: mezclar horas entre train y test regalaría información del futuro.

**[DICES]**

> El segundo bloque es el de entrenamiento: dos fuentes públicas alineadas hora a hora.
>
> Para la irradiancia, NASA POWER en Sevilla: diecinueve años horarios con ocho variables, entre ellas un índice de nubosidad calculado y las codificaciones cíclicas de hora y día.
>
> Para el precio, el mercado diario español vía ENTSO-E: cinco años, catorce variables. Ahí entran los dos lags de precio, el de veinticuatro horas y el semanal, y la capacidad fotovoltaica instalada en España, que pasa de quince gigavatios en dos mil veintiuno a treinta y seis en dos mil veinticinco y explica la caída del precio a mediodía.
>
> Y un detalle que importa: el split es temporal en los dos casos, nunca aleatorio. Mezclar horas entre entrenamiento y test regalaría información del futuro.

**[ENTREGA — no se dice en voz alta]** La frase del split es la que te compra credibilidad con un tribunal que sabe de aprendizaje automático.

---

## 7 · Dos redes con la misma arquitectura y parada temprana por validación  —  0:50

*Bloque: MODELOS LSTM · 3 de 7*

**[PANTALLA]**  Figuras: `TrainingSol_rmse.png` y `TrainingPrecio_rmse.png`. tres líneas de apoyo bajo las figuras.

**[DICES]**

> Las dos redes comparten arquitectura: dos capas LSTM apiladas, de ciento veintiocho y sesenta y cuatro unidades, con dropout, capa densa y salida de veinticuatro valores, que es el horizonte de un día.
>
> Las dos se entrenan con Adam y paran por criterio de validación: la solar en la época veintiuno de trescientas, la de precio en la veintinueve de doscientas. En pantalla, la curva de RMSE: azul entrenamiento, negro validación. No se separan: no hay sobreajuste.
>
> Una diferencia que sí importa: el modelo solar puede imponer que la irradiancia predicha no sea negativa. El de precio no, porque el precio spot admite negativos, y eso obliga después a un tratamiento distinto.

**[ENTREGA — no se dice en voz alta]** Rápida. Es la diapositiva de «así están hechas», no de resultados.

---

## 8 · El problema: ninguna de las dos redes bate sola a su línea base  —  1:12

*Bloque: MODELOS LSTM · 3 de 7*

**[PANTALLA]**  Figuras: `lstm_solar_PrediccionSolarEnLosDiasDeLaCampana.png` y `lstm_precio_MAEPorHorizon.png`. tres cifras destacadas: − 8,8 % · − 7,1 % · + 27,7 %.

**[DICES]**

> Y aquí está el resultado que determina lo que finalmente se despliega.
>
> Las dos redes se evalúan contra líneas base no triviales: la solar contra la persistencia de cielo claro, la de precio contra la persistencia de veinticuatro horas, que es la referencia mínima que exigen las guías del campo. Ninguna la bate en el agregado de veinticuatro horas: la solar queda un ocho coma ocho por ciento por detrás, la de precio un siete coma uno.
>
> El diagnóstico es distinto en cada una. La solar predice irradiancia en bruto y tiene que reconstruir la geometría solar que la línea base recibe gratis: aporta hasta la cuarta hora y pierde después. La de precio ha aprendido el perfil calendario-solar, que es justo lo que la persistencia reproduce sin coste.
>
> Y detecté y corregí una realimentación del buffer de precio que degradaba el error un veintisiete coma siete por ciento. Todas las cifras de esta defensa son posteriores a esa corrección.

**[ENTREGA — no se dice en voz alta]** Presentar esto como resultado medido, no como fallo. Es lo que demuestra que validaste contra la referencia correcta.

---

## 9 · La solución: proyección física y ponderación con el naive  —  1:08

*Bloque: MODELOS LSTM · 3 de 7*

**[PANTALLA]**  Dos cifras destacadas: + 5,8 % · + 6,6 %. tres pasos: Proyección sobre la envolvente · Ponderación con la línea base · Corrección del lazo cerrado.

> **Bloque de énfasis:** Lo que consume el EMS no es la salida cruda de la red, sino esta señal combinada.

**[DICES]**

> La solución tiene tres partes, y ninguna exige reentrenar.
>
> La primera es física: proyectar la predicción sobre la envolvente de cielo claro, es decir, no permitir que la irradiancia prevista supere a la de cielo despejado. Con eso el error diurno baja alrededor de un seis por ciento.
>
> La segunda es la que da nombre a la diapositiva: ponderar la red con su propia línea base. Una combinación convexa con un peso distinto por cada hora del horizonte, ajustado sobre validación, nunca sobre test. Los dos predictores cometen errores poco correlacionados —la red captura el perfil, la persistencia el nivel del día— y esa es la situación en la que combinar aporta. El resultado: más cinco coma ocho por ciento en solar y más seis coma seis en precio.
>
> Y la tercera es la corrección del lazo cerrado, realimentando con el precio real de la hora ya transcurrida, que sigue siendo estrictamente causal.

**[ENTREGA — no se dice en voz alta]** Esta es la diapositiva que cierra el bloque de redes. Deja claro que lo desplegado es la señal combinada.

---

## 10 · Cuatro escenarios que cruzan recurso solar y régimen de precio  —  0:49

*Bloque: COMPARACIÓN · 4 de 7*

**[PANTALLA]**  Figura `fig_met_escenarios.png`. tres líneas de apoyo bajo las figuras.

**[DICES]**

> Para comparar los gestores hacen falta escenarios, y no los elegí al azar: cruzan las dos variables que gobiernan la decisión del EMS, recurso solar y régimen de precio.
>
> Un laborable soleado con precio plano. Un laborable nublado, con índice de claridad de cero coma treinta y seis y punta de ciento noventa y cuatro euros el megavatio-hora, que es el caso sin excedente. Un fin de semana soleado con precio casi nulo a mediodía. Y el día de mayor diferencial de dos mil veinticinco, de veinticuatro a doscientos cincuenta y dos euros.
>
> Y cada uno se repite con varias semillas del generador de demanda, porque la demanda es estocástica.

**[ENTREGA — no se dice en voz alta]** Enlaza directa con la siguiente: «y esas semillas son la clave de cómo comparo».

---

## 11 · Cuatro piezas sostienen todas las cifras que vienen a continuación  —  1:33

*Bloque: COMPARACIÓN · 4 de 7*

**[PANTALLA]**  Cuatro conceptos: Pareado por semilla · Test de Wilcoxon · Umbral de relevancia · Oráculo.

**[DICES]**

> Antes de las cifras, las cuatro piezas que las sostienen.
>
> La primera es la comparación pareada, que es lo que ven en el esquema: la semilla ene genera exactamente el mismo perfil de demanda en todas las versiones, los mismos vehículos a las mismas horas, así que la diferencia se calcula par a par. El ruido de la demanda es común a los dos miembros, se cancela en la resta, y el contraste gana potencia. Veinte pares: cuatro escenarios por cinco semillas.
>
> La segunda es el test de Wilcoxon, de rangos con signo. Empecé con un t-test y lo abandoné: tres semillas del escenario nublado dominaban la media, con medias hasta veinte veces la mediana. El contraste describía esas tres tiradas, no a la población.
>
> La tercera es un umbral de relevancia económica. Medí la dispersión del coste de la propia referencia entre grupos de semillas: nueve euros con treinta y tres por semana. Una diferencia significativa por debajo de eso la declaro operativamente nula, y lo fijé antes de simular.
>
> Y la cuarta es el oráculo: repetir una tanda con la previsión perfecta. No es desplegable, es una cota superior. Si con error cero una estrategia no gana, ninguna mejora de la previsión va a hacer que gane.

**[ENTREGA — no se dice en voz alta]** Ritmo pausado, una pieza cada vez. Es la diapositiva que te compra credibilidad para todo el bloque siguiente.

---

## 12 · Versión A: la referencia ya es una heurística madura  —  0:54

*Bloque: LOS TRES EMS · 5 de 7*

**[PANTALLA]**  Cuatro mecanismos: Reparto dinámico por estado de carga · Tiempo mínimo de funcionamiento · Gestión de las dos presiones · Decisión económica de producir.

> **Bloque de énfasis:** No es una regla ingenua construida para perder: es el punto de partida contra el que hay que medirse.

**[DICES]**

> El primer gestor, la Versión A, es la referencia: viene del TFM previo del grupo y lo he portado a esta arquitectura.
>
> Quiero insistir en lo que ya trae, porque condiciona cómo se lee todo lo demás. Reparto dinámico de potencia entre batería y electrolizador por tramos de estado de carga. Tiempo mínimo de funcionamiento de dos horas con histéresis y anti-rebote, para que los equipos electroquímicos no conmuten cada pocos minutos. La gestión de los dos niveles de presión con su compresor. Y una decisión económica de producir hidrógeno frente a reponerlo fuera.
>
> Es decir, ya tiene los mecanismos que distinguen a un gestor de reglas maduro de un reparto por prioridades. Lo que no tiene es ninguna predicción.

**[ENTREGA — no se dice en voz alta]** Si el tribunal no retiene esto, el 14 % del final parecerá fácil. Insiste.

---

## 13 · Versión B: la previsión mejora sistemáticamente el servicio de hidrógeno  —  1:11

*Bloque: LOS TRES EMS · 5 de 7*

**[PANTALLA]**  Tres cifras destacadas: 39 / 40 · × 10 · − 18,9 pts.

> **Bloque de énfasis:** De ese empate sale la regla de diseño que se aplica después: la acción disparada por una previsión debe estar condicionada, y su magnitud salir del margen económico disponible, no de una constante.

> **Nota al pie:** En coste empata con la heurística: −0,13 €/día sobre un recibo diario de ≈45 €, no significativo, y tampoco gana con previsión perfecta.

**[DICES]**

> La Versión B añade las dos previsiones donde la heurística ya decidía: la solar desplaza el reparto cuando anticipa que va a caer el excedente, y la de precio gobierna un arbitraje de batería.
>
> Y tiene una victoria clara: el servicio de hidrógeno. Mantiene el tanque de alta más lleno y pasa menos tiempo en nivel crítico, en treinta y nueve de cuarenta pares. Y escala con la calidad de la previsión: con oráculo se multiplica por diez. El mecanismo funciona; lo que limita es la previsión, no el diseño.
>
> En coste empata: trece céntimos sobre un recibo diario de unos cuarenta y cinco euros, y tampoco gana con previsión perfecta.
>
> De ahí sale la regla de diseño que aplico después: una primera implementación que traducía «el precio va a subir» en una acción de magnitud fija empeoraba el coste, y más cuanto mejor era la previsión. La acción tiene que estar condicionada y su magnitud salir del margen económico.

**[ENTREGA — no se dice en voz alta]** Tono de quien informa. B tiene su victoria y la cuentas primero; el empate en coste viene después y sin disculpas.

---

## 14 · La batería estaba al 85 % mientras el electrolizador compraba red  —  1:14

*Bloque: LOS TRES EMS · 5 de 7*

**[PANTALLA]**  Figura `fig_res_destino_import.png`. tres cifras destacadas: 76 % · 121,5 €/MWh · 85 %.

> **Bloque de énfasis:** La información necesaria ya estaba en las entradas de la Versión A: ninguna previsión hacía falta para ver esto.

**[DICES]**

> Al descomponer la importación de la Versión A por destinos aparece esto, y es lo que motiva el tercer gestor. Fíjense solo en la primera barra: las otras dos son la Versión C, que veremos enseguida.
>
> De los mil trescientos veintiún kilovatios-hora que la referencia compra a la red en una semana, mil seis —el setenta y seis por ciento— van al electrolizador, a ciento veintiuno con cinco euros el megavatio-hora. Los vehículos son el veintiuno por ciento.
>
> Y en los instantes exactos en que compra esa energía, la batería está al ochenta y cinco por ciento de carga de media, y nunca baja del sesenta y nueve.
>
> El motivo está en el orden del código: en la rama de déficit la batería cubre los vehículos y, en un paso posterior, la decisión económica enciende el electrolizador; esa carga nueva no se le vuelve a ofrecer a la batería, así que la absorbe la red. Toda la información necesaria ya estaba en las entradas.

**[ENTREGA — no se dice en voz alta]** Sobrio. Es un diagnóstico de ingeniería, no una revelación. Deja aire entre las tres cifras y sigue.

---

## 15 · Versión C: separar de dónde sale la energía de cuándo conviene producir  —  1:12

*Bloque: LOS TRES EMS · 5 de 7*

**[PANTALLA]**  Figura `ems_logica_C.png`. dos decisiones numeradas: La batería alimenta al electrolizador · Planificador de orden de mérito a 24 h.

> **Bloque de énfasis:** El planificador solo usa el ORDEN de los precios: es invariante a cualquier transformación monótona de la previsión.

**[DICES]**

> La Versión C separa dos decisiones que la heurística tomaba juntas: de dónde sale la energía del electrolizador y cuándo conviene producir. Cada cambio tiene su interruptor.
>
> El primero son diez líneas. En la rama de déficit, la carga que crea la decisión de producir hidrógeno se ofrece a la batería antes que a la red, mientras el estado de carga esté por encima de una reserva del sesenta por ciento. Ese sesenta sale del contrafactual: con ese piso, el setenta y nueve por ciento de esa importación podía haber salido de la batería. Y no consume ninguna previsión.
>
> El segundo es un planificador: se estima cuánto hidrógeno falta y cuánto excedente gratis va a haber, y se produce si la hora actual está entre las ene más baratas del horizonte.
>
> Lo que hace defendible esta regla es que solo usa el orden de los precios: contar cuántas horas futuras son más baratas es invariante a cualquier transformación monótona de la previsión.

**[ENTREGA — no se dice en voz alta]** La invariancia monótona es el argumento más elegante del trabajo. Dilo despacio.

---

## 16 · Versión C: −13,9 % de coste semanal, en los veinte pares evaluados  —  1:11

*Bloque: LOS TRES EMS · 5 de 7*

**[PANTALLA]**  Figura `fig_res_coste_escenario.png`. Tabla.

> **Bloque de énfasis:** El precio de la mejora: la batería cicla ×2,2 y el hidrógeno no servido pasa de 0,82 a 3,07 kg/semana en el escenario nublado.

> **Nota al pie:** 20 de 20 pares, p por debajo de una diezmilésima · cinco veces el umbral de relevancia fijado antes de simular

**[DICES]**

> Los resultados de la Versión C, sobre siete días y veinte pares escenario-semilla.
>
> Coste total con hidrógeno: menos cincuenta y dos euros con tres por semana, un trece coma nueve por ciento, y gana en los veinte pares, con una p por debajo de una diezmilésima. Cinco veces el umbral de relevancia. Importa un cincuenta y cuatro por ciento menos y la autosuficiencia sube del ochenta y siete coma siete al noventa y cuatro coma tres.
>
> En la figura, cada línea une los dos miembros de un par. Mejora en los cuatro escenarios, y se ahorra más donde más caro compraba el electrolizador.
>
> Y la mejora tiene un precio, que declaro aquí mismo: la batería cicla dos coma dos veces más, con la degradación sin modelar, y el hidrógeno no servido pasa de cero coma ocho a tres coma uno kilogramos por semana en el nublado. Está dentro de la métrica de coste, pero es un dato de operación.

**[ENTREGA — no se dice en voz alta]** El contrapeso va en la misma diapositiva y lo dices tú. No lo dejes para que lo pregunten.

---

## 17 · Y la mejora se puede atribuir pieza a pieza  —  1:14

*Bloque: LOS TRES EMS · 5 de 7*

**[PANTALLA]**  Tres contrastes: − 47,1 € · − 5,1 € · 0,00 €. Línea de leyenda que define C₀, C_p y C.

> **Bloque de énfasis:** El mercado diario publica a las 13:00 el precio del día siguiente: entre 11 y 35 horas del horizonte no hay nada que predecir.

**[DICES]**

> Y como cada mecanismo tiene su interruptor, la mejora se puede atribuir pieza a pieza. Tres tandas, el mismo fichero, los mismos veinte pares. C-cero es solo el primer cambio; C-pe le añade el planificador con el precio ya publicado; y C es la versión completa.
>
> Alimentar el electrolizador desde la batería, solo eso: menos cuarenta y siete euros con uno. El noventa por ciento del ahorro, en veinte de veinte pares.
>
> Añadir la programación de las horas: cinco euros con uno más. Significativa, pero por debajo de mi umbral de relevancia, así que la declaro como tal. El mecanismo no es comprar más barato, sino comprar menos.
>
> Y añadir la red neuronal de precio: cero. Las dos tandas salen idénticas a precisión de máquina en los cuarenta indicadores. La razón es de disponibilidad de información: el mercado diario publica a las trece horas el precio del día siguiente, así que entre once y treinta y cinco horas del horizonte no hay nada que predecir.

**[ENTREGA — no se dice en voz alta]** Sin dramatizar el cero. Es un dato de la atribución, y la atribución es la aportación metodológica del trabajo. SI TE ATACAN EL TÍTULO («habla de LSTM y el 90 % no la usa»): el título dice CUANTIFICAR la mejora de la predicción, y cuantificar incluye que salga pequeña. B sí usa previsión y sí mejora, pero en servicio de hidrógeno, no en coste. Ver pregunta 26.

---

## 18 · Limitaciones  —  0:49

*Bloque: LIMITACIONES · 6 de 7*

**[PANTALLA]**  Tres grupos: Modelo físico · Datos · Alcance.

**[DICES]**

> Las limitaciones, agrupadas por a qué afectan.
>
> Del modelo físico: los tanques usan gas ideal, que a seiscientos bar sobrestima un cuarenta y cinco por ciento la masa, así que la autonomía simulada es optimista; y la pila de combustible no arranca en ninguna simulación, de modo que el modo isla queda sin ejercitar.
>
> De los datos: la irradiancia viene de un reanálisis que no está disponible en tiempo real, y la demanda de hidrógeno se aproxima por analogía con la de vehículos eléctricos.
>
> Y de alcance: el coste no incluye peajes ni cargos, así que las cifras son comparativas; y la referencia es una implementación concreta, no un algoritmo establecido.

**[ENTREGA — no se dice en voz alta]** Rápido y sin dramatizar. Cada una de estas seis es una pregunta que el tribunal ya no necesita hacerte. SI PREGUNTAN POR EL GAS IDEAL: la cifra exacta con tablas NIST es 40 %, no 45 (Z = 1,40 a 600 bar y 15 °C); el 45 sale de interpolar entre dos densidades publicadas. Dala tú. SI PREGUNTAN POR LA PILA: el bloque tiene 120 celdas de 600 cm² y 600 A; su curva de polarización da el máximo en ~156 A y son unos 11 kW, no los 130 del criterio de diseño. No contamina ningún resultado porque la pila no arranca nunca, pero el modo isla no está cubierto ni sobre el papel del modelo.

---

## 19 · Conclusiones  —  1:10

*Bloque: CONCLUSIONES · 7 de 7*

**[PANTALLA]**  Tres conclusiones numeradas. Fondo oscuro.

> **Pie:** Líneas futuras: aislar la previsión solar · objetivo de inventario del tanque previo al día nublado · modelo de degradación de la batería · control predictivo a 48 h, donde el mercado ya no está publicado

**[DICES]**

> La pregunta del trabajo era si una previsión con redes LSTM mejora a un EMS heurístico ya maduro. La respuesta, medida, son estas tres conclusiones.
>
> La primera, sobre las redes: entrené y validé dos modelos contra líneas base no triviales, ninguno las bate por sí solo, y la ponderación con el predictor ingenuo es lo que recupera el resultado. Eso, más la corrección del lazo cerrado, es lo que se despliega.
>
> La segunda, sobre los gestores: tres versiones comparadas sobre la misma instalación. La predictiva mejora la seguridad de suministro de hidrógeno; la final reduce el coste semanal un trece coma nueve por ciento en los veinte casos.
>
> Y la tercera, que da sentido a las otras dos: la cadena de medida permite atribuir esa mejora pieza a pieza. El valor de una previsión depende de en qué decisión se inserte y de qué información no esté ya disponible.
>
> Muchas gracias por su atención. Quedo a su disposición.

**[ENTREGA — no se dice en voz alta]** Levanta la vista en la tercera conclusión. Cierra con firmeza, sin arrastrar el «muchas gracias».

---

## Diapositivas de reserva

**R1 · Una semana completa con la Versión C** — Escenario laborable soleado, semilla 1. Para preguntas sobre comportamiento dinámico, la reserva del 60 % o el ciclado de la batería.

**R2 · Un día del escenario nublado, hora a hora** — Misma semilla, Versión A frente a Versión C. Para explicar el mecanismo de C con un caso concreto.

**R3 · Nivel del tanque de alta en la semana nublada** — Misma semilla, con la zona crítica sombreada. Para la pregunta sobre el servicio de hidrógeno que empeora. SI PREGUNTAN POR EL NIVEL NEGATIVO: es un artefacto declarado del modelo — los integradores de los tanques no saturan a cero, así que el inventario puede bajar de cero y el modelo sirve un hidrógeno que físicamente no tiene. Ese tramo es exactamente lo que mide el indicador de hidrógeno no servido, que se valora a 8 €/kg dentro de la métrica principal. Activar la saturación queda como corrección pendiente del modelo, y está declarado en la memoria.

**R4 · Predicción de precio en los cuatro días de campaña** — LSTM frente a precio real y a la persistencia lag-24. Para preguntas sobre la calidad de la red de precio y sobre la sub-dispersión.

---

## Frases ancla

Si te pierdes, vuelve a una de estas:

1. «El reto pasa a ser de operación: **de dónde sale cada kilovatio**.»
2. «**Solo cambia el script del bloque de decisión**: cualquier diferencia es atribuible al gestor, no al escenario.»
3. «Ninguna de las dos redes bate sola a su línea base. **La ponderación con el naive sí**, y es lo que se despliega.»
4. «Compraba red para el electrolizador **con la batería al 85 %**.»
5. «La regla **solo usa el orden de los precios**: es invariante a cualquier transformación monótona.»

---

## Recortes de emergencia

Si al terminar la 14 vas más de un minuto por encima, aplica en este orden:

1. **Diapositiva 7 (las dos redes)** → di solo «misma arquitectura, dos capas apiladas, parada temprana por validación» y pasa. Ahorra ~35 s.
2. **Diapositiva 3 (la estación)** → di las tres cifras grandes y salta el resto. Ahorra ~25 s.
3. **Diapositiva 18 (limitaciones)** → di solo el grupo de modelo físico y remite los otros dos a la memoria. Ahorra ~25 s.
4. **Diapositiva 5 (datos de demanda)** → salta el párrafo de Caltech. Ahorra ~20 s.

**Nunca recortes** la 11 (metodología), la 14 (diagnóstico) ni la 17 (contribución): son las tres que sostienen todas las cifras.

---

## Antes de entrar

- Lleva la memoria impresa con las tablas de destino de la importación, de C frente a A y de contribución marcadas con pestañas.
- Ten memorizado qué reserva es cuál: R1 panorama, R2 día nublado, R3 tanque, R4 predicción de precio.
- Ensaya en voz alta con cronómetro al menos tres veces. La primera vez te saldrá largo; es normal.
- Las transiciones que conviene ensayar aparte son 9 → 10 (de las redes a la comparación) y 13 → 14 (de la Versión B al diagnóstico).
