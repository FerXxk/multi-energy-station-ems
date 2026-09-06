"""
Junta en un solo CSV todo lo que la red de precio puede mirar aparte del propio
precio: demanda, generacion solar y eolica, festivos y dias de la semana, y el
periodo en que estuvo activo el tope al gas. Ademas marca las horas cuyo dato se
ha tenido que rellenar, y arrastra esa marca una semana hacia adelante, porque la
red mira los precios de las 168 horas anteriores y esas horas quedan
contaminadas. El resultado se guarda en codigo/data/datos_exogenos_2021_2025.csv.
"""

import os
import sys
import numpy as np
import pandas as pd
from pathlib import Path

# Festivos nacionales España 2021-2025
HOLIDAYS_ES = set()
for year in range(2021, 2026):
    HOLIDAYS_ES.update([
        (year, 1, 1), (year, 1, 6), (year, 5, 1), (year, 8, 15),
        (year, 10, 12), (year, 11, 1), (year, 12, 6), (year, 12, 8), (year, 12, 25),
    ])
HOLIDAYS_ES.update([
    (2021, 4, 2), (2022, 4, 15), (2023, 4, 7), (2024, 3, 29), (2025, 4, 18),
])


def load_csv(filename, value_col, rename_to):
    ruta = Path(__file__).resolve().parent.parent / "data" / filename
    if not ruta.exists():
        print(f"  AVISO: {filename} no encontrado, usando None.")
        return None
    df = pd.read_csv(ruta)
    df["timestamp"] = pd.to_datetime(df["timestamp"])
    return df[["timestamp", value_col]].rename(columns={value_col: rename_to})


def impute_column(df, col, es_imputado, allow_zero=True):
    """
    Imputa una columna con reglas estrictas:
    - precio/demanda/wind: 0 es INVÁLIDO (se marca imputado)
    - solar: 0 es válido (noche)
    - NaN <= 3h consecutivos: interpolación lineal
    - NaN > 3h: lag-168 + flag
    - NaN restantes: leave as NaN (no fallback a 0)
    """
    n_total = len(df)

    # los ceros que no pueden serlo se marcan como huecos
    if not allow_zero:
        n_zero = (df[col] == 0).sum()
        if n_zero > 0:
            mask_zero = df[col] == 0
            es_imputado[mask_zero] = 1
            df.loc[mask_zero, col] = np.nan
            print(f"  {col}: {n_zero} ceros marcados como imputados")

    # se localizan los bloques de huecos seguidos
    is_nan = df[col].isna()
    if not is_nan.any():
        return es_imputado

    blocks = (~is_nan).cumsum()
    block_sizes = is_nan.groupby(blocks).sum()

    short_gaps = block_sizes[block_sizes <= 3].index
    long_gaps = block_sizes[block_sizes > 3].index

    # los huecos cortos se interpolan
    mask_short = is_nan & blocks.isin(short_gaps)
    n_short = mask_short.sum()
    if n_short > 0:
        df.loc[mask_short, col] = df[col].interpolate(method="linear")[mask_short]
        es_imputado[mask_short] = 1
        print(f"  {col}: {n_short} NaN cortos interpolados")

    # los largos se rellenan con el valor de la misma hora de la semana anterior
    mask_long = is_nan & blocks.isin(long_gaps)
    idx_long = df.index[mask_long]
    n_relleno = 0
    for idx in idx_long:
        src = idx - 168
        if src >= 0 and pd.notna(df.at[src, col]):
            df.at[idx, col] = df.at[src, col]
            es_imputado[idx] = 1
            n_relleno += 1
    n_long = mask_long.sum()
    if n_long > 0:
        print(f"  {col}: {n_relleno}/{n_long} NaN largos rellenados con lag-168")

    # lo que quede se arrastra del vecino, como el solar al principio de la serie
    n_remaining = df[col].isna().sum()
    if n_remaining > 0:
        mask_remaining = df[col].isna()
        df[col] = df[col].ffill().bfill()
        es_imputado[mask_remaining] = 1
        print(f"  {col}: {n_remaining} NaN restantes rellenados con ffill+bfill")

    # interpolar entre valores casi nulos puede devolver un cero exacto: se revisa
    if not allow_zero:
        n_zero_post = (df[col] == 0).sum()
        if n_zero_post > 0:
            mask_zero_post = df[col] == 0
            idx_zero = df.index[mask_zero_post]
            n_replaced = 0
            for idx in idx_zero:
                src = idx - 168
                if src >= 0 and pd.notna(df.at[src, col]) and df.at[src, col] != 0:
                    df.at[idx, col] = df.at[src, col]
                    es_imputado[idx] = 1
                    n_replaced += 1
                elif idx + 168 < len(df) and pd.notna(df.at[idx + 168, col]) and df.at[idx + 168, col] != 0:
                    df.at[idx, col] = df.at[idx + 168, col]
                    es_imputado[idx] = 1
                    n_replaced += 1
            n_still_zero = (df[col] == 0).sum()
            if n_still_zero > 0:
                # ultimo recurso: se arrastra el ultimo valor valido
                mask_still = df[col] == 0
                df[col] = df[col].replace(0, np.nan)
                df[col] = df[col].ffill().bfill()
                es_imputado[mask_still] = 1
                n_replaced += mask_still.sum()
                n_still_zero = 0
            print(f"  {col}: {n_zero_post} ceros residuales post-interpolación reemplazados")

    return es_imputado


def main():
    data_dir = Path(__file__).resolve().parent.parent / "data"
    sys.stdout.reconfigure(encoding="utf-8")

    print("=== Preparando features exógenas (v2 — fixes de imputación) ===\n")

    # 1. Cargar datasets
    print("1. Cargando CSVs...")
    df_precio = load_csv("precios_entsoe_ES_2021_2025.csv", "precio_EUR_MWh", "precio_MWh")
    df_demanda = load_csv("demanda_ES_2021_2025.csv", "demanda_MW", "demanda_MW")
    df_solar = load_csv("generacion_solar_ES_2021_2025.csv", "solar_MW", "solar_MW")
    df_wind = load_csv("generacion_eolica_ES_2021_2025.csv", "wind_MW", "wind_MW")

    if df_precio is None:
        print("ERROR: No hay CSV de precios. Abortando.")
        return

    # 2. Merge por timestamp
    print("\n2. Mergeando por timestamp...")
    df = df_precio.copy()
    for dframe, name in [(df_demanda, "demanda"), (df_solar, "solar"), (df_wind, "wind")]:
        if dframe is not None:
            df = df.merge(dframe, on="timestamp", how="left")
            n_missing = df.iloc[:, -1].isna().sum()
            print(f"  {name}: {n_missing} NaN tras merge")

    # 3. Features de calendario
    print("\n3. Calculando features de calendario...")
    ts = df["timestamp"]
    df["hora"] = ts.dt.hour
    df["dia_semana"] = ts.dt.dayofweek + 1
    df["mes"] = ts.dt.month
    df["es_finde"] = (ts.dt.dayofweek >= 5).astype(int)
    df["es_festivo"] = ts.apply(
        lambda t: 1 if (t.year, t.month, t.day) in HOLIDAYS_ES else 0
    )
    df["tope_gas_activo"] = (ts >= pd.Timestamp("2022-06-15")).astype(int)

    # 4. Relleno de huecos, columna a columna
    print("\n4. Imputación estricta...")
    es_imputado = np.zeros(len(df), dtype=int)

    # Precio: 0 es inválido
    es_imputado = impute_column(df, "precio_MWh", es_imputado, allow_zero=False)
    # Demanda: 0 es inválido
    es_imputado = impute_column(df, "demanda_MW", es_imputado, allow_zero=False)
    # Wind: 0 es inválido
    es_imputado = impute_column(df, "wind_MW", es_imputado, allow_zero=False)
    # Solar: 0 es válido (noche)
    es_imputado = impute_column(df, "solar_MW", es_imputado, allow_zero=True)

    df["es_imputado"] = es_imputado

    # la marca de hueco se arrastra 168 horas: esa fila tendra un lag contaminado
    df["lag168_imputado"] = df["es_imputado"].shift(168).fillna(0).astype(int)
    df["flag_excluir"] = ((df["es_imputado"] == 1) | (df["lag168_imputado"] == 1)).astype(int)

    n_excluir = df["flag_excluir"].sum()
    n_imputados = (df["es_imputado"] == 1).sum()
    print(f"\n5. Flags de imputación:")
    print(f"  Filas imputadas (directamente): {n_imputados}")
    print(f"  Filas a excluir (directa + lag168): {n_excluir}")

    # 6. Comprobacion de que no quedan huecos en las columnas criticas
    print("\n6. Verificación final:")
    hay_error = False
    for col in ["precio_MWh", "demanda_MW", "wind_MW", "solar_MW"]:
        n_nan = df[col].isna().sum()
        if n_nan > 0:
            print(f"  ERROR: {col} tiene {n_nan} NaN restantes")
            hay_error = True
    n_precio_zero = (df["precio_MWh"] == 0).sum()
    if n_precio_zero > 0:
        print(f"  ERROR: precio_MWh tiene {n_precio_zero} ceros restantes")
        hay_error = True
    if hay_error:
        print("  Abortando — revisar imputación.")
        return

    print("  OK: sin NaN ni ceros en columnas críticas")

    # 7. Guardar
    out_cols = [
        "timestamp", "precio_MWh",
        "demanda_MW", "solar_MW", "wind_MW",
        "hora", "dia_semana", "mes", "es_finde", "es_festivo",
        "tope_gas_activo", "es_imputado", "lag168_imputado", "flag_excluir",
    ]
    out_path = data_dir / "datos_exogenos_2021_2025.csv"
    df[out_cols].to_csv(out_path, index=False)
    print(f"\n7. Guardado: {out_path}")
    print(f"   Filas: {len(df)}")

    # 8. Estadísticas
    print("\n8. Estadísticas:")
    print(f"  Precio medio:  {df['precio_MWh'].mean():.2f} EUR/MWh")
    print(f"  Demanda media: {df['demanda_MW'].mean():.0f} MW")
    print(f"  Solar medio:   {df['solar_MW'].mean():.0f} MW")
    print(f"  Wind medio:    {df['wind_MW'].mean():.0f} MW")


if __name__ == "__main__":
    main()
