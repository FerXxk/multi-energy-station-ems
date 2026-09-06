#import "template/lib.typ": first-letter, index, main-content, post-content, pre-content, tfg_etsi_us_template

#set text(font: ("Times New Roman", "Liberation Serif", "New Computer Modern", "serif"))

#show: tfg_etsi_us_template.with(
  // El título del TFG
  "Estrategias de gestión energética para una estación de repostaje multi-energía: cuantificación de la mejora aportada por la predicción con redes LSTM",
  // El grado de la titulación, e.g. Ingeniería Industrial
  "Grado en Ingeniería Electrónica, Robótica y Mecatrónica",
  // Nombre y apellidos del autor
  "Fernando Román Hidalgo",
  // Nombre y apellidos del tutor (o tutores)
  "Miguel Ángel Ridao Carlini",
  // Título del tutor, p.ej. Profesor Asociado
  "CATEDRÁTICO DE UNIVERSIDAD",
  // Nombre del departamento asociado
  "Dpto. de Ingeniería de Sistemas y Automática",
  // Año del TFG (Por defecto el año de compilación del archivo)
  // year: 2026
)

#pre-content[
  // El contenido de aquí usa numeración romana de páginas y los títulos
  // definidos no están numerados. Usado para índice, agradecimientos,
  // introducción, abstracto/resumen, ...

  = Agradecimientos
  Decía el tío Ben que «un gran poder conlleva una gran responsabilidad». Durante este último tiempo, al estar ya inmerso en el mundo laboral, reconozco que la tentación de dejar este trabajo de lado y pasar página ha estado muy presente. Sin embargo, he sentido la responsabilidad de terminar lo que empecé y cerrar esta etapa académica como se merece. No solo por mí, sino por el deber de honrar a todas las personas que han estado a mi lado. Por eso, este trabajo no es solo mío, sino de todos los que me han acompañado en el proceso.

  En primer lugar, quiero expresar mi más sincero agradecimiento a mi tutor, Miguel Ángel, por su paciencia, su plena disponibilidad y su intachable profesionalidad a la hora de guiarme.

  A mis padres, por su apoyo incondicional desde el primer día. Gracias por confiar siempre en mí y por haberme inculcado el valor de no conformarme nunca. Si he llegado hasta aquí, es gracias a lo que me habéis enseñado.

  A mis amigos de la universidad, por compartir el gusto de aprender riendo. Gracias a vosotros, cada paso dado en esta carrera no se ha sentido como una obligación, sino como una experiencia que ha merecido la pena.

  A mis amigos de siempre, por obligarme a levantar la vista de la pantalla y ser ese soplo de aire fresco y necesario cuando uno solo necesita despejarse y desconectar.

  Y a mi pareja, mi mayor punto de apoyo durante toda esta etapa universitaria. Has sido mi refugio y mi motivación en esos momentos en los que las fuerzas escaseaban; sé de sobra que, sin tu aliento, este trabajo todavía seguiría en el tintero.

  A todos, gracias por acompañarme hasta la meta.

  = Resumen
  La descarbonización del transporte por carretera exige infraestructuras de repostaje capaces de dar servicio simultáneamente a vehículos eléctricos de batería y a vehículos de pila de combustible, integrando además la generación renovable local. Este trabajo aborda el modelado y la simulación en MATLAB/Simulink de OASIS, una microrred multi-energía que combina generación fotovoltaica, almacenamiento eléctrico (BESS), un electrolizador PEM con almacenamiento de hidrógeno en dos etapas de presión (tanque de baja y de alta, con compresor intermedio), una pila de combustible y dos cargadores rápidos de vehículo eléctrico, todo ello coordinado por un Sistema de Gestión de Energía (EMS).

  Partiendo de un EMS heurístico de referencia adaptado de un trabajo previo del grupo de investigación, se entrenan y validan dos modelos de red neuronal LSTM —irradiancia solar y precio spot de la electricidad a 24 horas— y se estudia cómo incorporarlos a la gestión. Inyectadas en las reglas de la heurística, las previsiones no reducen el coste ni siquiera con información perfecta, aunque sí mejoran de forma sistemática la seguridad del suministro de hidrógeno. La cadena de medida construida para demostrarlo (comparación pareada por semilla, oráculo, descomposición de la importación por destinos y ablación por componentes) localiza en cambio el margen real: la heurística compraba a la red la mayor parte de la energía del electrolizador con la batería casi llena. La versión final del EMS hace que la batería alimente al electrolizador antes que la red y programa la producción de hidrógeno sobre el precio publicado del mercado diario, y reduce el coste semanal un 14 % en los veinte casos evaluados. Añadirle la previsión LSTM de precio no cambia ningún resultado, porque la información que la decisión necesita ya está publicada; la previsión aporta donde hay incertidumbre real, que es el suministro de hidrógeno en los días de poca irradiancia.

  El trabajo entrega, por tanto, la herramienta de simulación y comparación de estrategias, los dos modelos de predicción validados frente a líneas base no triviales, y la evidencia cuantitativa de qué parte de la mejora de un EMS predictivo es atribuible a la predicción y qué parte al diseño de las reglas que la consumen.

  *Palabras clave:* microrred multi-energía, sistema de gestión de energía (EMS), hidrógeno verde, electrolizador PEM, pila de combustible, LSTM, vehículo eléctrico, MATLAB/Simulink.

  = Abstract
  Decarbonizing road transport requires refueling infrastructure able to serve battery electric vehicles and fuel-cell electric vehicles simultaneously, while integrating local renewable generation. This thesis addresses the modeling and simulation, in MATLAB/Simulink, of OASIS, a multi-energy microgrid that combines photovoltaic generation, electrical storage (BESS), a PEM electrolyzer with two-stage hydrogen storage (low- and high-pressure tanks linked by a compressor), a fuel cell, and two fast electric-vehicle chargers, all coordinated by an Energy Management System (EMS).

  Starting from a heuristic reference EMS adapted from prior work by the research group, two LSTM neural network models are trained and validated —solar irradiance and day-ahead electricity price over a 24-hour horizon— and their integration into the management logic is studied. Injected into the heuristic's rules, the forecasts do not reduce cost even with perfect information, although they consistently improve the security of hydrogen supply. The measurement chain built to demonstrate this (seed-paired comparison, oracle runs, decomposition of grid imports by destination and component-wise ablation) instead locates the real margin: the heuristic bought most of the electrolyzer's energy from the grid while the battery was nearly full. The final EMS lets the battery feed the electrolyzer before the grid does, and schedules hydrogen production on the published day-ahead price, reducing the weekly cost by 14 % in all twenty evaluated cases. Adding the LSTM price forecast changes no result, because the information the decision needs is already published; forecasting adds value where genuine uncertainty remains, namely hydrogen supply on low-irradiance days.

  The thesis therefore delivers the simulation and comparison framework, the two forecasting models validated against non-trivial baselines, and quantitative evidence of how much of a predictive EMS's improvement is attributable to the forecast and how much to the design of the rules that consume it.

  *Keywords:* multi-energy microgrid, energy management system (EMS), green hydrogen, PEM electrolyzer, fuel cell, LSTM, electric vehicle, MATLAB/Simulink.

  // Índices
  #index(title: [Índice General], target: heading)

  = Nota sobre el uso de herramientas de Inteligencia Artificial

  Durante el desarrollo de este trabajo se han empleado de manera complementaria herramientas de Inteligencia Artificial generativa como apoyo en tareas de optimización de redacción, organización y estructura de contenidos, así como en la consulta bibliográfica preliminar y en el soporte puntual para la depuración de scripts de MATLAB orientados a la generación de figuras y tablas. En todo caso, la formulación de los objetivos, la toma de decisiones metodológicas, el diseño de los sistemas de gestión energética (EMS), la validación de los modelos y la interpretación de los resultados han sido llevados a cabo de forma autónoma por el autor, quien asume la plena responsabilidad de la autoría intelectual del contenido de esta memoria.
]

#main-content[
  // Las páginas de aquí junto a los títulos definidos usan numeración arábiga
  // comenzando desde 1. Usado para el contenido principal del TFG

  #include "capitulos/introduccion.typ"

  #include "capitulos/estadoarte.typ"

  #include "capitulos/datos_ev.typ"

  #include "capitulos/lstm.typ"

  #include "capitulos/metodologia.typ"

  #include "capitulos/resultados.typ"

  #include "capitulos/conclusiones.typ"

  #include "capitulos/anexo.typ"

]

#post-content[
  // El contenido de aquí continúa con la numeración de páginas anterior, pero
  // los títulos definidos no están numerados. Usado para glosario,
  // bibliografía, índice de figuras...

  #index(title: [Índice de Figuras], target: (figure.where(kind: image)))

  #index(title: [Índice de Tablas], target: (figure.where(kind: table)))

  #bibliography("bibliografia/referencias.bib", style: "ieee", title: [Bibliografía])
]
