# Guion de defensa

## Diapositiva 1 · Estrategias de gestión energética para una estación de repostaje multi-energía

Buenos días. Gracias, presidente.

Soy Fernando Román Hidalgo y presento el Trabajo Fin de Grado «Estrategias de gestión energética para una estación de repostaje multi-energía», dirigido por el catedrático Miguel Ángel Ridao Carlini, del Departamento de Ingeniería de Sistemas y Automática.

La charla tiene tres movimientos: el planteamiento y los datos, los dos modelos de predicción, y los tres gestores de energía que comparo.

---

## Diapositiva 2 · El marco ya pone fechas; la infraestructura sigue separada por vector

El transporte es una cuarta parte de las emisiones de la Unión, y casi tres cuartas partes de esa fracción son carretera. Es uno de los focos que el Pacto Verde Europeo tiene que cerrar.

El marco ya pone fechas. La Hoja de Ruta del Hidrógeno española fija entre cien y ciento cincuenta hidrogeneras públicas para dos mil treinta y sitúa los corredores de repostaje verde como prioridad; el PNIEC fija cinco millones y medio de vehículos eléctricos para esa fecha; y el reglamento europeo AFIR convierte el despliegue de recarga en objetivos vinculantes.

El problema es esa fragmentación: cada vector arrastra hoy su propia infraestructura y su propia inversión.

Y ya hay precedentes. Repsol inauguró en dos mil veinticinco la estación de Morro Jable, en Fuerteventura: fotovoltaica, baterías, pila de hidrógeno y recarga eléctrica. Es casi la combinación de OASIS, a menor escala y sin electrolizador propio.

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

La fuente es DESL-EPFL, casi mil novecientas sesiones reales de carga rápida, con una energía media de treinta y dos kilovatios-hora. La contrasto con Caltech, que es carga lenta, para comprobar que son familias distintas.

De ahí salen las dos decisiones. Los cincuenta kilovatios del cargador, que es el estándar europeo de carga rápida en continua y que con la energía media cubren una sesión en unos cuarenta minutos, sin exigir transformador de media tensión. Y que los cargadores sean dos, por teoría de colas sobre la hora punta: con dos, la espera se mantiene acotada.

Dimensiono sobre el panorama actual a propósito: es el escenario del que hay datos reales, y escalar hacia arriba siempre es más fácil que hacia abajo, más aún con una arquitectura modular como esta.

Con esas distribuciones se genera el perfil de demanda de cada simulación. Es estocástico, y eso importará en la comparación.

---

## Diapositiva 6 · Y los datos de entrenamiento, de dos fuentes públicas alineadas hora a hora

El segundo bloque es el de entrenamiento, y son dos fuentes públicas alineadas hora a hora.

Para la irradiancia, NASA POWER, que es un reanálisis meteorológico: de ahí saco, para el punto de Sevilla, casi veinte años de registro horario y las variables que explican la nubosidad. Un detalle que merece la pena: la hora y el día no entran como un número, sino codificados en seno y coseno, para que el modelo sepa que las once y las doce de la noche son contiguas y no los dos extremos de una escala.

Para el precio, las casaciones del mercado diario español a través de ENTSO-E. Además del histórico, entra el contexto que explica su deriva: sobre todo la capacidad fotovoltaica instalada en España, que ha crecido lo suficiente como para cambiar la forma del precio a mediodía.

Y un detalle que importa: el reparto entre entrenamiento y prueba es temporal, nunca aleatorio. Mezclar horas le regalaría al modelo información del futuro.

---

## Diapositiva 7 · Dos redes con la misma arquitectura y parada temprana por validación

Las dos redes comparten arquitectura: dos capas LSTM apiladas, de ciento veintiocho y sesenta y cuatro unidades, con dropout, capa densa y salida de veinticuatro valores, el horizonte de un día. Se entrenan con Adam y paran por criterio de validación. En pantalla, la curva de RMSE: azul entrenamiento, negro validación. No se separan: no hay sobreajuste.

Entreno con RMSE, el error cuadrático medio, porque al elevar al cuadrado penaliza mucho más un fallo grande que varios pequeños, y aquí lo que rompe una decisión es el fallo grande: no ver una punta de precio o una caída de sol. Para comparar modelos uso después el error absoluto medio, que está en las unidades de la variable y no lo dominan cuatro horas atípicas.

Una diferencia que importa: el modelo solar puede imponer que la irradiancia predicha no sea negativa. El de precio no, porque el precio admite negativos.

---

## Diapositiva 8 · El problema: ninguna de las dos redes bate sola a su línea base

Y aquí está el problema, el resultado que reorientó este capítulo.

Cada red se evalúa contra su línea base: la solar contra la persistencia de cielo claro, la de precio contra la de veinticuatro horas. Y no es una vara de medir cualquiera: en estas dos series el día de hoy se parece muchísimo al de ayer, así que «lo mismo que ayer» acierta la mayor parte del tiempo. Es una referencia dura.

Ninguna de las dos la bate: la solar queda un ocho coma ocho por ciento por detrás, la de precio un siete coma uno.

Pero el motivo de esa derrota es lo que abre la solución. Una red recurrente está pensada para anticipar cambios, no para repetir lo de ayer. En las horas en que no cambia nada, que son la mayoría, la persistencia es imbatible; en las que sí cambia, que son las que deciden, aporta la red. Aciertan en sitios distintos: la salida no es elegir una, sino combinarlas.

---

## Diapositiva 9 · La solución: proyección física y ponderación con el naive

La solución tiene tres partes, y ninguna exige reentrenar.

La primera es física: acotar la predicción a la envolvente de cielo claro, no dejar que la irradiancia prevista supere la de un día despejado. Con eso el error absoluto medio diurno —cuánto me equivoco de media cada hora, en las unidades de la variable— baja de cincuenta y nueve a cincuenta y seis vatios-hora por metro cuadrado.

La segunda da nombre a la diapositiva: ponderar la red con su propia línea base, una combinación convexa con un peso distinto por cada hora del horizonte, ajustado en validación y nunca en test.

La tercera es la corrección del lazo cerrado, realimentando con el precio real de la hora ya transcurrida, que sigue siendo causal.

El resultado son esas dos cifras, y conviene decir sobre qué se miden: no sobre no predecir nada, sino sobre la persistencia, que ya acierta la mayor parte del tiempo.

---

## Diapositiva 10 · Cuatro escenarios que cruzan recurso solar y régimen de precio

Para comparar los gestores hacen falta escenarios, y no los elegí al azar: cruzan las dos variables que gobiernan la decisión del EMS, recurso solar y régimen de precio.

Un laborable soleado con precio plano. Un laborable nublado, con índice de claridad de cero coma treinta y seis y punta de ciento noventa y cuatro euros el megavatio-hora, que es el caso sin excedente. Un fin de semana soleado con precio casi nulo a mediodía. Y el día de mayor diferencial de dos mil veinticinco, de veinticuatro a doscientos cincuenta y dos euros.

Y cada uno se repite con varias semillas del generador de demanda, porque la demanda es estocástica.

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

Quiero insistir en lo que ya trae, porque condiciona cómo se lee todo lo demás. Reparto dinámico de potencia entre batería y electrolizador por tramos de estado de carga. Tiempo mínimo de funcionamiento de dos horas con histéresis y anti-rebote, para que los equipos electroquímicos no conmuten cada pocos minutos. La gestión de los dos niveles de presión con su compresor. Y una decisión económica de producir hidrógeno frente a reponerlo fuera.

Es decir, ya tiene los mecanismos que distinguen a un gestor de reglas maduro de un reparto por prioridades. Lo que no tiene es ninguna predicción.

---

## Diapositiva 13 · Versión B: la previsión mejora sistemáticamente el servicio de hidrógeno

La Versión B es la misma heurística con las dos previsiones metidas dentro. No cambia la arquitectura: cambia lo que mira la regla en el momento de decidir.

La previsión solar entra en el reparto del excedente: antes dependía solo del estado de carga de ese instante; ahora, si la previsión anticipa que el excedente va a caer, el reparto se desplaza hacia la batería antes de que caiga. Y la de precio gobierna un arbitraje de batería.

B tiene una victoria y un empate. La victoria es el servicio de hidrógeno, en treinta y nueve de cuarenta pares, y lo importante no es el tamaño sino que escala con la calidad de la previsión: con el oráculo se multiplica por diez. Lo que limita es la predicción, no el diseño.

El empate es el coste, y de ahí sale la regla de diseño que aplico después: la primera versión del arbitraje traducía «el precio va a subir» en una acción de tamaño fijo, y empeoraba el coste, más cuanto mejor era la previsión. Una acción disparada por una previsión tiene que estar condicionada, y su tamaño salir del margen económico disponible.

---

## Diapositiva 14 · La batería estaba al 85 % mientras el electrolizador compraba red

Al descomponer la importación de la Versión A por destinos aparece esto, y es lo que motiva el tercer gestor.

De los mil trescientos veintiún kilovatios-hora que compra a la red en una semana, el setenta y seis por ciento van al electrolizador, a ciento veintiuno con cinco euros el megavatio-hora. Y en los instantes exactos en que los compra, la batería está al ochenta y cinco por ciento de media.

Pongan eso junto al otro lado del balance: en esa misma semana la estación exporta catorce mil kilovatios-hora a treinta y nueve euros. Vende diez veces más energía de la que compra, y la compra tres veces más cara de lo que la vende. Está pasando la misma energía dos veces por el contador, y perdiendo en los dos sentidos.

El motivo está en el orden del código: la batería cubre primero los vehículos y, en un paso posterior, la decisión económica enciende el electrolizador; esa carga nueva no se le vuelve a ofrecer, así que la absorbe la red.

---

## Diapositiva 15 · Versión C: separar de dónde sale la energía de cuándo conviene producir

La Versión C separa dos decisiones que la heurística tomaba juntas: de dónde sale la energía del electrolizador y cuándo conviene producir. En pantalla, los cuatro pasos de la lógica común, con los dos que sustituyo en ámbar.

El primero son diez líneas: la carga que crea la decisión de producir hidrógeno se le ofrece a la batería antes que a la red, mientras el estado de carga esté por encima del sesenta por ciento. Ese sesenta sale del contrafactual del diagnóstico anterior.

El segundo es un planificador: estima cuánto hidrógeno falta y cuánto excedente gratis viene, y de ahí salen las horas de electrolizador que hay que comprar a la red, que se colocan en las más baratas del horizonte.

Conviene precisar de dónde sale ese precio. El mercado diario publica sobre la una de la tarde las veinticuatro horas del día siguiente: la parte del horizonte ya publicada se usa tal cual, y solo se predice el tramo que aún no ha salido a mercado.

Y lo que hace defendible la regla es que solo usa el orden: la decisión es «estoy entre las ene más baratas, sí o no», y eso no cambia si la previsión falla en el nivel mientras acierte en el orden.

---

## Diapositiva 16 · Versión C: −13,9 % de coste semanal, en los veinte pares evaluados

Los resultados de la Versión C, sobre siete días y veinte pares escenario-semilla.

La figura es la diferencia de coste de cada versión frente a la A, escenario por escenario, y la banda gris es el umbral de relevancia. La Versión B cae dentro de la banda en los cuatro: en coste empata. La C se sale por la izquierda en los cuatro, y por bastante.

En la tabla, las tres métricas: cincuenta y dos euros con tres menos por semana, un trece coma nueve por ciento, ganando en los veinte pares; un cincuenta y cuatro por ciento menos de importación; y la autosuficiencia del ochenta y siete coma siete al noventa y cuatro coma tres.

El orden entre escenarios no lo fija el excedente disponible, sino el precio al que compraba el electrolizador: se ahorra más donde más caro compraba.

Y la mejora tiene un precio, que declaro yo: la batería cicla dos coma dos veces más, con la degradación sin modelar, y en el nublado hay que reponer desde fuera tres kilos de hidrógeno a la semana en vez de uno. Valorado dentro del coste, pero es un dato de operación.

---

## Diapositiva 17 · Y la mejora se puede atribuir pieza a pieza

Y como cada mecanismo tiene su interruptor, la mejora se puede atribuir pieza a pieza. Tres tandas, el mismo fichero, los mismos veinte pares. C-cero es solo el primer cambio; C-pe le añade el planificador con el precio ya publicado; y C es la versión completa.

Alimentar el electrolizador desde la batería, solo eso: menos cuarenta y siete euros con uno. El noventa por ciento del ahorro, en veinte de veinte pares.

Añadir la programación de las horas: cinco euros con uno más. Significativa, pero por debajo de mi umbral de relevancia, así que la declaro como tal. El mecanismo no es comprar más barato, sino comprar menos.

Y añadir la red neuronal de precio: cero. Las dos tandas salen idénticas a precisión de máquina en los cuarenta indicadores. La razón es de disponibilidad de información: el mercado diario publica a las trece horas el precio del día siguiente, así que entre once y treinta y cinco horas del horizonte no hay nada que predecir.

---

## Diapositiva 18 · Limitaciones

Las limitaciones, agrupadas por a qué afectan.

Del modelo físico: algunos bloques asumen simplificaciones, la más relevante la ecuación de gas ideal en los tanques, que hace caber más hidrógeno del que cabría de verdad. Y la pila no llega a arrancar, que no es un fallo del gestor sino la decisión correcta: recuperar electricidad a partir del hidrógeno es el camino más caro y con más pérdidas de la estación, y mientras haya batería o red nunca compensa. La pila tiene sentido en modo isla, y ese modo no lo ejercito.

De los datos: la irradiancia sale de un reanálisis, que es lo que hace falta para entrenar, pero no es la señal que tendría la estación en tiempo real; cambiarla por una previsión operativa no toca el modelo, solo la entrada. Y la demanda de hidrógeno se construye por analogía con la eléctrica porque aún no hay flota de la que medirla; lo importante es que es la misma para las tres versiones, así que no favorece a ninguna.

Y de alcance: el coste no incluye peajes ni cargos, así que las cifras son comparativas. Y los umbrales están ajustados a esta instalación: llevar el algoritmo a otra exige recalibrarlos, no solo copiarlo.

---

## Diapositiva 19 · Conclusiones

La pregunta del trabajo era si una previsión con redes LSTM mejora a un EMS heurístico ya maduro. La respuesta, medida, son estas tres conclusiones.

Dos modelos entrenados, validados y corregidos, cuya señal combinada supera a la línea base en solar y en precio, y es la que consume el simulador.

Tres gestores comparados sobre la misma instalación: la predictiva mejora la seguridad de suministro de hidrógeno, y la final reduce el coste semanal casi un catorce por ciento en los veinte casos.

Y la tercera, que da sentido a las otras dos: la cadena de medida permite atribuir la mejora pieza a pieza. El valor de una previsión depende de en qué decisión se inserte y de qué información no esté ya disponible.

Cuatro líneas futuras. Aislar la previsión solar, dándole al planificador el excedente real en vez del previsto, para medir por separado lo que hoy va sumado. Dar al tanque un nivel objetivo antes de un día nublado previsto, que corregiría el único indicador que C empeora. Modelar la degradación de la batería. Y ampliar el horizonte a cuarenta y ocho horas con control predictivo: es el único tramo donde el mercado ya no está publicado y una red de precio volvería a aportar.

Muchas gracias por su atención.

---

## Diapositivas de reserva

### R1 · Una semana completa con la Versión C

Para preguntas sobre comportamiento dinámico, la reserva del 60 % o el ciclado de la batería.

### R2 · Un día del escenario nublado, hora a hora

Para explicar el mecanismo de C con un caso concreto.

### R3 · Nivel del tanque de alta en la semana nublada

Para la pregunta sobre el servicio de hidrógeno que empeora. C pasa más tiempo por debajo del nivel crítico que A: es la contrapartida del ahorro y está valorada dentro de la métrica de coste. SI PREGUNTAN POR EL TRAMO NEGATIVO: es un artefacto declarado del modelo — los integradores de los tanques no saturan a cero, así que el inventario puede bajar de cero. Ese tramo es exactamente el hidrógeno que hay que comprar fuera, y se valora a 8 €/kg dentro de la métrica principal. Activar la saturación queda como corrección pendiente, y está declarado en la memoria.

