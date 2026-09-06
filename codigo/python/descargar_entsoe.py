"""
Baja de la plataforma de transparencia de ENTSO-E los datos del mercado espanol
de 2021 a 2025: precio del mercado diario, demanda, y generacion solar y eolica.
Va ano por ano porque la API trunca las peticiones largas, promedia los cuartos
de hora a horas y lo deja todo en hora local espanola. Hace falta una clave
gratuita de la plataforma, que se pasa por la variable de entorno ENTSOE_API_KEY
o se teclea al arrancar. Necesita entsoe-py y pandas.
"""

import os
import sys
import pandas as pd
from pathlib import Path


def descargar_por_bloques(client, start_year, end_year, consulta, **kwargs):
    """Descarga año a año para evitar truncados de la API de ENTSO-E."""
    dfs = []

    for year in range(start_year, end_year + 1):
        print(f"  {year}...", end=" ", flush=True)
        start = pd.Timestamp(f"{year}-01-01 00:00", tz="Europe/Madrid")
        end = pd.Timestamp(f"{year}-12-31 23:59", tz="Europe/Madrid")

        try:
            if consulta == "prices":
                df = client.prices.day_ahead(start=start, end=end, country="ES")
            elif consulta == "load":
                df = client.load.actual(start=start, end=end, country="ES")
            elif consulta == "generation":
                df = client.generation.actual(start=start, end=end, country="ES", **kwargs)

            if df is not None and not df.empty:
                if isinstance(df, pd.Series):
                    df = df.to_frame(name="value")
                # Asegurar DatetimeIndex antes de concatenar
                if not isinstance(df.index, pd.DatetimeIndex):
                    for col in df.columns:
                        if "time" in col.lower() or "date" in col.lower():
                            df["timestamp"] = pd.to_datetime(df[col], utc=True)
                            df = df.set_index("timestamp")
                            break
                print(f"OK ({len(df)} filas)")
                dfs.append(df)
            else:
                print("VACIO")
        except Exception as e:
            print(f"ERROR: {e}")

    if not dfs:
        return pd.DataFrame()

    df_total = pd.concat(dfs)
    df_total = df_total[~df_total.index.duplicated(keep="first")]
    return df_total


def guardar_csv(df, output_path, rename_to):
    """Convierte de UTC a Europe/Madrid, promedia a horario, guarda CSV."""
    if df.empty:
        print(f"  SKIP {output_path.name} (sin datos)")
        return

    # Asegurar que tenemos DatetimeIndex
    if not isinstance(df.index, pd.DatetimeIndex):
        for col in df.columns:
            if df[col].dtype == "datetime64[ns]" or "time" in col.lower() or "date" in col.lower():
                df = df.set_index(col)
                break
        else:
            print(f"  SKIP {output_path.name} (no se encontro columna de fechas)")
            return

    # Asegurar timezone UTC si no tiene
    if df.index.tz is None:
        df.index = df.index.tz_localize("UTC")

    # Solo columnas numericas
    df = df.select_dtypes(include="number")

    df_local = df.tz_convert("Europe/Madrid").tz_localize(None)
    df_hourly = df_local.resample("h").mean()

    # Tratamiento inteligente de huecos
    if "solar" in output_path.stem.lower():
        # Solar: de noche no hay generacion, rellenar con 0
        df_hourly = df_hourly.fillna(0)
    else:
        # Precio, demanda, eolica: interpolar linealmente
        df_hourly = df_hourly.interpolate(method="linear").ffill().bfill()

    # Tomar primera columna si hay varias
    if isinstance(df_hourly, pd.DataFrame):
        values = df_hourly.iloc[:, 0]
    else:
        values = df_hourly

    out = pd.DataFrame({
        "timestamp": df_hourly.index.strftime("%Y-%m-%d %H:%M:%S"),
        rename_to: values.values,
    }).reset_index(drop=True)

    out.to_csv(output_path, index=False)
    print(f"  -> {output_path.name} ({len(out)} filas)")


def main():
    api_key = os.environ.get("ENTSOE_API_KEY")
    if not api_key:
        api_key = input("Introduce tu ENTSO-E API key: ").strip()
        if not api_key:
            print("ERROR: No se ha proporcionado API key.")
            sys.exit(1)

    from entsoe import Client
    client = Client(api_key=api_key, tz="Europe/Madrid", cache=False)

    start_year, end_year = 2021, 2025
    out_dir = Path(__file__).resolve().parent.parent / "data"
    out_dir.mkdir(parents=True, exist_ok=True)

    print("=== Descarga ENTSO-E (bucle anual) ===\n")

    # --- 0. Precios day-ahead ---
    print("[1/4] Precios day-ahead...")
    df_prices = descargar_por_bloques(client, start_year, end_year, "prices")
    guardar_csv(df_prices, out_dir / "precios_entsoe_ES_2021_2025.csv", "precio_EUR_MWh")

    # --- 1. Demanda real ---
    print("\n[2/4] Demanda real...")
    df_load = descargar_por_bloques(client, start_year, end_year, "load")
    guardar_csv(df_load, out_dir / "demanda_ES_2021_2025.csv", "demanda_MW")

    # --- 2. Generación solar real (B16) ---
    print("\n[3/4] Generación solar (B16)...")
    df_solar = descargar_por_bloques(client, start_year, end_year, "generation", psr_type="B16")
    guardar_csv(df_solar, out_dir / "generacion_solar_ES_2021_2025.csv", "solar_MW")

    # --- 3. Generación eólica real (B19 = Wind Onshore) ---
    print("\n[4/4] Generación eólica (B19)...")
    df_wind = descargar_por_bloques(client, start_year, end_year, "generation", psr_type="B19")
    guardar_csv(df_wind, out_dir / "generacion_eolica_ES_2021_2025.csv", "wind_MW")

    print("\n=== Descarga completada ===")


if __name__ == "__main__":
    main()
