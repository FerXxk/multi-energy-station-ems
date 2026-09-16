# Guion de defensa

## Diapositiva 1 · Estrategias de gestión energética para una estación de repostaje multi-energía

Buenos días. Gracias, presidente.

Soy Fernando Román Hidalgo y presento el Trabajo Fin de Grado «Estrategias de gestión energética para una estación de repostaje multi-energía», dirigido por el catedrático Miguel Ángel Ridao Carlini, del Departamento de Ingeniería de Sistemas y Automática.

La charla tiene tres movimientos: el planteamiento y los datos, los dos modelos de predicción, y los tres gestores de energía que comparo.

---

## Diapositiva 2 · El marco ya pone fechas; la infraestructura sigue separada por vector

El transporte es una cuarta parte de las emisiones de gases de efecto invernadero de la Unión, y casi tres cuartas partes de esa fracción son transporte por carretera. Es uno de los focos que el Pacto Verde Europeo tiene que cerrar para dos mil cincuenta.

El marco regulatorio ya pone fechas. La Hoja de Ruta del Hidrógeno española fija entre cien y ciento cincuenta hidrogeneras públicas para dos mil treinta, y sitúa los corredores de repostaje verde como línea prioritaria. El PNIEC fija cinco millones y medio de vehículos eléctricos para esa misma fecha, y el reglamento europeo AFIR convierte el despliegue de recarga en objetivos vinculantes.

El problema es esa fragmentación: cada vector arrastra hoy su propia infraestructura y su propia inversión.

Y ya hay precedentes de integrarlas. Repsol inauguró en enero de dos mil veinticinco la estación de Morro Jable, en Fuerteventura: fotovoltaica, baterías, pila de hidrógeno y recarga eléctrica. Es prácticamente la combinación de componentes de OASIS, a menor escala y sin electrolizador propio.

Con esa integración el reto deja de ser de dimensionamiento y pasa a ser de operación: decidir, en cada instante, de dónde sale cada kilovatio.

---

## Diapositiva 3 · La estación OASIS, modelada en Simulink

Esta es la instalación: la microrred OASIS del departamento, modelada en Simulink sobre la librería Simugrid. Quinientos kilovatios pico de fotovoltaica en marquesina, una batería de un megavatio-hora, un electrolizador PEM de doscientos kilovatios, dos tanques de hidrógeno a distinta presión con su compresor, una pila de combustible y dos cargadores rápidos.

El caso base con el que se ha dimensionado es el panorama actual proyectado a dos mil treinta, el de las cifras de la diapositiva anterior, y no un escenario de penetración masiva.

De todas estas cifras, dos están dimensionadas en este trabajo y no heredadas: la potencia del cargador y su número. Las justifico enseguida con los datos de demanda.

---

## Diapositiva 4 · El EMS decide tres cosas, y es lo único que cambia entre versiones

El gestor de energía es este único bloque de Simulink, y toma tres decisiones.

Cuando sobra sol, cómo repartir el excedente entre cargar la batería y producir hidrógeno. Cuando falta, en qué orden cubrir el déficit: batería, pila, red. Y en todo momento, si conviene producir hidrógeno o reponerlo desde fuera, comparando el coste del kilogramo producido aquí con su precio de reposición.

Todas las versiones que voy a comparar mantienen exactamente esta firma. Cambia el script del bloque de decisión y nada más: el mismo modelo físico, los mismos perfiles de entrada, la misma semilla de demanda.

Y el objetivo del trabajo no es solo mejorar ese gestor, sino poder atribuir la mejora: cuánto viene de la predicción y cuánto de las reglas que la consumen.

---

## Diapositiva 5 · La demanda sale de sesiones reales de carga rápida, no de una hipótesis

El primer bloque de datos sirve para dimensionar, y fija dos parámetros de la instalación.

La fuente es DESL-EPFL, sesiones reales de carga rápida: casi mil novecientas válidas, con una energía media de treinta y dos kilovatios-hora. La contrasto con Caltech, que es carga lenta, para comprobar que son familias distintas.

De ahí salen las dos decisiones. Los cincuenta kilovatios del cargador, que es el estándar europeo de carga rápida en continua y que con la energía media cubren una sesión en unos cuarenta minutos, sin exigir transformador de media tensión. Y que los cargadores sean dos, por teoría de colas sobre la hora punta: con dos, la espera se mantiene acotada.

Dimensiono sobre el panorama actual a propósito: es el escenario del que hay datos reales, y escalar hacia arriba siempre es más fácil que hacia abajo, más aún con una arquitectura modular como esta.

Con esas mismas distribuciones se genera el perfil de demanda de cada simulación. Es estocástico, y eso importará en la comparación.

---

## Diapositiva 6 · Y los datos de entrenamiento, de dos fuentes públicas alineadas hora a hora

El segundo bloque es el de entrenamiento, y son dos fuentes públicas alineadas hora a hora.

Para la irradiancia, NASA POWER, que es un reanálisis meteorológico: de ahí saco, para el punto de Sevilla, casi veinte años de registro horario y las variables que explican la nubosidad. Un detalle que merece la pena: la hora y el día no entran como un número, sino codificados en seno y coseno, para que el modelo sepa que las once y las doce de la noche son contiguas y no los dos extremos de una escala.

Para el precio, las casaciones del mercado diario español a través de ENTSO-E. Además del histórico, entra el contexto que explica su deriva: sobre todo la capacidad fotovoltaica instalada en España, que ha crecido lo suficiente como para cambiar la forma del precio a mediodía.

Y un detalle que importa: el reparto entre entrenamiento y prueba es temporal, nunca aleatorio. Mezclar horas le regalaría al modelo información del futuro.

---

## Diapositiva 7 · Dos redes con la misma arquitectura y parada temprana por validación

Las dos redes comparten arquitectura: dos capas LSTM apiladas, de ciento veintiocho y sesenta y cuatro unidades, con dropout, capa densa y salida de veinticuatro valores, que es el horizonte de un día.

Las dos se entrenan con Adam y paran por criterio de validación: la solar en la época veintiuno de trescientas, la de precio en la veintinueve de doscientas. En pantalla, la curva de RMSE: azul entrenamiento, negro validación. No se separan: no hay sobreajuste.

Una diferencia que sí importa: el modelo solar puede imponer que la irradiancia predicha no sea negativa. El de precio no, porque el precio spot admite negativos, y eso obliga después a un tratamiento distinto.

---

## Diapositiva 8 · El problema: ninguna de las dos redes bate sola a su línea base

Y aquí está el resultado que determina lo que finalmente se despliega.

Las dos redes se evalúan contra líneas base no triviales: la solar contra la persistencia de cielo claro, la de precio contra la persistencia de veinticuatro horas, que es la referencia mínima que exigen las guías del campo. Ninguna la bate en el agregado de veinticuatro horas: la solar queda un ocho coma ocho por ciento por detrás, la de precio un siete coma uno.

El diagnóstico es distinto en cada una. La solar predice irradiancia en bruto y tiene que reconstruir la geometría solar que la línea base recibe gratis: aporta hasta la cuarta hora y pierde después. La de precio ha aprendido el perfil calendario-solar, que es justo lo que la persistencia reproduce sin coste.

Y detecté y corregí una realimentación del buffer de precio que degradaba el error un veintisiete coma siete por ciento. Todas las cifras de esta defensa son posteriores a esa corrección.

---

## Diapositiva 9 · La solución: proyección física y ponderación con el naive

La solución tiene tres partes, y ninguna exige reentrenar.

La primera es física: proyectar la predicción sobre la envolvente de cielo claro, es decir, no permitir que la irradiancia prevista supere a la de cielo despejado. Con eso el error diurno baja alrededor de un seis por ciento.

La segunda es la que da nombre a la diapositiva: ponderar la red con su propia línea base. Una combinación convexa con un peso distinto por cada hora del horizonte, ajustado sobre validación, nunca sobre test. Los dos predictores cometen errores poco correlacionados —la red captura el perfil, la persistencia el nivel del día— y esa es la situación en la que combinar aporta. El resultado: más cinco coma ocho por ciento en solar y más seis coma seis en precio.

Y la tercera es la corrección del lazo cerrado, realimentando con el precio real de la hora ya transcurrida, que sigue siendo estrictamente causal.

---

## Diapositiva 10 · Cuatro escenarios que cruzan recurso solar y régimen de precio

Para comparar los gestores hacen falta escenarios, y no los elegí al azar: cruzan las dos variables que gobiernan la decisión del EMS, recurso solar y régimen de precio.

Un laborable soleado con precio plano. Un laborable nublado, con índice de claridad de cero coma treinta y seis y punta de ciento noventa y cuatro euros el megavatio-hora, que es el caso sin excedente. Un fin de semana soleado con precio casi nulo a mediodía. Y el día de mayor diferencial de dos mil veinticinco, de veinticuatro a doscientos cincuenta y dos euros.

Y cada uno se repite con varias semillas del generador de demanda, porque la demanda es estocástica.

---

## Diapositiva 11 · Cuatro piezas sostienen todas las cifras que vienen a continuación

Antes de las cifras, las cuatro piezas que las sostienen.

La primera es la comparación pareada, que es lo que ven en el esquema: la semilla ene genera el mismo perfil de demanda en todas las versiones, así que la diferencia se calcula par a par. El ruido de la demanda se cancela en la resta y el contraste gana potencia. Veinte pares: cuatro escenarios por cinco semillas.

La segunda es el test de Wilcoxon, de rangos con signo. Empecé con un t-test y lo abandoné: tres semillas del escenario nublado dominaban la media, con medias hasta veinte veces la mediana. El contraste describía esas tres tiradas, no a la población.

La tercera es un umbral de relevancia económica. Medí la dispersión del coste de la propia referencia entre grupos de semillas: nueve euros con treinta y tres por semana. Una diferencia significativa por debajo de eso la declaro operativamente nula, y lo fijé antes de simular.

Y la cuarta es el oráculo: repetir una tanda con la previsión perfecta. No es desplegable, es una cota superior. Si con error cero una estrategia no gana, ninguna mejora de la previsión va a hacer que gane.

---

## Diapositiva 12 · Versión A: la referencia ya es una heurística madura

El primer gestor, la Versión A, es la referencia: viene del TFM previo del grupo y lo he portado a esta arquitectura.

Quiero insistir en lo que ya trae, porque condiciona cómo se lee todo lo demás. Reparto dinámico de potencia entre batería y electrolizador por tramos de estado de carga. Tiempo mínimo de funcionamiento de dos horas con histéresis y anti-rebote, para que los equipos electroquímicos no conmuten cada pocos minutos. La gestión de los dos niveles de presión con su compresor. Y una decisión económica de producir hidrógeno frente a reponerlo fuera.

Es decir, ya tiene los mecanismos que distinguen a un gestor de reglas maduro de un reparto por prioridades. Lo que no tiene es ninguna predicción.

---

## Diapositiva 13 · Versión B: la previsión mejora sistemáticamente el servicio de hidrógeno

La Versión B añade las dos previsiones donde la heurística ya decidía: la solar desplaza el reparto cuando anticipa que va a caer el excedente, y la de precio gobierna un arbitraje de batería.

Y tiene una victoria clara: el servicio de hidrógeno. Mantiene el tanque de alta más lleno y pasa menos tiempo en nivel crítico, en treinta y nueve de cuarenta pares. Y escala con la calidad de la previsión: con oráculo se multiplica por diez. El mecanismo funciona; lo que limita es la previsión, no el diseño.

En coste empata: trece céntimos sobre un recibo diario de unos cuarenta y cinco euros, y tampoco gana con previsión perfecta.

De ahí sale la regla de diseño que aplico después: una primera implementación que traducía «el precio va a subir» en una acción de magnitud fija empeoraba el coste, y más cuanto mejor era la previsión. La acción tiene que estar condicionada y su magnitud salir del margen económico.

---

## Diapositiva 14 · La batería estaba al 85 % mientras el electrolizador compraba red

Al descomponer la importación de la Versión A por destinos aparece esto, y es lo que motiva el tercer gestor. Fíjense solo en la primera barra: las otras dos son la Versión C, que veremos enseguida.

De los mil trescientos veintiún kilovatios-hora que la referencia compra a la red en una semana, mil seis —el setenta y seis por ciento— van al electrolizador, a ciento veintiuno con cinco euros el megavatio-hora. Los vehículos son el veintiuno por ciento.

Y en los instantes exactos en que compra esa energía, la batería está al ochenta y cinco por ciento de carga de media, y nunca baja del sesenta y nueve.

El motivo está en el orden del código: en la rama de déficit la batería cubre los vehículos y, en un paso posterior, la decisión económica enciende el electrolizador; esa carga nueva no se le vuelve a ofrecer a la batería, así que la absorbe la red. Toda la información necesaria ya estaba en las entradas.

---

## Diapositiva 15 · Versión C: separar de dónde sale la energía de cuándo conviene producir

La Versión C separa dos decisiones que la heurística tomaba juntas: de dónde sale la energía del electrolizador y cuándo conviene producir. Cada cambio tiene su interruptor.

El primero son diez líneas. En la rama de déficit, la carga que crea la decisión de producir hidrógeno se ofrece a la batería antes que a la red, mientras el estado de carga esté por encima de una reserva del sesenta por ciento. Ese sesenta sale del contrafactual: con ese piso, el setenta y nueve por ciento de esa importación podía haber salido de la batería. Y no consume ninguna previsión.

El segundo es un planificador: se estima cuánto hidrógeno falta y cuánto excedente gratis va a haber, y se produce si la hora actual está entre las ene más baratas del horizonte.

Lo que hace defendible esta regla es que solo usa el orden de los precios: contar cuántas horas futuras son más baratas es invariante a cualquier transformación monótona de la previsión.

---

## Diapositiva 16 · Versión C: −13,9 % de coste semanal, en los veinte pares evaluados

Los resultados de la Versión C, sobre siete días y veinte pares escenario-semilla.

Coste total con hidrógeno: menos cincuenta y dos euros con tres por semana, un trece coma nueve por ciento, y gana en los veinte pares, con una p por debajo de una diezmilésima. Cinco veces el umbral de relevancia. Importa un cincuenta y cuatro por ciento menos y la autosuficiencia sube del ochenta y siete coma siete al noventa y cuatro coma tres.

En la figura, cada línea une los dos miembros de un par. Mejora en los cuatro escenarios, y se ahorra más donde más caro compraba el electrolizador.

Y la mejora tiene un precio, que declaro aquí mismo: la batería cicla dos coma dos veces más, con la degradación sin modelar, y el hidrógeno no servido pasa de cero coma ocho a tres coma uno kilogramos por semana en el nublado. Está dentro de la métrica de coste, pero es un dato de operación.

---

## Diapositiva 17 · Y la mejora se puede atribuir pieza a pieza

Y como cada mecanismo tiene su interruptor, la mejora se puede atribuir pieza a pieza. Tres tandas, el mismo fichero, los mismos veinte pares. C-cero es solo el primer cambio; C-pe le añade el planificador con el precio ya publicado; y C es la versión completa.

Alimentar el electrolizador desde la batería, solo eso: menos cuarenta y siete euros con uno. El noventa por ciento del ahorro, en veinte de veinte pares.

Añadir la programación de las horas: cinco euros con uno más. Significativa, pero por debajo de mi umbral de relevancia, así que la declaro como tal. El mecanismo no es comprar más barato, sino comprar menos.

Y añadir la red neuronal de precio: cero. Las dos tandas salen idénticas a precisión de máquina en los cuarenta indicadores. La razón es de disponibilidad de información: el mercado diario publica a las trece horas el precio del día siguiente, así que entre once y treinta y cinco horas del horizonte no hay nada que predecir.

---

## Diapositiva 18 · Limitaciones

Las limitaciones, agrupadas por a qué afectan.

Del modelo físico: los tanques usan gas ideal, que a seiscientos bar sobrestima un cuarenta y cinco por ciento la masa, así que la autonomía simulada es optimista; y la pila de combustible no arranca en ninguna simulación, de modo que el modo isla queda sin ejercitar.

De los datos: la irradiancia viene de un reanálisis que no está disponible en tiempo real, y la demanda de hidrógeno se aproxima por analogía con la de vehículos eléctricos.

Y de alcance: el coste no incluye peajes ni cargos, así que las cifras son comparativas; y la referencia es una implementación concreta, no un algoritmo establecido.

---

## Diapositiva 19 · Conclusiones

La pregunta del trabajo era si una previsión con redes LSTM mejora a un EMS heurístico ya maduro. La respuesta, medida, son estas tres conclusiones.

La primera, sobre las redes: entrené y validé dos modelos contra líneas base no triviales, ninguno las bate por sí solo, y la ponderación con el predictor ingenuo es lo que recupera el resultado. Eso, más la corrección del lazo cerrado, es lo que se despliega.

La segunda, sobre los gestores: tres versiones comparadas sobre la misma instalación. La predictiva mejora la seguridad de suministro de hidrógeno; la final reduce el coste semanal un trece coma nueve por ciento en los veinte casos.

Y la tercera, que da sentido a las otras dos: la cadena de medida permite atribuir esa mejora pieza a pieza. El valor de una previsión depende de en qué decisión se inserte y de qué información no esté ya disponible.

Muchas gracias por su atención. Quedo a su disposición.

---

## Diapositivas de reserva

### R1 · Una semana completa con la Versión C

Para preguntas sobre comportamiento dinámico, la reserva del 60 % o el ciclado de la batería.

### R2 · Un día del escenario nublado, hora a hora

Para explicar el mecanismo de C con un caso concreto.

### R3 · Nivel del tanque de alta en la semana nublada

Para la pregunta sobre el servicio de hidrógeno que empeora. SI PREGUNTAN POR EL NIVEL NEGATIVO: es un artefacto declarado del modelo — los integradores de los tanques no saturan a cero, así que el inventario puede bajar de cero y el modelo sirve un hidrógeno que físicamente no tiene. Ese tramo es exactamente lo que mide el indicador de hidrógeno no servido, que se valora a 8 €/kg dentro de la métrica principal. Activar la saturación queda como corrección pendiente del modelo, y está declarado en la memoria.

### R4 · Predicción de precio en los cuatro días de campaña

Para preguntas sobre la calidad de la red de precio y sobre la sub-dispersión.

