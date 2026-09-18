# Guion de defensa

## Diapositiva 1 · Estrategias de gestión energética para una estación de repostaje multi-energía

Buenos días.

Soy Fernando Román Hidalgo y presento el Trabajo Fin de Grado «Estrategias de gestión energética para una estación de repostaje multi-energía».

Dividiré la charla en tres partes: el planteamiento y los datos, los dos modelos de predicción, y los tres algoritmos de gestión de energía que comparo.

---

## Diapositiva 2 · El marco ya pone fechas; la infraestructura sigue separada por vector

El transporte es una cuarta parte de las emisiones de la Unión, y casi tres cuartas partes de esa fracción son carretera.

El marco ya pone fechas estrictas para la descarbonización del transporte (2030 datos), pero hoy se contemplan y despliegan de forma totalmente separada, fragmentando las inversiones por cada vector energético. 

Aunque ya existen precedentes reales de estaciones multi-energía combinadas (como la inaugurada por Repsol en Fuerteventura, Morro Jable), la solución pasa por integrarlas conjuntamente en una microrred. Con esta integración surge un desafío de operación: decidir en cada instante y de forma inteligente de dónde sale cada kilovatio

---

## Diapositiva 3 · La estación OASIS, modelada en Simulink

Esta es la instalación: una microrred modelada en Simulink sobre la librería Simugrid. Tienen en pantalla los seis componentes con sus tamaños; la fotovoltaica instalada en la marquesina, la batería, el electrolizador, los tanques de alta y baja presión, la pila de combustible y los cargadores de vehículo eléctrico.

El modelo de Simulink viene del trabajo previo del grupo, y lo primero que hice fue ajustar su parametrización a la escala de una electrolinera para que la estación no quedara sobredimensionada. Todo se ha dimensionado a partir de la demanda media, destacando especialmente dos tamaños que salen directamente de los datos reales: la potencia de los cargadores (cincuenta kilovatios) y su número (dos unidades), como veremos más adelante.

---

## Diapositiva 4 · El EMS decide tres cosas, y es lo único que cambia entre versiones

El gestor de energía —el EMS, por sus siglas en inglés— es este único bloque de Simulink, y toma tres decisiones.

Cuando sobra sol, cómo repartir el excedente entre cargar la batería y producir hidrógeno. Cuando falta, en qué orden cubrir el déficit: batería, pila, red. Y en todo momento, si conviene producir hidrógeno o reponerlo desde fuera, comparando el coste del kilogramo producido aquí con su precio de reposición.

Y el objetivo del trabajo no es solo mejorar ese gestor, sino poder atribuir la mejora: cuánto viene de la predicción y cuánto de las reglas que la consumen.

---

## Diapositiva 5 · La demanda sale de sesiones reales de carga rápida, no de una hipótesis

Este primer bloque sirve para dimensionar la instalación.

Parto de un dataset real de carga rápida —una electrolinera suiza de acceso público.

De ahí salen los parámetros del dimensionado. Cincuenta kilovatios por cargador, porque cubre una sesión media sin obligar a meter un transformador de media tensión. Y dos cargadores, porque es donde la cola en hora punta deja de ser un problema.

Con esas distribuciones genero el perfil de demanda de cada simulación. Es estocástico, y eso importará en la comparación.

---

## Diapositiva 6 · Y los datos de entrenamiento, de dos fuentes públicas alineadas hora a hora

El segundo bloque es el de entrenamiento: dos fuentes públicas alineadas hora a hora.

La irradiancia sale de NASA POWER, un reanálisis meteorológico, del que tomo cerca de veinte años de registro horario para el punto de Sevilla junto con las variables que explican la nubosidad. Un detalle: la hora y el día no entran como número, sino en seno y coseno, para que el modelo sepa que las once de la noche y la medianoche están pegadas y no en extremos opuestos de la escala.

El precio son las casaciones del mercado diario español, vía ENTSO-E. Y con el histórico entra el contexto que explica su deriva: sobre todo la fotovoltaica instalada en España, que ha crecido lo bastante como para cambiarle la forma al precio a mediodía.

Y algo que importa: el reparto entre entrenamiento y prueba es temporal, nunca aleatorio. Mezclar horas le regalaría al modelo información del futuro.

---

## Diapositiva 7 · Dos redes con la misma arquitectura y parada temprana por validación

Las dos redes comparten arquitectura: dos capas LSTM y una salida de veinticuatro valores, el horizonte de un día. En pantalla, la curva de error: entrenamiento y validación no se separan, así que no hay sobreajuste.

Lo que sí merece explicación es por qué uso dos métricas distintas. Entreno con RMSE porque al elevar al cuadrado castiga mucho más un fallo grande que varios pequeños, y aquí lo que rompe una decisión es el fallo grande: no ver una punta de precio o una caída de sol.

Al solar puedo imponerle que la irradiancia predicha no sea negativa. Al de precio no, porque el precio sí admite negativos.

---

## Diapositiva 8 · El problema: ninguna de las dos redes bate sola a su línea base

Y aquí está el problema, el resultado que reorientó este capítulo.

Cada red se evalúa contra su línea base: la solar contra la persistencia de cielo claro, la de precio contra la de veinticuatro horas. Y es una referencia dura: en estas dos series el día de hoy se parece muchísimo al de ayer, así que «lo mismo que ayer» acierta la mayor parte del tiempo. 

Ninguna de las dos la bate: la solar queda un ocho coma ocho por ciento por detrás, la de precio un siete coma uno.

Pero pierden por una razón que vale la pena. Una red recurrente no está hecha para repetir lo de ayer, sino para anticipar cambios — y la mayoría de las horas no cambia nada.

La persistencia gana casi siempre. La red gana cuando importa.

No compiten: se complementan. Por eso la salida no es elegir una, sino combinarlas.

---

## Diapositiva 9 · La solución: proyección física y ponderación con el naive

La solución tiene tres partes, todas de postprocesamiento.

La primera consiste en acotar la predicción a la envolvente de cielo claro, no dejar que la irradiancia prevista supere la de un día despejado.

La siguiente es la ponderación de la red con su propia línea base, una combinación convexa con un peso distinto por cada hora del horizonte.

La tercera es la corrección del lazo cerrado, realimentando con el precio real de la hora ya transcurrida, que sigue siendo causal.

Y el resultado es que la señal combinada sí bate a su línea base. Y esa mejora se mide sobre una referencia que ya acierta la mayor parte del tiempo.

---

## Diapositiva 10 · Cuatro escenarios que cruzan recurso solar y régimen de precio

Para comparar los gestores necesito escenarios, y no los elegí al azar: cruzan las dos variables que gobiernan la decisión del EMS, sol y precio. Con sol y nublado, con precio plano y con punta, laborable y fin de semana.

Y no se simula un día suelto: cada escenario es la semana real del dataset de 2025 que arranca en esa fecha, repetida con varias semillas de demanda.

---

## Diapositiva 11 · Cuatro piezas sostienen todas las cifras que vienen a continuación

Antes de las cifras, cómo las mido. Cuatro decisiones.

Comparo en pareja: la misma semilla da la misma demanda a todas las versiones, así que enfrento dos versiones sobre la misma semana. El azar se va en la resta.

Uso Wilcoxon en lugar de la media para que el promedio no se pervierta por un mal día.

Un umbral de relevancia, fijado antes de simular y en mi contra: por debajo de nueve euros a la semana lo doy por empate.

Y un oráculo, la misma tanda con previsión perfecta. Es un techo: si con previsión perfecta una idea no gana, mejorar la predicción no la va a salvar.

---

## Diapositiva 12 · Versión A: la referencia ya es una heurística madura

El primer gestor, la Versión A, es la referencia: viene del TFM previo del grupo y lo he portado a esta arquitectura.

Insisto en lo que ya trae, porque condiciona cómo se lee todo lo demás. Tienen las cuatro reglas en pantalla; me quedo con dos: un tiempo mínimo de funcionamiento con histéresis, para que los equipos electroquímicos no conmuten cada pocos minutos, y una decisión económica de producir, que compara lo que cuesta el kilogramo aquí con lo que costaría reponerlo fuera.

No es un reparto por prioridades: es un gestor de reglas maduro. Lo único que no tiene es predicción.

---

## Diapositiva 13 · Versión B: la previsión mejora sistemáticamente el servicio de hidrógeno

La Versión B es la misma heurística con las dos previsiones metidas dentro. La arquitectura no cambia: cambia lo que mira la regla al decidir. La previsión solar entra en el reparto del excedente — si se anticipa que el excedente va a caer, el reparto se desplaza hacia la batería antes de que caiga. Y la de precio gobierna un arbitraje de batería.

Sale una victoria y un empate.

La victoria es el servicio de hidrógeno: mejora en treinta y nueve de los cuarenta pares. Esta mejora además escala con la calidad de la previsión: con el oráculo se multiplica por diez. Lo que limita es la predicción, no el diseño.

El empate es el coste, y de ahí sale la regla de diseño que aplico después. La primera versión del arbitraje traducía «el precio va a subir» en una acción de tamaño fijo — y empeoraba el coste, más cuanto mejor era la previsión. Una acción disparada por una previsión tiene que salir del margen económico disponible, no de una constante.

---

## Diapositiva 14 · La batería estaba al 85 % mientras el electrolizador compraba red

B no movió el coste, así que la pregunta pasó a ser dónde se va ese dinero. Volví a la Versión A y descompuse su importación de red por destinos, y apareció esto.

De los kilovatios-hora que compra a la red en una semana, el setenta y seis por ciento van al electrolizador. Y en los instantes exactos en que los compra, la batería está al ochenta y cinco por ciento de media.

Pongan eso junto al otro lado del balance: en esa misma semana la estación vende diez veces más energía de la que compra, y la compra tres veces más cara de lo que la vende. Está pasando la misma energía dos veces por el contador, y perdiendo en los dos sentidos.

El motivo está en el orden del código: la batería cubre primero los vehículos y, en un paso posterior, la decisión económica enciende el electrolizador; esa carga nueva no se le vuelve a ofrecer, así que la absorbe la red.

---

## Diapositiva 15 · Versión C: separar de dónde sale la energía de cuándo conviene producir

La Versión C separa dos decisiones que la heurística tomaba juntas: de dónde sale la energía del electrolizador y cuándo conviene producir. En pantalla, los cuatro pasos de la lógica común, con los dos que sustituyo en ámbar.

La carga que crea la decisión de producir hidrógeno se le ofrece a la batería antes que a la red, mientras el estado de carga esté por encima del sesenta por ciento, que sale del contrafactual del diagnóstico anterior.

El segundo es un planificador: estima cuánto hidrógeno falta y cuánto excedente gratis viene, y de ahí salen las horas de electrolizador que hay que comprar a la red, que se colocan en las más baratas del horizonte que se predice (mercado +24h)

Y lo que hace defendible la regla es que solo usa el orden: la decisión es «estoy entre las ene más baratas, sí o no», y eso no cambia si la previsión falla en el nivel mientras acierte en el orden.

---

## Diapositiva 16 · Versión C: −13,9 % de coste semanal, en los veinte pares evaluados

Los resultados de la Versión C, en veinte pares escenario-semilla.

La figura es la diferencia de coste frente a la A, escenario por escenario. B cae dentro del umbral de relevancia: en coste empata. C se sale por la izquierda en los cuatro, y por bastante.

En la tabla, tres métricas. El coste baja unos cincuenta y dos euros por semana: casi un catorce por ciento, y gana en los veinte pares. La importación de red cae a la mitad, un cincuenta y cuatro por ciento. Y la autosuficiencia sube del ochenta y ocho al noventa y cuatro por ciento.

Comparando los escenarios se puede observar que se ahorra más donde más caro compraba.

Pero la mejora tiene un coste: Los tres kilos de hidrógeno que hay que reponer de forma externa en el escenario nublado y el ciclado de la batería que a la larga provocaría un desgaste en la infraestructura.

---

## Diapositiva 17 · Y la mejora se puede atribuir pieza a pieza

La mejora se atribuye pieza a pieza aislando cada parte de la mejora. 

Alimentar el electrolizador desde la batería, solo eso: menos cuarenta y siete euros con uno. El noventa por ciento del ahorro, en veinte de veinte pares.

Añadir el planificador: cinco euros más. Y es aquí donde entra la previsión solar, porque el planificador la usa para estimar cuánto excedente gratis viene. La solución no es solo comprar más barato, sino comprar menos.

Y añadir la red neuronal de precio: cero. La razón es de disponibilidad de información: el mercado publica hasta las 12 h del día siguiente, predecir más allá de las 24h no aporta ya que el algoritmo sigue viendo los mismos tramos de precio.

---

## Diapositiva 18 · Limitaciones

Las limitaciones, agrupadas según a qué afectan.

El modelo físico presenta algunas simplificaciones, como el gas ideal en los tanques, que hace caber más hidrógeno del que cabría de verdad. No se llega a usar la pila ya que el algoritmo decide que es el método más caro de cubrir la demanda. No se ejercita el modo isla.

En cuanto a los datos, la irradiancia sale de un reanálisis, para entrenar basta pero para operar habría que obtenerla de una predicción. Y la demanda de hidrógeno se construye por analogía con la eléctrica porque aún no hay datasets públicos de flotas.

Además se han obviado peajes y cargos, así que las cifras de coste son comparativas entre sistemas. Y por último las constantes usadas en los EMS están adaptadas a esta microrred, por lo que para otra instalación habría que reajustarlas.

---

## Diapositiva 19 · Conclusiones

Repasando lo que se ha logrado en el trabajo, tenemos:

Dos modelos entrenados, validados y corregidos, cuya señal combinada supera a la línea base en solar y en precio, y es la que consume el simulador.

Tres gestores sobre la misma instalación: uno que mejora la gestión de hidrógeno, y otro que reduce el coste semanal casi un catorce por ciento en los veinte casos.

Y la tercera, poder atribuir la mejora pieza a pieza. Gracias a esto podemos saber qué aporta cada red LSTM a la decisión final.

Cuatro líneas futuras. Aislar la previsión solar, para medir por separado lo que hoy va sumado dentro de la programación. Dar al tanque un nivel objetivo antes de un día nublado previsto. Modelar la degradación de la batería. Y ampliar el horizonte a cuarenta y ocho horas con control predictivo (mpc).

Muchas gracias por su atención.

---

## Diapositivas de reserva

### R1 · Una semana completa con la Versión C

Para preguntas sobre comportamiento dinámico, la reserva del 60 % o el ciclado de la batería.

### R2 · Un día del escenario nublado, hora a hora

Para explicar el mecanismo de C con un caso concreto.

### R3 · Nivel del tanque de alta en la semana nublada

Para la pregunta sobre el servicio de hidrógeno que empeora. C pasa más tiempo por debajo del nivel crítico que A: es la contrapartida del ahorro y está valorada dentro de la métrica de coste. SI PREGUNTAN POR EL TRAMO NEGATIVO: es un artefacto declarado del modelo — los integradores de los tanques no saturan a cero, así que el inventario puede bajar de cero. Ese tramo es exactamente el hidrógeno que hay que comprar fuera, y se valora a 8 €/kg dentro de la métrica principal. Activar la saturación queda como corrección pendiente, y está declarado en la memoria.

