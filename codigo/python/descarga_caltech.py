"""
Baja de la API de Caltech las sesiones de carga de su aparcamiento y las deja en
un CSV. Son cargas lentas, de unos 6,6 kW, y sirven para comparar con las de
carga rapida de la EPFL. Pide el token por consola, que hay que sacarlo
registrandose en ev.caltech.edu. Necesita requests y pandas.
"""

import os
import requests
import pandas as pd

# Configuracion: credenciales, emplazamiento y rango de fechas
TOKEN = input("Introduce tu token de Caltech (ev.caltech.edu): ").strip()
if not TOKEN:
    print("ERROR: No se introdujo token. Regístrate en https://ev.caltech.edu/register")
    exit(1)
SITE = "caltech"                  # 'caltech', 'jpl' o 'office001'
FECHA_DESDE = "Wed, 1 Jan 2020 00:00:00 GMT"
FECHA_HASTA = "Thu, 1 Jan 2021 00:00:00 GMT"

# carpeta de destino
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEST_DIR = os.path.join(SCRIPT_DIR, "..", "data", "caltech")
os.makedirs(DEST_DIR, exist_ok=True)

BASE_URL = f"https://ev.caltech.edu/api/v1/sessions/{SITE}"

# url de la primera pagina
params = {}
if FECHA_DESDE and FECHA_HASTA:
    where_clause = f'connectionTime>="{FECHA_DESDE}" and connectionTime<="{FECHA_HASTA}"'
    params["where"] = where_clause

# descarga pagina a pagina
sesiones = []
url = BASE_URL
auth = (TOKEN, "")

page = 1
while url:
    resp = requests.get(url, params=params if page == 1 else None, auth=auth)
    resp.raise_for_status()
    data = resp.json()

    items = data.get("_items", data.get("items", []))
    sesiones.extend(items)
    print(f"Página {page}: {len(items)} sesiones (total acumulado: {len(sesiones)})")

    links = data.get("_links", {})
    next_link = links.get("next")
    if next_link:
        href = next_link["href"]
        if href.startswith("/"):
            url = "https://ev.caltech.edu/api/v1" + href
        else:
            url = "https://ev.caltech.edu/api/v1/" + href
        params = None
        page += 1
    else:
        url = None

print(f"\nTotal de sesiones descargadas: {len(sesiones)}")

# paso a tabla y limpieza
df = pd.json_normalize(sesiones)

cols_interes = [c for c in [
    "_id", "connectionTime", "disconnectTime", "doneChargingTime",
    "kWhDelivered", "siteID", "spaceID", "stationID", "userID"
] if c in df.columns]

df = df[cols_interes]

for col in ["connectionTime", "disconnectTime", "doneChargingTime"]:
    if col in df.columns:
        df[col] = pd.to_datetime(df[col], errors="coerce", utc=True)

if "connectionTime" in df.columns and "disconnectTime" in df.columns:
    df["duracion_horas"] = (df["disconnectTime"] - df["connectionTime"]).dt.total_seconds() / 3600

df = df.dropna(subset=["connectionTime", "disconnectTime", "kWhDelivered"])
df = df[df["kWhDelivered"] > 0.5]

# guardado en CSV
output_path = os.path.join(DEST_DIR, "acndata_caltech.csv")
df.to_csv(output_path, index=False)
print(f"\nGuardado en: {output_path}")
print(f"Sesiones válidas: {len(df)}")
print(df.head())
