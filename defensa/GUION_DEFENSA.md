# Guion de defensa

## Diapositiva 1 · Estrategias de gestión energética para una estación de repostaje multi-energía

Buenos días. Gracias, presidente.

Soy Fernando Román Hidalgo y presento el Trabajo Fin de Grado «Estrategias de gestión energética para una estación de repostaje multi-energía», dirigido por el catedrático Miguel Ángel Ridao Carlini, del Departamento de Ingeniería de Sistemas y Automática.

La charla tiene tres movimientos: el planteamiento y los datos, los dos modelos de predicción, y los tres gestores de energía que comparo.

---

## Diapositiva 2 · El marco ya pone fechas; la infraestructura sigue separada por vector

El transporte es una cuarta parte de las emisiones de la Unión, y casi tres cuartas partes de esa fracción son carretera. Es uno de los focos que el Pacto Verde Europeo tiene que cerrar.

El marco ya pone fechas. La Hoja de Ruta del Hidrógeno fija entre cien y ciento cincuenta hidrogeneras públicas para dos mil treinta, y sitúa los corredores de repostaje verde como prioridad. El PNIEC fija cinco millones y medio de vehículos eléctricos en España para esa misma fecha. Y el reglamento europeo AFIR convierte el despliegue de recarga en objetivos vinculantes.

El problema es esa fragmentación: cada vector arrastra hoy su propia infraestructura y su propia inversión.

Y ya hay precedentes: Repsol inauguró en dos mil veinticinco la estación de Morro Jable, en Fuerteventura, que es casi la combinación de componentes de OASIS a menor escala y sin electrolizador propio.

Con esa integración el reto deja de ser de dimensionamiento y pasa a ser de operación: decidir, en cada instante, de dónde sale cada kilovatio.

---

## Diapositiva 3 · La estación OASIS, modelada en Simulink

Esta es la instalación: la microrred OASIS del departamento, modelada en Simulink sobre la librería Simugrid. Tienen en pantalla los seis componentes con sus tamaños; el orden de magnitud es medio megavatio de fotovoltaica, un megavatio-hora de batería y doscientos kilovatios de electrolizador.

El modelo de Simulink viene del trabajo previo del grupo, y lo primero que hice fue ajustar su parametrización a la escala de una electrolinera, para que la estación no quedara sobredimensionada. Y hay dos tamaños que sí salen de la demanda medida: los cargadores, cincuenta kilovatios y dos unidades, y la pila de combustible, ciento treinta kilovatios, que es el pico de los dos cargadores más el compresor y un margen del diez por ciento. En dos diapositivas están los datos de demanda que lo sostienen.

---

## Diapositiva 4 · El EMS decide tres cosas, y es lo único que cambia entre versiones

El gestor de energía —el EMS, por sus siglas en inglés— es este único bloque de Simulink, y toma tres decisiones.

Cuando sobra sol, cómo repartir el excedente entre cargar la batería y producir hidrógeno. Cuando falta, en qué orden cubrir el déficit: batería, pila, red. Y en todo momento, si conviene producir hidrógeno o reponerlo desde fuera, comparando el coste del kilogramo producido aquí con su precio de reposición.

Todas las versiones que voy a comparar mantienen exactamente esta firma. Cambia el script del bloque de decisión y nada más: el mismo modelo físico, los mismos perfiles de entrada, la misma semilla de demanda.

Y el objetivo del trabajo no es solo mejorar ese gestor, sino poder atribuir la mejora: cuánto viene de la predicción y cuánto de las reglas que la consumen.

---

## Diapositiva 5 · La demanda sale de sesiones reales de carga rápida, no de una hipótesis

El primer bloque de datos sirve para dimensionar, y fija dos parámetros de la instalación.

La fuente es DESL-EPFL, casi mil novecientas sesiones reales de carga rápida con una energía media de treinta y dos kilovatios-hora, contrastadas con las de Caltech para comprobar que carga rápida y carga lenta son familias distintas.

De ahí salen las dos cifras del dimensionado. Cincuenta kilovatios cubren una sesión media en unos cuarenta minutos sin exigir transformador de media tensión. Y el número de cargadores sale de la cola en hora punta: con uno la espera media se va a media hora, con dos baja a dos minutos, y el tercero ya no compensa.

Dimensiono sobre el panorama actual a propósito: es el escenario del que hay datos reales, y escalar hacia arriba es más fácil que hacia abajo, más con una arquitectura modular como esta.

Con esas distribuciones se genera el perfil de demanda de cada simulación. Es estocástico, y eso importará en la comparación.

---

## Diapositiva 6 · Y los datos de entrenamiento, de dos fuentes públicas alineadas hora a hora

El segundo bloque es el de entrenamiento, y son dos fuentes públicas alineadas hora a hora.

Para la irradiancia, NASA POWER, que es un reanálisis meteorológico: de ahí saco, para el punto de Sevilla, casi veinte años de registro horario y las variables que explican la nubosidad. Un detalle que merece la pena: la hora y el día no entran como un número, sino codificados en seno y coseno, para que el modelo sepa que las once de la noche y la medianoche —que en la escala numérica son el veintitrés y el cero— están pegadas, y no en los extremos opuestos.

Para el precio, las casaciones del mercado diario español a través de ENTSO-E. Además del histórico, entra el contexto que explica su deriva: sobre todo la capacidad fotovoltaica instalada en España, que ha crecido lo suficiente como para cambiar la forma del precio a mediodía.

Y un detalle que importa: el reparto entre entrenamiento y prueba es temporal, nunca aleatorio. Mezclar horas le regalaría al modelo información del futuro.

---

## Diapositiva 7 · Dos redes con la misma arquitectura y parada temprana por validación

Las dos redes comparten arquitectura: dos capas LSTM apiladas —redes recurrentes con memoria larga— y una salida de veinticuatro valores, que es el horizonte de un día. Se entrenan con Adam y paran por criterio de validación. En pantalla, la curva de RMSE: azul entrenamiento, negro validación. No se separan: no hay sobreajuste.

Entreno con RMSE, el error cuadrático medio, porque al elevar al cuadrado penaliza mucho más un fallo grande que varios pequeños, y aquí lo que rompe una decisión es el fallo grande: no ver una punta de precio o una caída de sol. Para comparar modelos uso después el error absoluto medio, que está en las unidades de la variable y no lo dominan cuatro horas atípicas.

Una diferencia que importa: el modelo solar puede imponer que la irradiancia predicha no sea negativa. El de precio no, porque el precio admite negativos.

---

## Diapositiva 8 · El problema: ninguna de las dos redes bate sola a su línea base

Y aquí está el problema, el resultado que reorientó este capítulo.

Cada red se evalúa contra su línea base: la solar contra la persistencia de cielo claro, la de precio contra la de veinticuatro horas. Y no es una vara de medir cualquiera: en estas dos series el día de hoy se parece muchísimo al de ayer, así que «lo mismo que ayer» acierta la mayor parte del tiempo. Es una referencia dura.

Ninguna de las dos la bate: la solar queda un ocho coma ocho por ciento por detrás, la de precio un siete coma uno.

Pero el motivo de esa derrota es lo que abre la solución. Una red recurrente está pensada para anticipar cambios, no para repetir lo de ayer. En las horas en que no pasa nada, que son la mayoría, la persistencia es imbatible; en las que sí pasa algo, que son las que deciden, aporta la red. Lo ven en el panel de abajo a la izquierda: el día nublado la red da cuatrocientos veinte y lo real fueron doscientos sesenta. Aciertan en sitios distintos, así que la salida no es elegir una, sino combinarlas.

---

## Diapositiva 9 · La solución: proyección física y ponderación con el naive

La solución tiene tres partes, y ninguna exige reentrenar.

La primera es física: acotar la predicción a la envolvente de cielo claro, no dejar que la irradiancia prevista supere la de un día despejado. Con eso el error medio diurno baja de cincuenta y nueve a cincuenta y seis vatios-hora por metro cuadrado.

La segunda da nombre a la diapositiva: ponderar la red con su propia línea base, una combinación convexa con un peso distinto por cada hora del horizonte, ajustado en validación y nunca en test.

La tercera es la corrección del lazo cerrado, realimentando con el precio real de la hora ya transcurrida, que sigue siendo causal.

Y el resultado es que la señal combinada sí bate a su línea base: un cinco coma ocho por ciento mejor en solar y un seis coma seis en precio. Conviene decir sobre qué se mide esa mejora: no sobre no predecir nada, sino sobre una referencia que ya acierta la mayor parte del tiempo.

---

## Diapositiva 10 · Cuatro escenarios que cruzan recurso solar y régimen de precio

Para comparar los gestores hacen falta escenarios, y no los elegí al azar: cruzan las dos variables que gobiernan la decisión del EMS, recurso solar y régimen de precio.

Un laborable soleado con precio plano. Un laborable nublado, que es el caso sin excedente, con punta de precio por la tarde. Un fin de semana soleado, con precio casi nulo a mediodía. Y el de mayor diferencial de precio de todo dos mil veinticinco.

Cada escenario no se simula como un día suelto, sino como la semana real de siete días que arranca en esa fecha, con su precio y su irradiancia de calendario. Y cada uno se repite con cinco semillas del generador de demanda.

---

## Diapositiva 11 · Cuatro piezas sostienen todas las cifras que vienen a continuación

Antes de las cifras, las cuatro piezas que las sostienen.

La primera es comparar en pareja, que es el esquema: la misma semilla genera el mismo perfil de demanda para todas las versiones, así que comparo dos versiones sobre la misma semana y no dos promedios. El azar de la demanda se va en la resta. Veinte pares: cuatro escenarios por cinco semillas.

La segunda es el test de Wilcoxon: en vez de mirar si la media mejora, mira si las diferencias caen siempre del mismo lado. Lo elegí porque unas pocas semanas nubladas muy caras bastaban para arrastrar la media.

La tercera es un umbral de relevancia, y es el que me pongo en contra: por debajo de nueve euros a la semana, que es lo que varía la propia referencia solo por cambiar de semillas, lo doy por empate. Fijado antes de simular.

Y la cuarta es el oráculo: repetir la tanda con la previsión perfecta. Es un techo. Si con previsión perfecta una idea no gana, mejorar la predicción no la va a salvar.

---

## Diapositiva 12 · Versión A: la referencia ya es una heurística madura

El primer gestor, la Versión A, es la referencia: viene del TFM previo del grupo y lo he portado a esta arquitectura.

Quiero insistir en lo que ya trae, porque condiciona cómo se lee todo lo demás. Tienen las cuatro en pantalla; me detengo en dos. El tiempo mínimo de funcionamiento de dos horas con histéresis, para que los equipos electroquímicos no conmuten cada pocos minutos. Y una decisión económica de producir, que compara el coste del kilogramo producido aquí con lo que costaría reponerlo fuera.

Es decir, ya tiene los mecanismos que distinguen a un gestor de reglas maduro de un reparto por prioridades. Lo que no tiene es ninguna predicción.

---

## Diapositiva 13 · Versión B: la previsión mejora sistemáticamente el servicio de hidrógeno

La Versión B es la misma heurística con las dos previsiones metidas dentro. No cambia la arquitectura: cambia lo que mira la regla en el momento de decidir.

La previsión solar entra en el reparto del excedente: antes dependía solo del estado de carga del instante; ahora, si se anticipa que el excedente va a caer, el reparto se desplaza hacia la batería antes de que caiga. Y la de precio gobierna un arbitraje de batería.

B se comparó sobre veinticuatro horas con diez semillas, cuarenta pares, porque ahí lo que importa es la dinámica eléctrica. Y tiene una victoria y un empate. La victoria es el servicio de hidrógeno —el nivel medio del tanque de alta y el tiempo que pasa por debajo del nivel crítico—: mejora en treinta y nueve de los cuarenta pares. La mejora es pequeña, pero escala con la calidad de la previsión: con el oráculo se multiplica por diez. Lo que limita es la predicción, no el diseño.

El empate es el coste, y de ahí sale la regla de diseño que aplico después: la primera versión del arbitraje traducía «el precio va a subir» en una acción de tamaño fijo, y empeoraba el coste, más cuanto mejor era la previsión. Una acción disparada por una previsión tiene que salir del margen económico disponible, no de una constante.

---

## Diapositiva 14 · La batería estaba al 85 % mientras el electrolizador compraba red

B no movió el coste, así que la pregunta pasó a ser dónde se va ese dinero. Volví a la Versión A y descompuse su importación de red por destinos, y apareció esto.

De los mil trescientos veintiún kilovatios-hora que compra a la red en una semana, el setenta y seis por ciento van al electrolizador, a ciento veintiuno con cinco euros el megavatio-hora. Y en los instantes exactos en que los compra, la batería está al ochenta y cinco por ciento de media.

Pongan eso junto al otro lado del balance: en esa misma semana la estación exporta catorce mil kilovatios-hora a treinta y nueve euros. Vende diez veces más energía de la que compra, y la compra tres veces más cara de lo que la vende. Está pasando la misma energía dos veces por el contador, y perdiendo en los dos sentidos.

El motivo está en el orden del código: la batería cubre primero los vehículos y, en un paso posterior, la decisión económica enciende el electrolizador; esa carga nueva no se le vuelve a ofrecer, así que la absorbe la red.

---

## Diapositiva 15 · Versión C: separar de dónde sale la energía de cuándo conviene producir

La Versión C separa dos decisiones que la heurística tomaba juntas: de dónde sale la energía del electrolizador y cuándo conviene producir. En pantalla, los cuatro pasos de la lógica común, con los dos que sustituyo en ámbar.

El primero son diez líneas: la carga que crea la decisión de producir hidrógeno se le ofrece a la batería antes que a la red, mientras el estado de carga esté por encima del sesenta por ciento, que sale del contrafactual del diagnóstico anterior.

El segundo es un planificador: estima cuánto hidrógeno falta y cuánto excedente gratis viene, y de ahí salen las horas de electrolizador que hay que comprar a la red, que se colocan en las más baratas del horizonte.

Y conviene precisar de dónde sale ese precio: el mercado diario publica sobre la una de la tarde las veinticuatro horas del día siguiente, así que la parte ya publicada se usa tal cual y solo se predice el tramo que falta.

Y lo que hace defendible la regla es que solo usa el orden: la decisión es «estoy entre las ene más baratas, sí o no», y eso no cambia si la previsión falla en el nivel mientras acierte en el orden.

---

## Diapositiva 16 · Versión C: −13,9 % de coste semanal, en los veinte pares evaluados

Los resultados de la Versión C, sobre siete días y veinte pares escenario-semilla.

La figura es la diferencia de coste frente a la A, escenario por escenario; la banda gris es el umbral de relevancia. B cae dentro de la banda en los cuatro: en coste empata. C se sale por la izquierda en los cuatro, y por bastante.

En la tabla, tres métricas. El coste baja unos cincuenta y dos euros por semana: casi un catorce por ciento, y gana en los veinte pares. La importación de red cae a la mitad, un cincuenta y cuatro por ciento. Y la autosuficiencia sube del ochenta y ocho al noventa y cuatro por ciento.

El orden entre escenarios no lo fija el excedente, sino el precio al que compraba el electrolizador: se ahorra más donde más caro compraba.

Y la mejora tiene un precio, que declaro yo. Los tres kilos de hidrógeno que hay que reponer desde fuera en el nublado sí están valorados dentro de esos cincuenta y dos euros. El ciclado no: la batería mueve dos coma dos veces más energía y la degradación no está modelada. Es la principal reserva que le pongo yo mismo al resultado.

---

## Diapositiva 17 · Y la mejora se puede atribuir pieza a pieza

Como cada mecanismo tiene su interruptor, la mejora se atribuye pieza a pieza. Tres tandas, el mismo fichero, los mismos veinte pares: la versión con solo el primer cambio, la que le añade el planificador con el precio ya publicado, y la completa.

Alimentar el electrolizador desde la batería, solo eso: menos cuarenta y siete euros con uno. El noventa por ciento del ahorro, en veinte de veinte pares.

Añadir el planificador: cinco euros más. Y es aquí donde entra la previsión solar, porque el planificador la usa para estimar cuánto excedente gratis viene: su aportación está dentro de esta cifra y no se puede aislar de ella. Wilcoxon la da por significativa, pero cae por debajo de mi umbral de nueve, así que la declaro empate. El mecanismo no es comprar más barato, sino comprar menos.

Y añadir la red neuronal de precio: cero. Las dos tandas salen idénticas a precisión de máquina en los cuarenta indicadores. La razón es de disponibilidad de información: el mercado publica a las trece horas el día siguiente, así que el planificador ve entre once y treinta y cinco horas ya publicadas. Solo hay que predecir lo que quede del horizonte, y en la campaña ese tramo no cambió ni una de las decisiones.

---

## Diapositiva 18 · Limitaciones

Las limitaciones, agrupadas según a qué afectan.

Del modelo físico: algunos bloques asumen simplificaciones, la más relevante la ecuación de gas ideal en los tanques, que hace caber más hidrógeno del que cabría de verdad. Y la pila no llega a arrancar, que no es un fallo del gestor sino la decisión correcta: recuperar electricidad del hidrógeno es el camino más caro y con más pérdidas de la estación. Tiene sentido en modo isla, y ese modo no lo ejercito.

De los datos: la irradiancia sale de un reanálisis, que es lo que hace falta para entrenar pero no es la señal que tendría la estación en tiempo real; cambiarla por una previsión operativa no toca el modelo, solo la entrada. Y la demanda de hidrógeno se construye por analogía con la eléctrica porque aún no hay flota de la que medirla; es la misma para las tres versiones, así que no favorece a ninguna.

Y de alcance: el coste no incluye peajes ni cargos, así que las cifras son comparativas. Y los umbrales están ajustados a esta instalación: llevar el algoritmo a otra exige recalibrarlos, no solo copiarlo.

---

## Diapositiva 19 · Conclusiones

La pregunta del trabajo era si una previsión con redes LSTM mejora a un EMS heurístico ya maduro. La respuesta, medida, son estas tres conclusiones.

Dos modelos entrenados, validados y corregidos, cuya señal combinada supera a la línea base en solar y en precio, y es la que consume el simulador.

Tres gestores sobre la misma instalación: la predictiva mejora el servicio de hidrógeno, y la final reduce el coste semanal casi un catorce por ciento en los veinte casos.

Y la tercera, que da sentido a las otras dos: la cadena de medida permite atribuir la mejora pieza a pieza. El valor de una previsión depende de en qué decisión se inserte y de qué información no esté ya disponible.

Cuatro líneas futuras. Aislar la previsión solar, para medir por separado lo que hoy va sumado dentro de la programación. Dar al tanque un nivel objetivo antes de un día nublado previsto, que corregiría el único indicador que C empeora. Modelar la degradación de la batería. Y ampliar el horizonte a cuarenta y ocho horas con control predictivo: es el único tramo donde el mercado ya no está publicado.

Muchas gracias por su atención.

---

## Diapositivas de reserva

### R1 · Una semana completa con la Versión C

Para preguntas sobre comportamiento dinámico, la reserva del 60 % o el ciclado de la batería.

### R2 · Un día del escenario nublado, hora a hora

Para explicar el mecanismo de C con un caso concreto.

### R3 · Nivel del tanque de alta en la semana nublada

Para la pregunta sobre el servicio de hidrógeno que empeora. C pasa más tiempo por debajo del nivel crítico que A: es la contrapartida del ahorro y está valorada dentro de la métrica de coste. SI PREGUNTAN POR EL TRAMO NEGATIVO: es un artefacto declarado del modelo — los integradores de los tanques no saturan a cero, así que el inventario puede bajar de cero. Ese tramo es exactamente el hidrógeno que hay que comprar fuera, y se valora a 8 €/kg dentro de la métrica principal. Activar la saturación queda como corrección pendiente, y está declarado en la memoria.

