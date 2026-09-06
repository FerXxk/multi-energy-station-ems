# Aviso de licencias y material de terceros

Este repositorio es el anexo del Trabajo Fin de Grado *OASIS — Gestión energética
de una estación de repostaje multi-energía* (Fernando Román Hidalgo, Universidad
de Sevilla, 2026). Reúne obra propia y material de terceros, y cada parte se rige
por su licencia.

## Obra propia

| Parte | Licencia |
|---|---|
| `codigo/` — EMS, herramientas, preparación, entrenamiento y scripts de Python | MIT — ver [LICENSE](LICENSE) |
| `SimugridElectrolinera/OASIS.slx`, `init_OASIS.m`, `lstm_*.m` — modelo Simulink y S-Functions, montados sobre la librería pública Simugrid | MIT |
| `codigo/resultados/` — CSV de la campaña reportada | MIT |
| `memoria/capitulos/`, `memoria/main.typ`, `memoria/main.pdf`, `memoria/bibliografia/` | CC BY 4.0 — ver [LICENSE-DOCS](LICENSE-DOCS) |
| Figuras originales del autor en `memoria/img/` y `codigo/data/**/figuras/` | CC BY 4.0 |

## Material de terceros

Lo siguiente **no** está cubierto por las licencias anteriores. Se incluye para
que el trabajo sea reproducible, conservando la titularidad de sus autores.

| Parte | Titular | Condiciones |
|---|---|---|
| `memoria/template/lib.typ` | [aleokdev/plantilla-tfg-etsi-us](https://github.com/aleokdev/plantilla-tfg-etsi-us) | Plantilla de TFG de la ETSI reescrita en Typst, adaptada para este trabajo y **usada con permiso de su autor**. El repositorio de origen no declara licencia; para reutilizarla fuera de este trabajo, conviene pedírsela a él. |
| `memoria/template/figures/` (`Logo.svg`, `US-marca-principal.png`, `edificio01.png`) | Universidad de Sevilla | Identidad corporativa de la US. Su uso está limitado a documentos académicos de la Universidad; la marca no se licencia con este repositorio. |
| `SimugridElectrolinera/Imagenes/` | Diversos | Iconos y fotografías de equipos empleados en el diagrama del modelo. Se usan únicamente con fines ilustrativos y académicos. |
| `codigo/data/entsoe/` | ENTSO-E Transparency Platform | Reutilización permitida bajo los términos y condiciones de la plataforma, con atribución expresa a ENTSO-E. |
| `codigo/data/NASA/` | NASA POWER (Langley Research Center) | Datos de acceso libre. La NASA solicita citar el proyecto POWER en los trabajos que los empleen. |
| `codigo/data/desl_epfl/` | DESL-EPFL, *Level-3 EV charging dataset* | Licencia MIT del conjunto de datos original. |
| `codigo/data/caltech/acndata_caltech.csv` | Caltech ACN-Data | Datos obtenidos a través de su API bajo los términos de uso de ACN-Data, que exigen citar la publicación original. |
| `codigo/modelos/*.mat` | Obra propia, entrenada sobre los datos anteriores | MIT, sujeto a las condiciones de las fuentes de datos con las que se entrenaron. |

## Citas de las fuentes de datos

- **NASA POWER**: NASA Langley Research Center (LaRC) POWER Project. https://power.larc.nasa.gov/
- **ENTSO-E**: ENTSO-E Transparency Platform. https://transparency.entsoe.eu/
- **DESL-EPFL**: https://github.com/DESL-EPFL/Level-3-EV-charging-dataset
- **Caltech ACN-Data**: Lee, Z. J., Li, T., Low, S. H. *ACN-Data: Analysis and Applications of an Open EV Charging Dataset*. e-Energy, 2019. https://ev.caltech.edu/

Si eres titular de alguno de los materiales listados y quieres que se retire o se
cite de otro modo, abre una incidencia en el repositorio.
