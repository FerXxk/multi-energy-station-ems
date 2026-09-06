"""
Baja del repositorio de la EPFL los dos ficheros del conjunto de datos de carga
rapida, el de sesiones y el de medidas, y los deja en codigo/data/desl_epfl.
Necesita requests.
"""

import os
import requests

# Configuracion: repositorio y ficheros a descargar
REPO_URL = "https://github.com/DESL-EPFL/Level-3-EV-charging-dataset"
RAW_BASE = "https://raw.githubusercontent.com/DESL-EPFL/Level-3-EV-charging-dataset/main"

ARCHIVOS = {
    "Session_data.xlsx": f"{RAW_BASE}/Session_data.xlsx",
    "Measurement_data.xlsx": f"{RAW_BASE}/Measurement_data.xlsx",
}

# carpeta de destino
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEST_DIR = os.path.join(SCRIPT_DIR, "..", "data", "desl_epfl")

# descarga de los ficheros
os.makedirs(DEST_DIR, exist_ok=True)

for nombre, url in ARCHIVOS.items():
    destino = os.path.join(DEST_DIR, nombre)
    if os.path.exists(destino):
        print(f"[SKIP] {nombre} ya existe en {destino}")
        continue

    print(f"Descargando {nombre}...")
    resp = requests.get(url, timeout=120)
    resp.raise_for_status()

    with open(destino, "wb") as f:
        f.write(resp.content)

    size_mb = len(resp.content) / (1024 * 1024)
    print(f"  Guardado: {destino} ({size_mb:.1f} MB)")

print(f"\nDescarga completada. Archivos en: {DEST_DIR}")
