= Modelos de predicción basados en redes LSTM <cap-lstm>

Los sistemas de gestión de energía proactivos requieren predicciones fiables de las variables que más influyen en la operación de la estación: la irradiancia solar —que determina la generación fotovoltaica— y el precio horario de la electricidad en el mercado spot (que condiciona cuándo conviene comprar de la red o producir hidrógeno). En este capítulo se describen los dos modelos de redes neuronales recurrentes de tipo LSTM (_Long Short-Term Memory_) desarrollados para cubrir ambas necesidades: el modelo solar, entrenado con datos meteorológicos del satélite NASA POWER, y el modelo de precio, entrenado con datos históricos del mercado ENTSO-E junto con variables meteorológicas y temporales.

Ambos modelos se integran en la simulación Simulink mediante _S-Functions_ de MATLAB que se ejecutan en tiempo real durante la simulación, actualizan su predicción cada hora y entregan un vector de 24 valores que cubre el horizonte del día siguiente.

== Fundamentos de las redes LSTM

Las redes neuronales recurrentes (RNN) son una familia de arquitecturas diseñadas para procesar secuencias de datos con dependencias temporales. A diferencia de las redes _feedforward_ convencionales, las RNN mantienen un estado interno (memoria) que se actualiza en cada paso de tiempo y permite capturar patrones de largo alcance en series temporales.

Las LSTM @hochreiter1997lstm son una variante especialmente diseñada para evitar el problema del desvanecimiento del gradiente (_vanishing gradient_), que limita la capacidad de las RNN estándar para aprender dependencias a largo plazo. La célula LSTM incorpora tres puertas (_gates_) que regulan el flujo de información:

- *Puerta de olvido* ($f_t$): decide qué información del estado de la célula anterior se descarta.
- *Puerta de entrada* ($i_t$): decide qué información nueva se almacena en el estado de la célula.
- *Puerta de salida* ($o_t$): decide qué parte del estado de la célula se expone como salida.

Las ecuaciones que gobiernan una célula LSTM son:

$
         f_t & = sigma(W_f [h_(t-1), x_t] + b_f) \
         i_t & = sigma(W_i [h_(t-1), x_t] + b_i) \
  tilde(C)_t & = tanh(W_C [h_(t-1), x_t] + b_C) \
         C_t & = f_t dot C_(t-1) + i_t dot tilde(C)_t \
         o_t & = sigma(W_o [h_(t-1), x_t] + b_o) \
         h_t & = o_t dot tanh(C_t)
$

donde $x_t$ es el vector de entrada en el instante $t$, $h_t$ es el estado oculto, $C_t$ es el estado de la célula, y $W_*, b_*$ son los pesos y sesgos aprendidos durante el entrenamiento.

En el presente trabajo se utiliza una arquitectura de dos capas LSTM apiladas, con una capa totalmente conectada al final que colapsa el estado oculto en el vector de salida de 24 valores. Esta configuración permite al modelo capturar tanto patrones de corto plazo (variaciones hora a hora) como ciclos más lentos (día/semana/estacionalidad).

== Modelo LSTM solar: predicción de irradiancia

=== Datos de entrada y fuente

El modelo solar predice las 24 horas siguientes de irradiancia horizontal global (_ALLSKY Surface SW Down_, en Wh/m²), que es la variable que determina la potencia fotovoltaica generada. Los datos de entrenamiento provienen del servicio NASA POWER (_Prediction Of Worldwide Energy Resource_), que proporciona datos meteorológicos horarios basados en análisis de reanálisis atmosférico y observaciones satelitales @nasapower.

Se han descargado datos horarios para la ubicación de Sevilla (latitud 37.39°N, longitud 5.99°W) correspondientes al período 2007--2025, es decir, 19 años de registro.

Las variables empleadas como entrada (_features_) al modelo son las siguientes:

#figure(
  table(
    columns: (1fr, 2fr, 1fr),
    align: (left, left, left),
    table.header([*Feature*], [*Descripción*], [*Normalización*]),
    [`ALLSKY`], [Irradiancia horizontal global (Wh/m²)], [Min-Max → \[0, 1\]],
    [`RH2M`], [Humedad relativa a 2 m (%)], [Min-Max → \[0, 1\]],
    [`PS`], [Presión superficial (kPa)], [Min-Max → \[0, 1\]],
    [`cloud_idx`], [Índice de nubosidad: $1 - "ALLSKY"/"CLRSKY"$], [Calculada, ∈ \[0, 1\]],
    [`hora_sin`], [$sin(2π · h/24)$], [Codificación cíclica],
    [`hora_cos`], [$cos(2π · h/24)$], [Codificación cíclica],
    [`dia_sin`], [$sin(2π · d_"año"/365)$], [Codificación cíclica],
    [`dia_cos`], [$cos(2π · d_"año"/365)$], [Codificación cíclica],
  ),
  caption: [Features de entrada al modelo LSTM solar (8 variables).],
) <tbl-features-solar>

La codificación cíclica (_circular encoding_) se emplea para representar variables periódicas como la hora del día y el día del año de forma que el modelo perciba correctamente la continuidad entre el último y el primer valor del ciclo (por ejemplo, que las 23:00 es adyacente a las 00:00). Es una técnica estándar de preprocesado en predicción de series temporales con estacionalidad conocida.

El índice de nubosidad se calcula como la fracción de irradiancia bloqueada respecto al cielo despejado: si $"CLRSKY" > 10$ Wh/m², entonces $"cloud_idx" = 1 - "ALLSKY"/"CLRSKY"$, con saturación en \[0, 1\]. Este índice resume en un único valor el estado de la nubosidad instantánea.

=== Arquitectura y entrenamiento

El modelo se construye con una arquitectura LSTM de dos capas apiladas seguida de dos capas totalmente conectadas:

#figure(
  table(
    columns: (1fr, 2fr, 1fr),
    align: (left, left, right),
    table.header([*Capa*], [*Tipo*], [*Unidades / Parámetro*]),
    [1], [sequenceInputLayer], [8 features],
    [2], [lstmLayer (`OutputMode: sequence`)], [128 unidades],
    [3], [dropoutLayer], [20%],
    [4], [lstmLayer (`OutputMode: last`)], [64 unidades],
    [5], [dropoutLayer], [20%],
    [6], [fullyConnectedLayer], [64 neuronas],
    [7], [reluLayer], [—],
    [8], [fullyConnectedLayer], [24 neuronas (salida)],
    [9], [reluLayer], [—],
    [10], [regressionLayer], [—],
  ),
  caption: [Arquitectura de la red LSTM solar.],
) <tbl-arq-solar>

La primera capa LSTM opera en modo `sequence` para pasar el estado oculto a cada paso de tiempo a la segunda capa, mientras que la segunda opera en modo `last` para comprimir toda la secuencia en un único vector de estado. Las capas de _dropout_ (20%) se añaden entre ambas LSTM para reducir el sobreajuste. La capa final de activación rectificada (`reluLayer`) tras la salida de 24 valores impone por construcción que la irradiancia predicha no sea negativa, una restricción física que el modelo de precio no puede adoptar (el precio spot sí admite valores negativos) y que explica por qué en aquel caso hace falta el mecanismo de recorte descrito en @sec-clamp.

La red se entrena con los siguientes hiperparámetros:

#figure(
  table(
    columns: (2fr, 1fr),
    align: (left, right),
    table.header([*Hiperparámetro*], [*Valor*]),
    [Optimizador], [Adam],
    [Tasa de aprendizaje inicial], [0.001],
    [Descenso de tasa (factor / periodo)], [0.3 / cada 80 épocas],
    [Máximo de épocas], [300],
    [Tamaño de mini-lote], [64],
    [Umbral de gradiente], [1.0],
    [Paciencia de validación], [20 épocas],
    [Ventana de historia (_lookback_)], [48 h],
    [Horizonte de predicción], [24 h],
    [División train/val/test], [80% / 10% / 10% cronológico],
    [RMSE de validación (escala normalizada)], [0,27761],
    [Época de parada], [21 de 300 (criterio de validación)],
  ),
  caption: [Hiperparámetros de entrenamiento del modelo LSTM solar.],
) <tbl-hiper-solar>

La división 80/10/10 se realiza de forma cronológica, no aleatoria: las secuencias se
reparten en bloques consecutivos en el tiempo, de modo que el modelo nunca ve datos
posteriores a los de evaluación. Sobre las 166 465 secuencias disponibles, el conjunto de
test resultante cubre del 5 de febrero de 2024 al 30 de diciembre de 2025, por lo que el
año 2025 (el que se emplea en la campaña de simulación) queda íntegramente fuera del
entrenamiento.

El entrenamiento se realiza con aceleración GPU mediante CUDA y se detiene por criterio de validación en la época 21 de 300, con un RMSE de validación de 0,27761 en la escala normalizada. La @fig-training-sol muestra que el error cae en las primeras iteraciones y que, a partir de ahí, las curvas de entrenamiento y validación se mantienen superpuestas en torno a ese valor sin separarse.

#figure(
  image("../img/TrainingSol.png", width: 90%),
  caption: [Curva de entrenamiento del modelo LSTM solar: evolución del error cuadrático medio en entrenamiento y validación a lo largo de las épocas.],
) <fig-training-sol>

=== Resultados de validación

La @fig-sol-semana muestra la predicción del modelo para el primer paso del horizonte (h+1) durante una semana del conjunto de test, comparada con los valores reales de irradiancia. La @fig-sol-24h muestra un ejemplo de predicción completa a 24 horas para un día individual.

#figure(
  image("../img/LSTM_Sol_Semana.png", width: 95%),
  caption: [Predicción LSTM solar (h+1) vs. irradiancia real ALLSKY durante una semana del conjunto de test (Sevilla, NASA POWER).],
) <fig-sol-semana>

#figure(
  image("../img/LSTM_Sol_24h.png", width: 85%),
  caption: [Predicción LSTM solar completa a 24 horas para un día de test. Cada punto corresponde a un horizonte h+1, h+2, ..., h+24.],
) <fig-sol-24h>

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Horizonte*], [*MAE* (Wh/m²)], [*RMSE* (Wh/m²)], [*R²*]),
    [h+1],  [16,89], [31,70], [—],
    [h+6],  [32,06], [60,49], [—],
    [h+12], [30,53], [62,92], [—],
    [h+24], [32,43], [67,31], [—],
    [Global (h+1…h+24)], [30,19], [61,08], [0,955],
    [Global, sólo horas de día], [59,38], [—], [—],
  ),
  caption: [Métricas de validación del modelo LSTM solar por horizonte, sobre el conjunto de test (05-feb-2024 a 30-dic-2025, 16 647 secuencias).],
) <tbl-metricas-solar>

El error no crece de forma monótona con el horizonte: h+12 (30,53 Wh/m²) es menor que h+6 (32,06). Esto sucede porque en una serie con un ciclo diario tan marcado el error depende sobre todo de la posición del instante predicho dentro del día, y no solo de su distancia al instante de emisión: al repartirse los instantes de emisión por las 24 horas, cada horizonte mezcla objetivos diurnos y nocturnos en proporciones distintas.

El 49,3 % de las horas del horizonte de predicción corresponden a horas nocturnas, en las que la irradiancia es nula y cualquier modelo acierta. Por ello se reporta también el MAE restringido a horas de día, que es el doble del global: 59,38 Wh/m² frente a una irradiancia media diurna de 415 Wh/m², es decir un error relativo del 14,3 %. Esta es la cifra comparable con la literatura de predicción de irradiancia; el MAE global de 30,19 Wh/m² está diluido por las noches y no debe interpretarse de forma aislada.

=== Evaluación frente a líneas base

El coeficiente de determinación de la irradiancia está dominado por el ciclo día/noche, y por tanto un valor elevado no acredita por sí mismo capacidad predictiva. Para dimensionar el resultado se comparan dos referencias clásicas, evaluadas sobre las mismas secuencias de test:

- *Persistencia lag-24*: repetir las 24 últimas horas observadas.
- *Persistencia de cielo claro* (_smart persistence_): índice de cielo claro de las últimas 24 h, $k_t = sum "ALLSKY" \/ sum "CLRSKY"$, aplicado a la curva de cielo claro del día siguiente. Al ser CLRSKY una magnitud puramente geométrica, su valor futuro es conocido de antemano. Es la referencia habitual en predicción de irradiancia @wang2019lstmsolar.

#figure(
  table(
    columns: (2fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Modelo*], [*MAE* (Wh/m²)], [*MAE diurno*], [*R²*]),
    [LSTM], [30,19], [59,38], [0,955],
    [Persistencia lag-24], [33,59], [66,23], [0,924],
    [Persistencia de cielo claro], [27,74], [54,71], [0,945],
    [Sólo el ciclo día/noche], [—], [—], [0,891],
  ),
  caption: [Comparación del modelo LSTM solar con las líneas base, sobre el mismo conjunto de test. La última fila corresponde a una curva de cielo claro escalada por una constante, un modelo que no incorpora ninguna información meteorológica.],
) <tbl-baseline-solar>

Una curva de cielo claro escalada por una constante, sin información meteorológica alguna, alcanza ya $R^2 = 0","891$, y la persistencia de cielo claro llega a $0","945$ frente a los $0","955$ del modelo LSTM (@tbl-baseline-solar). En consecuencia, el R² no se emplea aquí como argumento de calidad: la métrica relevante es la mejora relativa frente a la línea base (_skill_).

En el promedio de las 24 horas del horizonte, el modelo mejora un 10,1 % a la persistencia lag-24 pero queda un 8,8 % por debajo de la persistencia de cielo claro. Ese promedio, sin embargo, oculta un comportamiento fuertemente dependiente del horizonte:

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Horizonte*], [*LSTM*], [*Cielo claro*], [*Skill*]),
    [h+1], [16,89], [19,72], [+14,4 %],
    [h+2], [17,09], [22,15], [+22,8 %],
    [h+3], [21,65], [24,17], [+10,4 %],
    [h+4], [25,30], [25,76], [+1,8 %],
    [h+5], [29,79], [26,94], [−10,6 %],
    [h+6], [32,06], [27,74], [−15,6 %],
    [Media h+1…h+3], [*18,54*], [22,01], [*+15,8 %*],
  ),
  caption: [MAE (Wh/m²) del modelo LSTM solar frente a la persistencia de cielo claro por horizonte, y mejora relativa. El modelo aporta información hasta h+4 y a partir de h+5 es superado por la línea base.],
) <tbl-skill-solar>

El modelo bate a la línea base en las cuatro primeras horas del horizonte y es superado a partir de la quinta. Este resultado acota el tramo del horizonte útil para el EMS de la Versión B (@cap-metodologia), que promedia únicamente las primeras horas del vector de previsión: sobre las tres primeras la mejora es del 15,8 %, mientras que extenderlo a seis horas la reduciría al 2,5 %. Este análisis por horizonte se ha realizado sobre el conjunto de test; el valor definitivo de `N_PV_H` se fija sobre el conjunto de validación (apartado siguiente).

El comportamiento por tipo de día completa la interpretación. Sobre los cuatro días empleados en la campaña de simulación:

#figure(
  table(
    columns: (1.4fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Día*], [*Irradiancia* (Wh/m²·día)], [*MAE LSTM*], [*MAE cielo claro*]),
    [2 jul (despejado)], [8 163], [22,59], [*6,04*],
    [17 sep (despejado)], [6 017], [13,78], [*0,99*],
    [13 jul (despejado tras día nuboso)], [8 324], [*37,20*], [107,05],
    [11 feb (nublado)], [1 451], [*53,67*], [75,13],
  ),
  caption: [MAE (Wh/m²) del modelo LSTM solar y de la persistencia de cielo claro en los cuatro días de la campaña de simulación.],
) <tbl-dias-solar>

En días de tiempo estable y cielo despejado la línea base es netamente superior (hasta un orden de magnitud el 17 de septiembre), simplemente porque no hay nada que predecir: la geometría solar basta. El modelo aporta cuando el estado del cielo cambia respecto al día anterior, ya sea al despejar (13 de julio, donde la persistencia falla al arrastrar la nubosidad del día previo) o en jornadas nubosas (11 de febrero). Este es precisamente el régimen en el que un EMS reactivo se equivoca, y por tanto el régimen en el que la predicción puede modificar la operación.

La comparación no es del todo simétrica, y esa asimetría explica en buena medida por qué el modelo pierde a partir de h+5. La persistencia de cielo claro dispone de la curva CLRSKY del día siguiente y solo tiene que estimar un escalar: el índice de cielo claro. El modelo LSTM, en cambio, predice la irradiancia en bruto y no recibe CLRSKY futuro entre sus entradas, por lo que debe reconstruir a partir de las codificaciones cíclicas de hora y día la misma componente determinista que la línea base recibe gratis. Se le exige por tanto aprender la geometría solar además de la meteorología, y es en los horizontes largos —donde la componente geométrica domina sobre la meteorológica— donde ese sobrecoste se paga.

La práctica habitual en predicción de irradiancia consiste precisamente en evitarlo: modelar el índice de cielo claro $k_t = "ALLSKY" \/ "CLRSKY"$ en lugar de la irradiancia bruta, y recuperar la predicción final multiplicando por la curva CLRSKY conocida del horizonte. Importa precisar el alcance exacto de lo que falta, porque el modelo no es del todo ajeno a esta idea: la _feature_ `cloud_idx` de la @tbl-features-solar es justamente $1 - k_t$, de modo que el índice de cielo claro ya entra en la red como variable de entrada. Lo que no está es, por un lado, $k_t$ como variable objetivo (la red predice irradiancia bruta y debe por tanto reproducir la envolvente geométrica) y, por otro, el valor futuro de CLRSKY, que la línea base sí utiliza.

De ahí se derivan dos líneas de mejora de coste muy distinto. La primera, y la más barata, no requiere reentrenar nada: basta con proyectar la predicción ya existente sobre la envolvente de cielo claro conocida, es decir, calcular el índice implícito $hat(k)_t = hat(y) \/ "CLRSKY"$, acotarlo al intervalo físicamente admisible y reconstruir la predicción multiplicando de nuevo por CLRSKY. Esto corrige las predicciones que violan la envolvente (el modo de fallo más probable en los horizontes largos) y puede evaluarse sobre las predicciones de test ya guardadas. La segunda, reentrenar la red tomando $k_t$ como objetivo, es la solución de fondo, pero obliga a revalidar el modelo y a repetir las simulaciones del @cap-metodologia, que se realizaron con la versión ya entrenada. La primera se ha llevado a cabo, y su resultado se presenta en la sección siguiente.

Conviene también matizar la fortaleza aparente de la línea base en los días despejados de la @tbl-dias-solar. ALLSKY y CLRSKY proceden de la misma cadena de cálculo radiativo de NASA POWER, y por eso en un día genuinamente despejado ambos productos coinciden casi exactamente y el índice $k_t$ vale prácticamente 1 dos días seguidos: el MAE de 0,99 Wh/m² del 17 de septiembre no mide tanto la calidad de la persistencia como el acuerdo interno del reanálisis. Frente a medidas de piranómetro, con nubosidad parcial real no capturada por el producto satelital, esa ventaja sería sensiblemente menor.

En síntesis, el modelo LSTM solar queda validado para el uso que se le da en este trabajo (previsión a pocas horas, empleada para anticipar la evolución del excedente fotovoltaico) con un error relativo diurno del 14,3 % y una mejora del 15,8 % sobre la persistencia de cielo claro en el tramo h+1…h+3. La salida cruda de la red no queda validada, en cambio, como predictor de irradiancia a 24 horas: en el horizonte completo una línea base trivial es mejor, y afirmar lo contrario a partir del R² sería un error de interpretación.

Esta última limitación es de la red aislada, y los dos apartados siguientes la resuelven. La conclusión hacia la que apuntan puede adelantarse aquí: proyectando la predicción sobre la envolvente física de cielo claro y combinándola después con la línea base, la señal resultante —que es la que consume la Versión B— sí bate a la persistencia también en el agregado de 24 horas, con un skill del +5,8 %.

El comportamiento sobre los cuatro días concretos que consume la campaña de simulación (@tbl-escenarios) añade un matiz que el agregado esconde:

#figure(
  image("../img/lstm_solar_PrediccionSolarEnLosDiasDeLaCampana.png", width: 92%),
  caption: [Predicción de irradiancia frente al valor real de NASA POWER en los cuatro días de la campaña de simulación.],
) <fig-solar-campana>

En los tres días despejados el modelo sigue la curva casi exactamente (22,6 Wh/m² de MAE el 2 de julio, 37,2 el 13 de julio y 13,8 el 17 de septiembre), pero en el laborable nublado del 11 de febrero el error se dispara a 53,7 Wh/m², más del doble: la red predice un máximo de 425 Wh/m² frente a los 265 reales y no ve en absoluto el paso de nubes de las 13 a las 15 h, que hunde la irradiancia a un tercio de lo previsto.

La asimetría es la misma que se observará en el modelo de precio y conviene retenerla, porque es la que gobierna el valor operativo de la previsión: el modelo acierta en los días en los que acertar no aporta nada (un día despejado lo predice igual de bien la persistencia de cielo claro, sin red neuronal alguna) y falla justo en el día en que anticipar la caída de excedente sería útil. El mecanismo de la Versión B que consume `PVPred` está pensado precisamente para adelantar producción de hidrógeno ante una caída de irradiancia; el 11 de febrero es el escenario donde más margen tendría para aportar, y es donde la previsión es peor.

=== Proyección sobre la envolvente y elección del horizonte operativo

Para separar las dos hipótesis del apartado anterior (error por parametrización frente a incertidumbre meteorológica irreducible) se ha proyectado la predicción ya entrenada sobre la envolvente de cielo claro, sin reentrenar nada: se calcula el índice implícito $hat(k)_t = hat(y) \/ "CLRSKY"$, se acota a un techo $k_max$ y se reconstruye la predicción como $hat(k)_t dot "CLRSKY"$.

Un 6,65 % de las predicciones diurnas superan $1","10 dot "CLRSKY"$, con un exceso medio de 21,6 Wh/m² y un máximo de 100,9; ninguna es negativa.

#figure(
  table(
    columns: (1.6fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right),
    table.header([*Tratamiento*], [*MAE glob.*], [*MAE diurno*], [*R²*], [*Skill vs. c. claro*]),
    [Sin proyectar], [30,19], [59,38], [0,9554], [−8,8 %],
    [Sólo horas de noche a 0], [30,18], [59,38], [0,9554], [−8,8 %],
    [+ envolvente $k_max = 1","00$], [*28,47*], [*56,00*], [*0,9571*], [*−2,6 %*],
    [+ envolvente $k_max = 1","05$], [29,15], [57,33], [0,9565], [−5,1 %],
    [+ envolvente $k_max = 1","10$], [29,45], [57,94], [0,9561], [−6,2 %],
    [+ envolvente $k_max = 1","20$], [29,76], [58,54], [0,9558], [−7,3 %],
  ),
  caption: [Efecto de proyectar la predicción sobre la envolvente de cielo claro, sobre el mismo conjunto de test. MAE en Wh/m².],
) <tbl-envolvente>

Enmascarar las horas nocturnas no cambia el MAE diurno (59,38 Wh/m² antes y después): la mejora de las filas siguientes procede de la envolvente. El mejor techo resulta ser $k_max = 1","00$, es decir, no permitir que la predicción supere en ningún caso la irradiancia de cielo despejado; esto es coherente con la naturaleza del dato, ya que ALLSKY y CLRSKY proceden de la misma cadena radiativa de NASA POWER y el primero no excede al segundo por construcción. Con ese techo el MAE diurno baja de 59,38 a 56,00 Wh/m² (una mejora del 5,7 %) y el déficit frente a la línea base se reduce de −8,8 % a −2,6 %.

Más informativo aún es dónde actúa la corrección:

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right),
    table.header([*Horizonte*], [*LSTM*], [*Proyectado*], [*Cielo claro*], [*Mejora*]),
    [h+1], [16,89], [13,92], [19,72], [17,6 %],
    [h+2], [17,09], [16,02], [22,15], [6,3 %],
    [h+3], [21,65], [21,51], [24,17], [0,7 %],
    [h+6], [32,06], [30,55], [27,74], [4,7 %],
    [h+12], [30,53], [30,10], [28,80], [1,4 %],
    [h+16], [36,53], [36,52], [28,82], [0,0 %],
    [h+20], [32,72], [32,65], [28,87], [0,2 %],
    [h+24], [32,43], [30,53], [29,63], [5,9 %],
  ),
  caption: [MAE (Wh/m²) por horizonte antes y después de proyectar sobre la envolvente. El desglose se calculó con $k_max = 1","10$, el techo con el que se hizo el diagnóstico; el techo que finalmente se despliega es $1","00$ (@tbl-envolvente). La mejora se concentra en las primeras horas y se anula en el tramo central.],
) <tbl-envolvente-horizonte>

La mejora se concentra en h+1 (17,6 %) y h+2 (6,3 %), y se anula por completo entre h+13 y h+20, donde la corrección no llega al 0,2 %. Y, lo más concluyente, el punto de cruce con la línea base no se mueve: sigue en h+5.

De aquí se siguen dos conclusiones distintas, que no deben mezclarse. En el corto plazo, la parametrización sí estaba costando precisión: el modelo emitía predicciones por encima de la envolvente física y corregirlas recupera casi un 18 % de error en h+1. En el largo plazo, en cambio, la hipótesis queda refutada: el error de los horizontes centrales no es un artefacto de haber predicho irradiancia bruta en lugar del índice de cielo claro, porque forzar la envolvente no lo reduce. Es incertidumbre meteorológica genuina, la que solo se resolvería incorporando una previsión NWP como entrada. Reentrenar la red tomando $k_t$ como objetivo no está por tanto justificado: no es donde está el problema, y obligaría a repetir toda la campaña de simulación. La proyección, en cambio, es un posprocesado que sí conviene aplicar, porque actúa justo sobre el tramo que consume el EMS.

*Elección del horizonte operativo.* El parámetro `N_PV_H` de la Versión B se ha fijado repitiendo el análisis por horizonte sobre el conjunto de validación, y no sobre el de test. Sobre validación, el promedio de las dos primeras horas del horizonte alcanza un skill del 9,6 % frente a la persistencia de cielo claro, superior tanto al de una sola hora (3,2 %) como al de tres (6,9 %), y a partir de la quinta el skill se vuelve negativo. Se adopta en consecuencia `N_PV_H = 2`. Sobre test, el promedio de h+1 y h+2 da un skill del 18,8 % frente al 15,8 % del promedio de tres horas, y con la proyección aplicada sube al 28,5 %.

=== Combinación con la línea base

Las secciones anteriores dejan un modelo que gana con claridad en las primeras horas del horizonte y pierde a partir de la quinta. Elegir uno de los dos predictores desperdicia información: la alternativa estándar, propuesta por @bates1969combination y hoy rutinaria en predicción de series energéticas, es combinarlos horizonte a horizonte,

$ hat(y)_"comb" (h) = w(h) dot hat(y)_"LSTM" (h) + (1 - w(h)) dot hat(y)_"cielo claro" (h) $

con los pesos $w(h)$ ajustados por barrido fino minimizando el MAE sobre el conjunto de validación, nunca sobre el de test. Es el mismo tratamiento que se aplica al modelo de precio, de forma que ambos reciben el mismo criterio. La combinación de predictores es, además, notoriamente difícil de batir en predicción de precios eléctricos @lago2021benchmarking. La señal de la LSTM que entra en la combinación es la ya proyectada sobre la envolvente con $k_max = 1","00$, que es la que se despliega.

Los pesos ajustados reproducen con fidelidad el diagnóstico del apartado anterior: valen 0,92 y 0,90 en h+1 y h+2, caen a 0,20 en h+6 y se anulan casi por completo entre h+15 y h+19, donde la red no aporta nada sobre la geometría solar. La recuperación parcial en las últimas horas del horizonte (0,44 y 0,48 en h+23 y h+24) no es ruido de ajuste: esos horizontes, emitidos a lo largo de todo el día, caen mayoritariamente sobre las primeras horas del día siguiente, donde la red vuelve a tener información útil.

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right),
    table.header([*Señal*], [*MAE glob.*], [*MAE diurno*], [*R²*], [*Skill vs. c. claro*]),
    [LSTM sola], [30,19], [59,38], [0,9554], [−8,8 %],
    [LSTM proyectada], [29,45], [57,94], [0,9561], [−6,2 %],
    [Cielo claro (línea base)], [27,74], [54,71], [0,9446], [—],
    [*Combinada*], [*26,14*], [*51,51*], [0,9529], [*+5,8 %*],
  ),
  caption: [Comparación de las cuatro señales sobre el conjunto de test. La combinada es la única que bate a la línea base en el agregado de 24 h. MAE en Wh/m².],
) <tbl-combinacion-solar>

La señal combinada es la primera que bate a la persistencia de cielo claro en el agregado de las 24 horas, con un skill del +5,8 % frente al −8,8 % de la red sola. Y no lo consigue a costa de empeorar en ningún tramo: al comparar horizonte a horizonte contra la mejor de las dos señales por separado, la combinada nunca queda por detrás. En h+1 el MAE baja a 10,78 Wh/m², frente a los 19,72 de la línea base; parte de esa mejora procede, no obstante, de la proyección sobre la envolvente y no de la mezcla en sí, porque la combinación se construye sobre la señal ya proyectada.

Esto tiene dos consecuencias prácticas. La primera es que la Versión B debe consumir la señal combinada y no la salida cruda de la red; se ha implementado en consecuencia, y el detalle se describe en el apartado siguiente. La segunda, y más interesante, es que una previsión que es fiable en las 24 horas (y no solo en las dos primeras) abre la puerta a decisiones que el EMS hoy no toma: en particular, decidir a media tarde si merece la pena arrancar el electrolizador contando con el excedente que quede de jornada, una decisión de horizonte largo que tolera mucho más error que el reparto instantáneo de potencia. Esa ampliación queda propuesta como trabajo futuro.

=== Integración en Simulink: S-Function `lstm_sol.m`

El modelo entrenado se guarda en `codigo/modelos/lstm_solar_sevilla.mat` junto con los parámetros de normalización (`norm_params`). Durante la simulación, la S-Function `lstm_sol.m` lo carga en `InitializeConditions` y realiza una inferencia por hora en la función `Outputs`.

La S-Function recibe dos puertos de entrada: el vector de 8 features del instante actual (procedente del bloque _From Workspace_ que lee `features_solar`) y el tiempo de simulación en segundos. Mantiene internamente un buffer circular de 48 horas que se actualiza en cada llamada, y sólo realiza una nueva inferencia cuando la hora ha cambiado (`hora_actual ≠ ultima_hora`), lo que evita cálculos redundantes.

*La salida no es la predicción cruda de la red.* Sobre ella se aplican, en este orden, los dos posprocesados justificados en los apartados anteriores: la proyección sobre la envolvente con $k_max = 1","00$ y la combinación convexa con la persistencia de cielo claro. Esto obliga a llevar `CLRSKY` al modelo de Simulink: se ha añadido la serie horaria `clrsky_real` a `datos_OASIS.mat` en `preparar_workspace_simulink.m`, y `init_OASIS.m` la recorta al día simulado.

Los pesos $w(h)$ se leen de `w_combi_sol`, junto con `KT_MAX_COMBI`, en el archivo del modelo, donde los deja el script de entrenamiento. Si no están, o si `clrsky_hour` no está en el _workspace_ base, la S-Function emite la predicción cruda.

La salida es, en definitiva, un vector de 24 valores de irradiancia prevista en Wh/m² —la señal combinada, con skill del +5,8 % frente a la línea base— que el EMS usa para estimar la generación fotovoltaica de las próximas horas.

== Modelo LSTM de precio: predicción del mercado spot

=== Motivación y fuente de datos

El precio horario de la electricidad en el mercado spot español (OMIE/ENTSO-E) presenta una variabilidad elevada y patrones complejos: ciclos diarios (pico mañana y tarde, valle nocturno), ciclos semanales (festivos y fines de semana con precios distintos), estacionalidad anual y episodios extremos (precios negativos o superiores a 200 €/MWh) asociados a excedentes renovables o tensiones de suministro.

Predecir correctamente el precio de las próximas 24 horas permite al EMS tomar decisiones óptimas: operar el electrolizador cuando el precio es bajo (hidrógeno barato), importar energía en valles nocturnos para almacenarla en la batería, y evitar importar en horas punta.

Los datos de entrenamiento provienen del conjunto unificado `datos_entsoe_unificado_2021_2025.csv`, que contiene el precio horario spot (€/MWh) junto con la demanda nacional y la generación solar y eólica de España, alineados temporalmente con los datos NASA de meteorología. De todas ellas, el modelo final emplea el precio y las variables meteorológicas: la demanda nacional y la generación agregada se descargaron y permanecen en el conjunto unificado, pero no se incorporaron como _features_ porque en operación real no se conocen para el horizonte que se predice, y usarlas con su valor observado habría introducido información no disponible en el instante de decisión. Su efecto se aproxima de forma indirecta mediante `fv_allsky`. El período de datos cubre desde enero de 2021 hasta diciembre de 2025 (≈43 800 horas, 5 años), con split por años: entrenamiento en 2021--2023, validación en 2024 y test en 2025.

=== Features del modelo (14 variables)

A diferencia del modelo solar, el modelo de precio es altamente multivariante. La matriz de features tiene 14 columnas:

#figure(
  table(
    columns: (auto, 1fr, 2fr, 1fr),
    align: (center, left, left, left),
    table.header([*\#*], [*Feature*], [*Descripción*], [*Normalización*]),
    [1], [`precio`], [Precio spot España (€/MWh)], [Z-score (μ, σ)],
    [2], [`ALLSKY`], [Irradiancia horizontal (Wh/m²)], [Z-score],
    [3], [`T2M`], [Temperatura a 2 m (°C)], [Z-score],
    [4], [`WS50M`], [Velocidad de viento a 50 m (m/s)], [Z-score],
    [5], [`hora_sin`], [$sin(2π · h/24)$], [Codificación cíclica],
    [6], [`hora_cos`], [$cos(2π · h/24)$], [Codificación cíclica],
    [7], [`dia_sin`], [$sin(2π · d_"sem"/7)$], [Codificación cíclica],
    [8], [`dia_cos`], [$cos(2π · d_"sem"/7)$], [Codificación cíclica],
    [9], [`mes_sin`], [$sin(2π · m/12)$], [Codificación cíclica],
    [10], [`mes_cos`], [$cos(2π · m/12)$], [Codificación cíclica],
    [11], [`precio_lag24`], [Precio de hace 24 h (€/MWh)], [Z-score],
    [12], [`precio_lag168`], [Precio de hace 168 h = 1 semana (€/MWh)], [Z-score],
    [13], [`fv_norm`], [Capacidad FV instalada en España normalizada], [Min-Max → \[0, 1\]],
    [14], [`fv_allsky`], [`ALLSKY` · `fv_norm` (proxy de generación FV)], [Z-score],
  ),
  caption: [Features de entrada al modelo LSTM de precio (14 variables).],
) <tbl-features-precio>

Los lags de precio (`precio_lag24`, `precio_lag168`) son especialmente relevantes: el precio de hoy a las 14:00 está fuertemente correlacionado con el precio de ayer a las 14:00 (lag-24) y con el precio del mismo día de la semana anterior (lag-168). La variable `fv_norm` codifica el crecimiento de la capacidad fotovoltaica instalada en España año a año (15 GW en 2021, 36 GW en 2025), y captura así la tendencia secular a la baja del precio en horas centrales del día debida a la mayor penetración solar.

La normalización se realiza mediante Z-score ($z = (x - μ)/σ$) con parámetros calculados sobre el conjunto de entrenamiento y guardados en `norm_params` junto con el modelo. La S-Function aplica estos mismos parámetros en tiempo de inferencia.

=== Arquitectura y entrenamiento

La arquitectura del modelo de precio es análoga a la del modelo solar, con la adaptación del número de features de entrada (14 en lugar de 8) y un dropout ligeramente mayor (30%) para combatir el mayor riesgo de sobreajuste por la mayor dimensionalidad:

#figure(
  table(
    columns: (1fr, 2fr, 1fr),
    align: (left, left, right),
    table.header([*Capa*], [*Tipo*], [*Unidades / Parámetro*]),
    [1], [sequenceInputLayer], [14 features],
    [2], [lstmLayer (`OutputMode: sequence`)], [128 unidades],
    [3], [dropoutLayer], [30%],
    [4], [lstmLayer (`OutputMode: last`)], [64 unidades],
    [5], [dropoutLayer], [30%],
    [6], [fullyConnectedLayer], [64 neuronas],
    [7], [reluLayer], [—],
    [8], [fullyConnectedLayer], [24 neuronas (salida)],
    [9], [regressionLayer], [—],
  ),
  caption: [Arquitectura de la red LSTM de precio.],
) <tbl-arq-precio>

Los hiperparámetros de entrenamiento difieren en el _lookback_ (168 h = 7 días, para capturar el ciclo semanal completo) y en el split temporal (por años en lugar de por proporción fija):

#figure(
  table(
    columns: (2fr, 1fr),
    align: (left, right),
    table.header([*Hiperparámetro*], [*Valor*]),
    [Optimizador], [Adam],
    [Tasa de aprendizaje inicial], [0.001],
    [Descenso de tasa (factor / periodo)], [0.5 / cada 50 épocas],
    [Máximo de épocas], [200],
    [Tamaño de mini-lote], [64],
    [Regularización L2], [1×10⁻⁴],
    [Umbral de gradiente], [1.0],
    [Paciencia de validación], [15 épocas],
    [Ventana de historia (_lookback_)], [168 h (7 días)],
    [Horizonte de predicción], [24 h],
    [Conjunto de entrenamiento], [2021--2023],
    [Conjunto de validación], [2024],
    [Conjunto de test], [2025],
    [RMSE de validación (escala normalizada)], [0,63358],
    [Época de parada], [29 de 200 (criterio de validación)],
  ),
  caption: [Hiperparámetros de entrenamiento del modelo LSTM de precio.],
) <tbl-hiper-precio>

El split temporal por años (en lugar de aleatorio) respeta la causalidad de la serie temporal: el modelo nunca ve datos del futuro durante el entrenamiento, y el test se realiza sobre el año más reciente disponible (2025), que no forma parte de la distribución de entrenamiento. El corte por año natural garantiza además que ninguna ventana de entrenamiento tenga su horizonte de predicción dentro del conjunto de validación; en el modelo solar, cuyo corte es proporcional y no por fecha, las últimas ventanas de cada conjunto sí solapan sus 24 h de horizonte con el conjunto siguiente (71 h de traslape en total), un efecto pequeño que se eliminaría descartando `ventana + horizonte` muestras en cada frontera. Esta práctica es la más rigurosa para evaluar modelos de predicción de precios de energía @weron2014electricity.

El entrenamiento se detiene por criterio de validación en la época 29 de 200, con un RMSE de validación de 0,63358 en la escala normalizada. La @fig-training-precio muestra que el error de validación desciende de forma sostenida hasta ese valor y se mantiene por debajo del de entrenamiento en todo momento, es decir, lo contrario del patrón que delata el sobreajuste.

#figure(
  image("../img/TrainingPrecio.png", width: 90%),
  caption: [Curva de entrenamiento del modelo LSTM de precio: evolución del error en entrenamiento y validación. La parada temprana (_early stopping_) se activa cuando la pérdida de validación no mejora durante 15 épocas consecutivas.],
) <fig-training-precio>

=== Resultados de validación

La @fig-lstm-precio muestra la predicción del modelo para tres días representativos del conjunto de test (2025), comparada con el precio real ENTSO-E.

#figure(
  image("../img/LSTM_Precio.png", width: 95%),
  caption: [Predicción LSTM de precio (línea roja) vs. precio real ENTSO-E (línea azul) para tres días del conjunto de test de 2025. La línea punteada representa el _baseline_ de persistencia lag-24 (precio de ayer a la misma hora).],
) <fig-lstm-precio>

La señal que finalmente consume la Versión B bate a la línea base, con un MAE de 18,47 €/MWh frente a los 19,77 de la persistencia de 24 horas, un skill del +6,6 %. Llegar hasta ahí, sin embargo, exige un diagnóstico previo, porque la salida cruda de la red no alcanza ese resultado por sí sola. Los tres apartados siguientes cubren qué mide la red frente a las líneas base, por qué se queda corta y cómo se corrige.

Como en el modelo solar, la evaluación no se apoya en un único número: el precio spot tiene una persistencia diaria muy fuerte, de modo que la referencia obligada (y exigida como mínimo por las guías de buenas prácticas del campo @lago2021benchmarking) es la persistencia _naïve_ a 24 horas —el precio de ayer a la misma hora— y, secundariamente, la persistencia semanal a 168 horas. Los tres predictores se evalúan sobre el mismo conjunto de test (2025, 8 736 horas, 209 664 pares horizonte-hora).

#figure(
  table(
    columns: (1.7fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Modelo*], [*MAE*], [*RMSE*], [*sMAPE*]),
    [Persistencia lag-24], [*19,77*], [28,50], [—],
    [Persistencia lag-168], [28,75], [40,30], [—],
    [LSTM (lazo abierto)], [21,17], [*27,94*], [58,5 %],
    [LSTM, horas con precio > 5 €/MWh], [22,05], [28,80], [37,8 %],
  ),
  caption: [Métricas del modelo LSTM de precio frente a las líneas base de persistencia, sobre el conjunto de test de 2025. MAE y RMSE en €/MWh.],
) <tbl-metricas-precio>

En el agregado de las 24 horas la red no alcanza a la persistencia de 24 horas en MAE: 21,17 frente a 19,77 €/MWh, un déficit del 7,1 %. Sí bate con holgura a la persistencia semanal, que queda un 45,4 % por detrás, pero ésa es una referencia débil. El único horizonte en el que la red gana es el primero: h+1 da un skill del +2,2 %, que se pierde ya al promediar el tramo h+1…h+6 (−2,9 %).

Hay, sin embargo, un matiz que el MAE no recoge: la red gana en RMSE, 27,94 frente a 28,50 €/MWh. Como el RMSE penaliza cuadráticamente los errores grandes, la lectura conjunta de ambas métricas es que la LSTM es peor en la hora típica pero mejor en las horas difíciles: evita los fallos gruesos que comete la persistencia cuando el perfil del día cambia respecto al anterior, a costa de acertar menos fino en los días tranquilos, que son la mayoría. Para un EMS que toma decisiones económicas, esa asimetría no es irrelevante —los errores caros son los grandes—, pero tampoco basta para declarar superior al modelo.

El sMAPE del 58,5 % debe interpretarse con cautela y se reporta por completitud: al ser una métrica relativa, se dispara en las horas de precio próximo a cero, cada vez más frecuentes con la penetración fotovoltaica. Restringiendo el cálculo a las horas con precio superior a 5 €/MWh baja al 37,8 %, que es la cifra interpretable.

#figure(
  image("../img/lstm_precio_MAEPorHorizon.png", width: 85%),
  caption: [Error MAE del modelo LSTM de precio por horizonte temporal (h+1 a h+24), comparado con las líneas base de persistencia lag-24 y lag-168.],
) <fig-mae-horizon-precio>

La @fig-mae-horizon-precio muestra un comportamiento muy distinto al del modelo solar. El error crece con el horizonte, pero muy poco: 19,38 €/MWh en h+1, 21,02 en h+6, 21,33 en h+12, 21,16 en h+18 y 22,66 en h+24, es decir un cociente h+24/h+1 de sólo 1,17. Frente al factor 1,9 del modelo solar, la curva es casi plana. Una curva plana no es aquí una virtud sino un indicio: sugiere que la red no está explotando la información reciente, y que su predicción a una hora es de calidad similar a la de un día.

El diagnóstico se confirma con el análisis de importancia de _features_, obtenido por permutación sobre el conjunto de test (incremento del MAE al barajar cada variable):

#figure(
  table(
    columns: (1fr, 1fr, 1fr, 1fr),
    align: (left, right, left, right),
    table.header([*Feature*], [*Δ MAE*], [*Feature*], [*Δ MAE*]),
    [`fv_allsky`], [*+3,59*], [`mes_sin`], [+0,79],
    [`hora_sin`], [+1,74], [`T2M`], [+0,43],
    [`dia_cos`], [+1,70], [`WS50M`], [+0,22],
    [`hora_cos`], [+1,61], [`precio_lag24`], [+0,14],
    [`ALLSKY`], [+1,55], [`precio_lag168`], [+0,13],
    [`dia_sin`], [+1,45], [`fv_norm`], [−0,00],
    [`mes_cos`], [+1,43], [], [],
  ),
  caption: [Importancia de las _features_ del modelo de precio por permutación, medida como incremento del MAE (€/MWh) al aleatorizar cada variable sobre el conjunto de test.],
) <tbl-importancia-precio>

La variable dominante es `fv_allsky`, el proxy de generación fotovoltaica, seguida del bloque de codificaciones cíclicas de hora, día de la semana y mes. Es decir: el modelo ha aprendido el perfil calendario-solar del precio, que explica buena parte de la varianza (la curva de "pato" que hunde el precio en las horas centrales del día), pero es exactamente la parte de la señal que la persistencia de 24 horas reproduce gratis.

Las dos últimas entradas de la tabla explican buena parte de lo anterior: `precio_lag24` y `precio_lag168` valen +0,14 y +0,13 €/MWh, es decir que la red apenas se apoya en los retardos de precio, pese a que el retardo de 24 horas por sí solo constituye la línea base que la supera. La información está disponible en la entrada; el modelo simplemente no la aprovecha. La explicación más plausible es que, con 168 pasos temporales y sólo dos de ellos portando el precio pasado en forma explícita, la señal de precio del buffer queda diluida frente a un bloque de variables deterministas que reducen la pérdida de entrenamiento más deprisa y de forma más estable. El modelo converge así a la componente más fácil de ajustar (el perfil medio del día) sin llegar a aprender la corrección de nivel que aportaría el precio de la jornada anterior.

La misma conclusión se alcanza desde la distribución de las predicciones. Sobre el test, el precio real tiene media 64,9 €/MWh y desviación típica 47,2, mientras que la predicción tiene media 61,0 y desviación típica 37,4: un cociente de dispersión de 0,79. La red está sistemáticamente subdispersa, aplana los extremos y regresa hacia la media, que es el comportamiento esperable de un modelo entrenado con error cuadrático sobre una serie de colas pesadas. Para el EMS esto tiene una consecuencia directa: las horas verdaderamente baratas se predicen menos baratas de lo que son, y las caras menos caras. Por tanto, la señal de precio predicho discrimina peor entre horas que el precio observado.

Queda por examinar el comportamiento sobre los cuatro días concretos de la campaña de simulación, que es el tramo más desfavorable del análisis:

#figure(
  table(
    columns: (1.9fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right),
    table.header([*Escenario*], [*MAE LSTM*], [*MAE lag-24*], [*Skill*]),
    [E1 · 2 jul., laborable soleado], [9,0], [11,0], [*+17,6 %*],
    [E2 · 11 feb., laborable nublado], [18,6], [8,9], [−109,0 %],
    [E3 · 13 jul., fin de semana soleado], [22,3], [12,8], [−74,2 %],
    [E4 · 17 sep., volatilidad], [26,0], [18,7], [−38,8 %],
  ),
  caption: [Error del modelo de precio en los cuatro escenarios de la campaña de simulación (@tbl-escenarios), frente a la persistencia de 24 horas. MAE en €/MWh.],
) <tbl-precio-campana>

#figure(
  image("../img/lstm_precio_PrediccionEnLosDiasDeLaCampana.png", width: 95%),
  caption: [Predicción del modelo de precio frente al precio real ENTSO-E en los cuatro días seleccionados para la campaña de simulación.],
) <fig-precio-campana>

El modelo sólo mejora a la línea base en E1 (el laborable soleado de precio plano, que es además el día en que la precisión importa menos) y queda por detrás en los otros tres, con un déficit que llega a duplicar el error de la línea base en E2. El caso más desfavorable es E4, el día de mayor diferencial de precio del año (24 → 252 €/MWh), que se eligió precisamente por ser aquel en el que `PrecioPred` tiene más margen para aportar: allí la red se queda un 38,8 % por detrás de repetir el precio de ayer. La @fig-precio-campana muestra por qué: en los días de perfil marcado la predicción reproduce la forma general pero aplana la amplitud, que es el mismo sesgo de subdispersión ya identificado en el agregado.

Este resultado se retiene explícitamente para la discusión del @cap-resultados: cualquier ventaja que la Versión B obtenga en esos escenarios no podrá atribuirse a la calidad de la previsión de precio. Es también el argumento que obliga a desplegar la señal combinada, y no la salida cruda de la red, en el modelo de Simulink.

=== Combinación con la línea base

Se aplica al modelo de precio el mismo tratamiento que al solar: una combinación convexa por horizonte con la línea base, con los pesos ajustados sobre el conjunto de validación (2024) y evaluada sobre test (2025).

$ hat(p)_"comb" (h) = w(h) dot hat(p)_"LSTM" (h) + (1 - w(h)) dot p_(t-24+h) $

Los pesos resultantes son mucho más planos que en el caso solar: parten de 0,74 en h+1 y descienden suavemente hasta 0,52 en h+24, sin llegar a anularse en ningún horizonte. La lectura es coherente con todo lo anterior: los dos predictores cometen errores poco correlacionados —la red captura el perfil calendario-solar, la persistencia captura el nivel del día— y ninguno domina al otro, que es justamente la situación en la que una combinación aporta más.

#figure(
  table(
    columns: (1.7fr, 1fr, 1fr),
    align: (left, right, right),
    table.header([*Señal*], [*MAE*], [*Skill vs. lag-24*]),
    [Persistencia lag-24], [19,77], [—],
    [LSTM sola], [21,17], [−7,1 %],
    [*Combinada*], [*18,47*], [*+6,6 %*],
  ),
  caption: [Efecto de la combinación convexa en el modelo de precio, sobre el conjunto de test. MAE en €/MWh.],
) <tbl-combinacion-precio>

La combinación recupera el resultado: 18,47 €/MWh frente a los 19,77 de la persistencia, un skill del +6,6 %, y un 12,8 % mejor que la red sola. La mejora se sostiene en todo el horizonte (16,69 €/MWh en h+1, 17,06 en h+2, 17,61 en h+3, 18,44 en h+6, 18,76 en h+12 y 19,11 en h+24), de modo que incluso el peor horizonte de la señal combinada bate a la línea base en su conjunto. Como en el modelo solar, el predictor que se despliega no es la salida cruda de la red, sino la mezcla.

=== Evaluación en lazo cerrado <sec-lazo-cerrado>

Todas las cifras anteriores son de lazo abierto: en cada instante se alimenta a la red con los 168 precios reales previos. La S-Function `lstm_precios.m`, en cambio, se despliega en lazo cerrado, realimentando su propia predicción a un paso. Para cuantificar esa discrepancia se ha replicado el mecanismo de realimentación sobre el conjunto de test, emulando el buffer autorregresivo de la S-Function.

#figure(
  table(
    columns: (1.4fr, 1fr),
    align: (left, right),
    table.header([*Horizonte*], [*Degradación del MAE*]),
    [h+1], [+0,0 %],
    [h+3], [−2,2 %],
    [h+6], [+13,6 %],
    [h+12], [+16,6 %],
    [h+18], [+32,6 %],
    [h+24], [*+74,2 %*],
    table.hline(),
    [*Agregado 24 h*], [*+27,7 %*],
  ),
  caption: [Degradación del modelo de precio al pasar de evaluación en lazo abierto a lazo cerrado con realimentación de la propia predicción. En el agregado, el MAE pasa de 21,65 a 27,64 €/MWh.],
) <tbl-lazo-cerrado>

El deterioro es severo y crece con el horizonte, como corresponde a la acumulación de error autorregresivo: nulo en la primera hora, del 13,6 % a las seis y del 74,2 % a las veinticuatro. En términos de skill frente a la persistencia, la red pasa de un −7,1 % en lazo abierto a un −39,8 % en lazo cerrado: el modelo tal como estaba desplegado era casi un 40 % peor que repetir el precio de ayer.

Esta medición es lo que justifica la corrección aplicada a `lstm_precios.m`, descrita en la sección siguiente: realimentar el buffer con el precio observado en lugar de con la predicción. La corrección es además la opción realista, porque un operador conoce el precio spot de las horas ya transcurridas (la casación del mercado diario se publica el día anterior), de modo que el lazo cerrado no representaba una limitación operativa sino un defecto de implementación.

=== Clamp de predicciones negativas <sec-clamp>

El mercado spot español opera dentro de los límites armonizados del acoplamiento diario europeo (SDAC), que desde el 10 de mayo de 2022 son \[-500, 4000\] €/MWh; los precios negativos son posibles pero infrecuentes (≤1% de las horas). Para evitar que el modelo genere predicciones aberrantes muy negativas en períodos con alta incertidumbre, se aplica un _clamp_ mínimo de −20 €/MWh en la inferencia: `Y_24 = max(-20, Y_24)`. Este umbral es conservador: admite precios negativos plausibles (excedentes renovables) pero descarta outliers extremos que podrían desestabilizar la lógica de control del EMS.

=== Integración en Simulink: S-Function `lstm_precios.m`

El modelo entrenado se guarda en `codigo/modelos/lstm_precio_luz.mat`. La S-Function `lstm_precios.m` recibe cuatro puertos de entrada: el vector de 3 features meteorológicas externas (ALLSKY, T2M, WS50M en valores crudos sin normalizar), el tiempo de simulación, el día del año (1--365) y el día de la semana (1=domingo, 7=sábado).

Internamente, la S-Function mantiene dos buffers circulares de 168 horas: uno para las features meteorológicas (`pr_buffer_weather`) y otro para la serie de precio (`pr_buffer_precio`). Este segundo buffer se inicializa con los precios reales de las 168 horas previas al día simulado. En la implementación heredada se realimentaba después con la propia predicción a un paso del modelo, en lugar de con el precio observado; el @sec-lazo-cerrado[apartado] cuantifica el coste de esa elección (un 27,7 % de MAE adicional, hasta un 74,2 % en h+24) y motiva la corrección aplicada: el buffer se actualiza ahora con el precio real de la hora transcurrida, tomado de la misma serie `precio_real_hour` que alimenta al modelo de Simulink, y sólo recurre a la predicción si esa muestra no está disponible. La operación sigue siendo estrictamente causal, porque el precio que se inserta corresponde a una hora ya pasada. En cada nueva hora, reconstruye la matriz de 14 features × 168 pasos temporales aplicando las codificaciones cíclicas y los lags de precio, llama a `predict()` y actualiza la predicción de las próximas 24 horas. Las features meteorológicas de la historia se leen de `features_precio`, pre-cargado en el workspace base por `init_OASIS.m`.

Igual que en el modelo solar, lo que sale del bloque no es la predicción cruda sino la señal combinada: sobre el vector de 24 horas se aplica la mezcla convexa con la persistencia de 24 h descrita en el apartado anterior. La línea base sale gratis, porque el precio de referencia $p_(t-24+h)$ se lee de la serie `precio_real_hour` —no del _buffer_ autorregresivo—, y corresponde en todos los casos a horas ya transcurridas. Los pesos se cargan de `w_combi_precio`, añadido al `.mat` del modelo por el script de entrenamiento, y en su ausencia la S-Function emite la salida cruda.

== Comparación de los dos modelos

#figure(
  table(
    columns: (1.5fr, 1fr, 1fr),
    align: (left, left, left),
    table.header([*Característica*], [*LSTM Solar*], [*LSTM Precio*]),
    [Variable objetivo], [ALLSKY (Wh/m²)], [Precio spot (€/MWh)],
    [Features de entrada], [8], [14],
    [Ventana de historia], [48 h], [168 h (7 días)],
    [Horizonte de predicción], [24 h], [24 h],
    [Capas LSTM (unidades)], [128 + 64], [128 + 64],
    [Dropout], [20%], [30%],
    [Normalización objetivo], [Min-Max], [Z-score],
    [Datos de entrenamiento], [NASA POWER (2007--2025)], [ENTSO-E + NASA (2021--2025)],
    [Split train/val/test], [80%/10%/10% cronológico], [2021-23 / 2024 / 2025],
    [Época máxima], [300], [200],
    [Regularización], [Dropout], [Dropout + L2 (1e-4)],
    [Archivo guardado], [`lstm_solar_sevilla.mat`], [`lstm_precio_luz.mat`],
    [S-Function], [`lstm_sol.m`], [`lstm_precios.m`],
    table.hline(),
    [Línea base de referencia], [Persistencia de cielo claro], [Persistencia lag-24],
    [Skill de la red sola (24 h)], [−8,8 %], [−7,1 %],
    [Skill de la señal combinada], [+5,8 %], [+6,6 %],
    [Peso de la LSTM en h+1 → h+24], [0,92 → 0,48], [0,74 → 0,52],
  ),
  caption: [Comparación de características y resultados de los dos modelos LSTM desarrollados.],
) <tbl-comparacion-lstm>

La elección de una ventana de historia de 168 h para el modelo de precio (frente a 48 h para el solar) responde a la naturaleza del fenómeno: la irradiancia solar en Sevilla tiene patrones diarios muy regulares que se capturan bien con 2 días de historia, mientras que el precio de la electricidad requiere ver al menos 7 días para capturar el ciclo semanal completo (diferencia entre laborables y festivos).

Las cuatro últimas filas de la @tbl-comparacion-lstm dan el mismo resultado en los dos modelos pese a tratarse de fenómenos y líneas base completamente distintos: ninguna de las dos redes bate por sí sola a su línea base trivial en el agregado de 24 horas, y ambas lo hacen (con márgenes muy parecidos, +5,8 % y +6,6 %) una vez combinadas con ella. La diferencia está en el perfil de los pesos. En el modelo solar caen a cero en el tramo central del horizonte, porque la geometría solar es determinista y la red no tiene nada que añadir sobre la envolvente de cielo claro más allá de las primeras horas. En el modelo de precio se mantienen en torno a 0,5 en todo el horizonte, porque los dos predictores capturan partes distintas de la señal —el perfil calendario-solar la red, el nivel del día la persistencia— y ninguno domina.

Al leer las dos filas de _skill_ de la @tbl-comparacion-lstm debe tenerse presente que las dos líneas base no son igual de exigentes, de modo que el −8,8 % y el −7,1 % no son cifras directamente comparables. La persistencia de cielo claro separa las dos componentes de la irradiancia (la determinista, contenida en CLRSKY y conocida con exactitud para cualquier instante futuro, y la estocástica, resumida en el índice $k_t$) y persiste únicamente la segunda. La persistencia lag-24, en cambio, arrastra a la vez la geometría solar de ayer y la nubosidad de ayer adherida a las horas de reloj de ayer, con lo que hereda dos fuentes de error en lugar de una. El precio spot no admite una construcción equivalente, porque no existe una envolvente física del precio calculable de antemano; en su caso la persistencia de 24 horas es la referencia más fuerte disponible.

La consecuencia es que, medido contra la persistencia lag-24 (que es el análogo exacto de la línea base del modelo de precio), el modelo solar sí mejora a la referencia, y en un 10,1 %: 30,19 frente a 33,59 Wh/m² (@tbl-baseline-solar). El déficit del 8,8 % se produce frente a la línea base más dura de las dos, que es la que la literatura de predicción de irradiancia considera correcta y la que se adopta aquí por ese motivo. La elección no es inocua: reportar únicamente la lag-24 habría permitido presentar el modelo solar con un _skill_ positivo del 10 % sin haber cambiado nada del modelo, y habría hecho al mismo tiempo irrelevante el +5,8 % de la señal combinada, porque batir una referencia débil no demuestra gran cosa.

De aquí se sigue una conclusión metodológica que se traslada al diseño de la Versión B: el valor de la predicción no está en sustituir a la línea base, sino en complementarla.

Conviene por ello fijar la terminología que se emplea en el resto del trabajo, porque la distinción es la que sostiene todo el capítulo. Se llama *red sola* a la salida directa de la LSTM, y *señal combinada* a la mezcla convexa de esa salida con la línea base correspondiente, horizonte a horizonte y con los pesos ajustados sobre validación. La red sola es un objeto intermedio del análisis: aparece en la evaluación porque es lo que permite medir cuánto aporta la red por encima de una regla trivial, pero no es lo que se despliega. Lo que las dos S-Functions entregan al EMS, y por tanto lo único que la Versión B llega a consumir, es la señal combinada.

== Limitaciones de los modelos

Los dos modelos presentan limitaciones que deben tenerse en cuenta al interpretar los resultados de la simulación:

En primer lugar, ninguno de los modelos incorpora información de predicción meteorológica NWP (_Numerical Weather Prediction_), sino que usa datos históricos observados. En un sistema real, la predicción solar se obtendría de una fuente NWP (ECMWF, AEMET) en lugar de datos pasados. Ambos modelos operan, no obstante, de forma estrictamente causal durante la simulación: las S-Functions mantienen una ventana móvil de observaciones pasadas (48 h en el modelo solar, 168 h en el de precio) e insertan en cada paso únicamente la muestra del instante actual, sin acceso a valores futuros. El hecho de que las variables meteorológicas provengan del año de test no supone por tanto disponer de una predicción meteorológica, sino evaluar sobre datos no vistos en el entrenamiento.

Sí existe, en cambio, una limitación de disponibilidad del dato: la irradiancia `ALLSKY` procede del reanálisis satelital CERES distribuido por NASA POWER, que se publica con varios días de retraso. Un sistema real no dispondría del valor de la última hora observada y tendría que sustituirlo por una medida local (piranómetro) o por una previsión NWP, cada una con su propia distribución de error. La transferencia del modelo a una instalación real exigiría por tanto reentrenarlo con la fuente de datos disponible en tiempo real.

En segundo lugar, y de forma más sutil, la evaluación de los modelos y su despliegue no ocurren en el mismo régimen. Ambas redes se entrenan con la entrada real en la ventana de historia (_teacher forcing_), pero la S-Function del precio operaba realimentando su propia predicción, lo que produce el fenómeno conocido como _exposure bias_: el error se acumula a lo largo del día y el rendimiento medido en lazo abierto sobrestima el que el EMS experimenta realmente. El @sec-lazo-cerrado[apartado] cuantifica esa brecha y describe la corrección adoptada. Queda como limitación residual que la corrección depende de disponer del precio observado de la hora anterior, algo que en la simulación se garantiza por construcción y que en una instalación real exige una conexión fiable a la publicación de la casación diaria.

En tercer lugar, el modelo de precio tiene dificultades en episodios extremos: precios muy negativos (curtailment masivo), picos superiores a 200 €/MWh (tensiones de gas) o cambios regulatorios bruscos. Estos eventos son inherentemente difíciles de predecir con modelos estadísticos y suelen requerir la incorporación de variables fundamentales de mercado no disponibles en los datasets públicos utilizados.

En cuarto lugar, ambos modelos se entrenan con datos de España y Sevilla, respectivamente. Una implantación de la estación OASIS en otra ubicación requeriría re-entrenar con datos de esa región.
