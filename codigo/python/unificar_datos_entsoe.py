"""
Junta los cuatro CSV que deja descargar_entsoe.py (precio, demanda, solar y
eolica) en una sola tabla horaria, que es la que leen despues el entrenamiento de
la red de precio y la preparacion del workspace de Simulink. Se guarda como
codigo/data/entsoe/datos_entsoe_unificado_2021_2025.csv.
"""

import pandas as pd
from pathlib import Path


def main():
    data_dir = Path(__file__).resolve().parent.parent / "data"

    # Cargar CSVs
    print("Cargando CSVs...")
    csvs = {
        "precio":  ("precios_entsoe_ES_2021_2025.csv",   "precio_EUR_MWh"),
        "demanda": ("demanda_ES_2021_2025.csv",           "demanda_MW"),
        "solar":   ("generacion_solar_ES_2021_2025.csv",  "solar_MW"),
        "eolica":  ("generacion_eolica_ES_2021_2025.csv", "wind_MW"),
    }

    dfs = {}
    for key, (fname, col) in csvs.items():
        fpath = data_dir / fname
        if not fpath.exists():
            print(f"  AVISO: {fname} no existe, se omite {key}")
            continue
        df = pd.read_csv(fpath)
        df["timestamp"] = pd.to_datetime(df["timestamp"])
        df = df.set_index("timestamp")
        dfs[key] = df[col]
        print(f"  {fname}: {len(df)} filas, rango {df.index.min()} a {df.index.max()}")

    # Unir todos los DataFrames por timestamp (outer join = preserva todas las horas)
    print("\nUnificando...")
    df_all = pd.concat(dfs.values(), axis=1, keys=dfs.keys())
    df_all = df_all.sort_index()

    # Rellenar huecos
    n_total = len(df_all)
    for col in df_all.columns:
        n_missing = df_all[col].isna().sum()
        if n_missing == 0:
            continue

        if col == "solar":
            # Solar: de noche = 0, de dia interpolamos despues
            df_all[col] = df_all[col].fillna(0)
            print(f"  {col}: {n_missing} huecos rellenados con 0 (noche)")
        else:
            # Precio, demanda, eolica: interpolar linealmente
            df_all[col] = df_all[col].interpolate(method="linear").ffill().bfill()
            print(f"  {col}: {n_missing} huecos interpolados")

    # Verificar que no quedan NaN
    total_nan = df_all.isna().sum().sum()
    if total_nan > 0:
        print(f"\nAVISO: quedan {total_nan} NaN, se rellenan con 0")
        df_all = df_all.fillna(0)

    # Guardar
    out_path = data_dir / "datos_entsoe_unificado_2021_2025.csv"
    df_out = df_all.reset_index()
    df_out["timestamp"] = df_out["timestamp"].dt.strftime("%Y-%m-%d %H:%M:%S")
    df_out.to_csv(out_path, index=False)

    print(f"\nGuardado: {out_path.name}")
    print(f"  {len(df_out)} filas, {len(df_out.columns)} columnas")
    print(f"  Columnas: {list(df_out.columns)}")
    print(f"  Rango: {df_out['timestamp'].iloc[0]} a {df_out['timestamp'].iloc[-1]}")


if __name__ == "__main__":
    main()
