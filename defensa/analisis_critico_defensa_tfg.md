# Análisis crítico y defensa del TFG: Estrategias de gestión energética

Este documento recopila el análisis crítico, las posibles objeciones del tribunal, los puntos débiles y las estrategias de defensa para la exposición del Trabajo Fin de Grado de **Fernando Román Hidalgo**, titulado *«Estrategias de gestión energética para una estación de repostaje multi-energía: cuantificación de la mejora aportada por la predicción con redes LSTM»*.

---

## Veredicto Global

El trabajo es **impecable, riguroso y metodológicamente muy sólido**. Demuestra un nivel de madurez sobresaliente para un TFG: no te limitas a «enchufar» una red neuronal a Simulink, sino que analizas los resultados críticamente, detectas por qué las redes fallan solas, corriges errores de lazo cerrado, haces pruebas estadísticas correctas (Wilcoxon) y, lo más importante, **haces una atribución causal pieza a pieza** que demuestra qué aporta valor y qué es puramente accesorio.

No obstante, un tribunal de ingeniería (y más en automático y sistemas) va a buscar las costuras. A continuación se detallan las principales pegas, puntos débiles y trampas preparadas.

---

## 1. El talón de Aquiles técnico: El modelo de precios y el "0,00 €"

* **La pega:** En la diapositiva 17 demuestras que añadir la red LSTM de precios ahorra exactamente **0,00 €** porque el mercado diario publica los precios a las 13:00 (cubriendo gran parte del horizonte). 
* **Por dónde te pueden atacar:** Un tribunal malicioso te dirá: *"Entonces, ¿para qué has entrenado una LSTM de precios durante todo el TFG? ¿No es un esfuerzo desperdiciado o un fallo de diseño al plantear el horizonte temporal?"*
* **Cómo defenderlo:** Demostrar científicamente que una técnica compleja (LSTM) no aporta valor frente a la información pública disponible es un resultado negativo pero de un valor científico incalculable. En investigación, demostrar que algo *no* sirve y explicar mecánicamente por qué (gracias a la hora de publicación del mercado diario) es tan válido como demostrar que sirve. Además, justifica la Versión B y C.

---

## 2. Trampas físicas y de modelado (Las que más duelen)

### A. Pila de combustible inactiva (Diapositiva 18)
* **La pega:** *"¿Cómo validas un sistema multi-energía si uno de los vectores principales (la pila de combustible) no llega a arrancar en ninguna simulación?"*
* **Defensa:** Tienes la respuesta técnica preparada en las notas (curva de polarización, 11 kW reales frente a los 130 kW nominales de diseño). El sistema opera en modo red/batería/electrolizador, lo cual es realista para microrredes conectadas, pero debes reconocer con naturalidad que el "modo isla" completo queda como asignatura pendiente.

### B. Gas ideal a 600 bares (Diapositiva 18)
* **La pega:** *"Asumir gas ideal a 600 bares subestima masivamente el factor de compresibilidad ($Z$). Tu masa de hidrógeno almacenada está sobreestimada un 45%. ¿Hasta qué punto esto invalida las dinámicas del tanque?"*
* **Defensa:** Las cifras son comparativas (todas las versiones sufren la misma simplificación matemática). Los del 45% lo sabes tú porque has hecho el análisis de limitaciones; si te lo sacan, demuestras que conoces las tripas de tu modelo termodinámico.

---

## 3. El "truco" de la Batería en la Versión C (El ahorro del 13,9%)

* **La pega:** El gran titular de tu TFG es que la Versión C ahorra un 13,9%. Pero si miras de dónde viene el ahorro (Diapositiva 17), **el 90% (47,1 € de 52,3 €) se debe puramente al Cambio 1** (ofrecer la carga del electrolizador a la batería antes que a la red, manteniendo un SOC > 60%), **¡que no usa ninguna previsión ni red neuronal!**
* **Por dónde te pueden atacar:** *"Fernando, estás vendiendo un TFG titulado 'cuantificación de la mejora aportada por la predicción LSTM', y resulta que el 90% del ahorro lo consigues con una regla estática de lógica de carril (el SOC al 60%) que no requiere inteligencia artificial para nada."*
* **Cómo defenderlo:** Esta es **la crítica más peligrosa** que te pueden hacer. Asúmela con elegancia: *"Exacto. Y esa es la conclusión más honesta del trabajo. La IA (las LSTM) por sí sola no arregla una mala política de gestión de flujos energéticos. Primero hay que estructurar correctamente los grados de libertad físicos del sistema (batería como tampón del electrolizador). La predicción solo aporta valor marginal cuando la base está bien armada"* (de ahí que la Versión B mejorara el servicio de hidrógeno y la C optimice los flujos).

---

## 4. Detalles de formato y presentación en las transparencias

* **Gráficas de entrenamiento (Diapositivas 6 y 7):** Las capturas de pantalla de MATLAB de *Training Progress* (con letras diminutas, barras grises y tipografía por defecto) quedan muy "de estar por casa". Un tribunal exigente te puede decir que no se lee nada. Como ya es tarde para rediseñarlas, asegúrate de explicar verbalmente lo importante: *"Como se aprecia en la miniatura, la curva converge sin sobreajuste gracias al early stopping en la época X"*, sin intentar que lean los ejes.
* **El volumen de texto en la diapositiva 15 (Versión C):** Tiene muchísima letra y diagramas de bloques complejos. Es un esquema muy de memoria o de documento Word más que de diapositiva de defensa. Si te preguntan por esa lógica, remítete al esquema general, pero ve con la lección aprendida de explicarlo con tus palabras pausadamente.

---

## Consejos clave para el día D

1. **Destaca tus aciertos metodológicos:** Los anclajes como el test de Wilcoxon en lugar del t-test para evitar sesgos de 3 semillas extremas, el pareado por semilla para eliminar ruido estocástico, y el umbral de relevancia económica de 9,33 €/semana demuestran rigor de ingeniero doctorando, no de alumno de último año de grado.
2. **No te pongas a la defensiva:** Cuando te arrastren hacia la "inutilidad" de la red de precio (el 0,00 €) o a que el mérito es de la regla del 60% de la batería y no de la LSTM, asúmelo como un triunfo de tu rigor científico: *"Precisamente por eso este TFG aporta luz frente al 'hype' de meter redes neuronales a todo: demuestro matemáticamente dónde la IA sí es útil (servicio de hidrógeno en B) y dónde es redundante frente a la información pública del mercado"*. Con eso los dejas desarmados.
