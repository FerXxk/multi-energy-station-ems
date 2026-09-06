// La URL del repositorio se define aquí una sola vez.
#let url-repo = "https://github.com/FerXxk/multi-energy-station-ems"

= Anexo: código y datos del trabajo <cap-anexo>

Todo el material necesario para reproducir este trabajo está publicado en

#align(center)[#link(url-repo)[#raw(url-repo)]]

y no se adjunta impreso. El repositorio contiene el modelo de Simulink, los EMS comparados, los dos modelos LSTM ya entrenados, los datos de entrada, los CSV con los indicadores de todas las simulaciones de la campaña y la fuente de esta memoria.

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header([*Carpeta*], [*Contenido*]),
    [`SimugridElectrolinera/`],
    [El modelo `OASIS.slx`, su script de preparación `init_OASIS.m` y las dos S-Functions de previsión, `lstm_sol.m` y `lstm_precios.m`.],

    [`codigo/EMS/`],
    [Las Versiones A, B y C del EMS, más C0. Cada una es el archivo que se pega en el bloque `MATLAB Function` del modelo. La constante `H2_PRECIO_EXT_KG` viene a los 8 €/kg de la campaña que se reporta; a 6,12 €/kg se obtiene la de sensibilidad.],

    [`codigo/herramientas/`],
    [La campaña de simulación, el cálculo de indicadores, el contraste pareado, la descomposición de la importación y la generación de las figuras del @cap-resultados.],

    [`codigo/preparar/`],
    [Generación del perfil estocástico de demanda y construcción del _workspace_ de Simulink a partir de los datos.],

    [`codigo/entrenar/`], [Entrenamiento de los dos modelos LSTM del @cap-lstm.],
    [`codigo/modelos/`], [Los dos modelos ya entrenados que consumen las S-Functions.],
    [`codigo/python/`],
    [Descarga y análisis de los datos de NASA POWER, ENTSO-E, DESL-EPFL y Caltech, y las figuras del @cap-datos-ev.],

    [`codigo/data/`], [Los datos descargados y procesados que alimentan la simulación.],
    [`codigo/resultados/`],
    [Los CSV con los indicadores de todas las simulaciones y sus agregados, de los que salen las tablas y las figuras del @cap-resultados.],

    [`memoria/`], [La fuente de este documento.],
  ),
  caption: [Contenido del repositorio del trabajo.],
) <tbl-anexo-repo>

El fichero `README.md` de la raíz detalla la secuencia completa de reproducción: qué scripts regeneran los datos y los modelos, qué EMS corresponde a cada tanda de la campaña con qué semillas y qué horizonte, y qué funciones producen las tablas y las figuras. No se versionan los `.mat` de resultados ni los perfiles de demanda, porque son regenerables: el generador de tráfico es determinista dada su semilla, y los CSV incluidos llevan todos los indicadores que se citan en la memoria.
