"""
Saca del conjunto de datos de carga rapida de la EPFL las distribuciones que
luego usa el generador de demanda en MATLAB: a que hora llegan los coches,
cuanta energia piden y con que carga entran y salen. Las guarda en CSV y de paso
dibuja las graficas que van en la memoria. Necesita pandas, openpyxl, numpy y
matplotlib.
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Backend sin GUI

# Configuracion: rutas de entrada y de salida
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "..", "data", "desl_epfl")
FIG_DIR = os.path.join(DATA_DIR, "figuras")
os.makedirs(FIG_DIR, exist_ok=True)

# 1. Carga de datos
print("Cargando Session_data.xlsx...")
df = pd.read_excel(os.path.join(DATA_DIR, "Session_data.xlsx"))
print(f"  Sesiones totales: {len(df)}")
print(f"  Columnas: {list(df.columns)}")

# 2. Limpieza de sesiones no validas
print("\n--- Limpieza de datos ---")
n_antes = len(df)

# Normalizar nombres de columnas (quitar espacios, pasar a minúsculas)
df.columns = df.columns.str.strip()

# Columnas reales del XLSX: 'Stay (min)', 'Energy (Wh)', 'Pmax (W)', etc.
# Mapear a nombres internos
col_map = {
    'Stay (min)': 'Stay',
    'Energy (Wh)': 'Energy',
    'Pmax (W)': 'Pmax',
    'Preq_max (W)': 'Preq_max',
    'Energy capacity (Wh)': 'Energy_capacity',
}
df = df.rename(columns={k: v for k, v in col_map.items() if k in df.columns})

# Quitar sesiones abortadas (< 2 min)
df = df[df['Stay'] > 2]
print(f"  Stay > 2 min: {len(df)} (eliminadas {n_antes - len(df)})")

# Quitar sesiones sin energía
df = df[df['Energy'] > 0]
print(f"  Energy > 0: {len(df)}")

# Quitar si SOC de llegada > 95% (ya casi lleno)
df = df[df['SOC arrival'] <= 95]
print(f"  SOC arrival <= 95%: {len(df)}")

# Verificar coherencia SOC
df = df[df['SOC departure'] > df['SOC arrival']]
print(f"  SOC departure > SOC arrival: {len(df)}")

# Potencia máxima razonable (< 200 kW)
df = df[df['Pmax'] < 200000]
print(f"  Pmax < 200 kW: {len(df)}")

n_despues = len(df)
print(f"  Sesiones válidas: {n_despues} (eliminadas {n_antes - n_despues})")

# 3. Variables derivadas
df['energia_kwh'] = df['Energy'] / 1000
df['duracion_min'] = df['Stay']
df['hora_llegada'] = df['Arrival'].dt.hour
df['dia_semana'] = df['Arrival'].dt.dayofweek  # 0=Lun, 6=Dom
df['es_finde'] = df['dia_semana'] >= 5

# Potencia media (kW)
df['potencia_media_kw'] = df['energia_kwh'] / (df['duracion_min'] / 60)

# 4. Distribuciones que consume MATLAB
print("\n--- Extrayendo distributions ---")

# 4a. Distribución de llegadas por hora (0-23)
llegadas = df['hora_llegada'].value_counts(normalize=True).sort_index()
llegadas_df = pd.DataFrame({'hora': llegadas.index, 'probabilidad': llegadas.values})
# Rellenar horas sin datos con 0
for h in range(24):
    if h not in llegadas_df['hora'].values:
        llegadas_df = pd.concat([llegadas_df, pd.DataFrame({'hora': [h], 'probabilidad': [0.0]})])
llegadas_df = llegadas_df.sort_values('hora').reset_index(drop=True)
llegadas_df.to_csv(os.path.join(DATA_DIR, 'distribucion_llegadas_ev.csv'), index=False)
print(f"  Distribución de llegadas: {len(llegadas_df)} horas")

# 4b. Distribución de energía por sesión (kWh)
energia_df = df[['energia_kwh']].copy()
energia_df.to_csv(os.path.join(DATA_DIR, 'distribucion_energia_ev.csv'), index=False)
print(f"  Distribución de energía: {len(energia_df)} sesiones")

# 4c. Distribución de SOC
soc_df = df[['SOC arrival', 'SOC departure']].copy()
soc_df.columns = ['soc_llegada', 'soc_salida']
soc_df.to_csv(os.path.join(DATA_DIR, 'distribucion_soc_ev.csv'), index=False)
print(f"  Distribución de SOC: {len(soc_df)} sesiones")

# 4d. Resumen de sesiones
resumen = {
    'metrica': [
        'total_sesiones',
        'dias_observados',
        'sesiones_por_dia',
        'energia_media_kwh',
        'energia_mediana_kwh',
        'energia_std_kwh',
        'duracion_media_min',
        'duracion_mediana_min',
        'duracion_std_min',
        'soc_llegada_media',
        'soc_llegada_mediana',
        'soc_salida_media',
        'potencia_media_kw',
        'n_cargadores',
    ],
    'valor': [
        len(df),
        df['Arrival'].dt.date.nunique(),
        len(df) / max(df['Arrival'].dt.date.nunique(), 1),
        df['energia_kwh'].mean(),
        df['energia_kwh'].median(),
        df['energia_kwh'].std(),
        df['duracion_min'].mean(),
        df['duracion_min'].median(),
        df['duracion_min'].std(),
        df['SOC arrival'].mean(),
        df['SOC arrival'].median(),
        df['SOC departure'].mean(),
        df['potencia_media_kw'].mean(),
        2,  # 2 cargadores CCS
    ]
}
resumen_df = pd.DataFrame(resumen)
resumen_df.to_csv(os.path.join(DATA_DIR, 'resumen_sesiones_ev.csv'), index=False)
print(f"  Resumen guardado")

# Resumen por tipo de día
resumen_laborable = {
    'metrica': ['sesiones_por_dia', 'energia_media_kwh', 'duracion_media_min', 'soc_llegada_media'],
    'valor': [
        len(df[~df['es_finde']]) / max(df[~df['es_finde']]['Arrival'].dt.date.nunique(), 1),
        df[~df['es_finde']]['energia_kwh'].mean(),
        df[~df['es_finde']]['duracion_min'].mean(),
        df[~df['es_finde']]['SOC arrival'].mean(),
    ]
}
resumen_finde = {
    'metrica': ['sesiones_por_dia', 'energia_media_kwh', 'duracion_media_min', 'soc_llegada_media'],
    'valor': [
        len(df[df['es_finde']]) / max(df[df['es_finde']]['Arrival'].dt.date.nunique(), 1),
        df[df['es_finde']]['energia_kwh'].mean(),
        df[df['es_finde']]['duracion_min'].mean(),
        df[df['es_finde']]['SOC arrival'].mean(),
    ]
}
resumen_tipo = pd.DataFrame({
    'tipo_dia': ['laborable', 'findesemana'],
    'sesiones_por_dia': [resumen_laborable['valor'][0], resumen_finde['valor'][0]],
    'energia_media_kwh': [resumen_laborable['valor'][1], resumen_finde['valor'][1]],
    'duracion_media_min': [resumen_laborable['valor'][2], resumen_finde['valor'][2]],
    'soc_llegada_media': [resumen_laborable['valor'][3], resumen_finde['valor'][3]],
})
resumen_tipo.to_csv(os.path.join(DATA_DIR, 'resumen_por_tipo_dia.csv'), index=False)
print(f"  Resumen por tipo de día guardado")

# 5. Graficas para la memoria
print("\n--- Generando gráficas ---")

plt.rcParams.update({
    'font.size': 12,
    'axes.titlesize': 14,
    'axes.labelsize': 12,
    'figure.dpi': 150,
})

# Gráfica 1: Histograma de llegadas por hora
fig, ax = plt.subplots(figsize=(10, 5))
ax.bar(llegadas_df['hora'], llegadas_df['probabilidad'] * 100, color='steelblue', edgecolor='black', linewidth=0.5)
ax.set_xlabel('Hora del día')
ax.set_ylabel('Porcentaje de sesiones (%)')
ax.set_title('Distribución de llegadas — DESL-EPFL (DC Fast 172.5 kW)')
ax.set_xticks(range(0, 24, 2))
ax.set_xlim(-0.5, 23.5)
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'llegadas_por_hora.png'))
plt.close()
print("  [1/6] llegadas_por_hora.png")

# Gráfica 2: Histograma de energía por sesión
fig, ax = plt.subplots(figsize=(10, 5))
ax.hist(df['energia_kwh'], bins=30, color='steelblue', edgecolor='black', linewidth=0.5)
ax.axvline(df['energia_kwh'].mean(), color='red', linestyle='--', linewidth=1.5, label=f'Media: {df["energia_kwh"].mean():.1f} kWh')
ax.axvline(df['energia_kwh'].median(), color='orange', linestyle='--', linewidth=1.5, label=f'Mediana: {df["energia_kwh"].median():.1f} kWh')
ax.set_xlabel('Energía cargada (kWh)')
ax.set_ylabel('Número de sesiones')
ax.set_title('Distribución de energía por sesión')
ax.legend()
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'energia_por_sesion.png'))
plt.close()
print("  [2/6] energia_por_sesion.png")

# Gráfica 3: SOC de llegada y salida
fig, ax = plt.subplots(figsize=(10, 5))
bins = np.arange(0, 105, 5)
ax.hist(df['SOC arrival'], bins=bins, alpha=0.6, color='steelblue', edgecolor='black', linewidth=0.5, label='Llegada')
ax.hist(df['SOC departure'], bins=bins, alpha=0.6, color='coral', edgecolor='black', linewidth=0.5, label='Salida')
ax.set_xlabel('Estado de carga SOC (%)')
ax.set_ylabel('Número de sesiones')
ax.set_title('SOC de llegada y salida — Distribución')
ax.legend()
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'soc_llegada_salida.png'))
plt.close()
print("  [3/6] soc_llegada_salida.png")

# Gráfica 4: Duración vs energía
fig, ax = plt.subplots(figsize=(10, 5))
scatter = ax.scatter(df['duracion_min'], df['energia_kwh'], alpha=0.3, s=15, c=df['SOC arrival'], cmap='viridis')
cbar = plt.colorbar(scatter, ax=ax)
cbar.set_label('SOC llegada (%)')
ax.set_xlabel('Duración de sesión (min)')
ax.set_ylabel('Energía cargada (kWh)')
ax.set_title('Duración vs Energía por sesión')
ax.grid(alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'duracion_vs_energia.png'))
plt.close()
print("  [4/6] duracion_vs_energia.png")

# Gráfica 5: Sesiones por día de la semana
dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
sesiones_dia = df['dia_semana'].value_counts().sort_index()
fig, ax = plt.subplots(figsize=(10, 5))
colors = ['steelblue'] * 5 + ['coral'] * 2  # Colores distintos para finde
ax.bar(dias, sesiones_dia.values, color=colors, edgecolor='black', linewidth=0.5)
ax.set_ylabel('Número de sesiones')
ax.set_title('Sesiones por día de la semana')
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'sesiones_por_dia.png'))
plt.close()
print("  [5/6] sesiones_por_dia.png")

# Gráfica 6: Histograma de duración
fig, ax = plt.subplots(figsize=(10, 5))
ax.hist(df['duracion_min'], bins=30, color='steelblue', edgecolor='black', linewidth=0.5)
ax.axvline(df['duracion_min'].mean(), color='red', linestyle='--', linewidth=1.5, label=f'Media: {df["duracion_min"].mean():.0f} min')
ax.axvline(df['duracion_min'].median(), color='orange', linestyle='--', linewidth=1.5, label=f'Mediana: {df["duracion_min"].median():.0f} min')
ax.set_xlabel('Duración de sesión (min)')
ax.set_ylabel('Número de sesiones')
ax.set_title('Distribución de duración de sesión')
ax.legend()
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'duracion_sesion.png'))
plt.close()
print("  [6/6] duracion_sesion.png")

# 6. Resumen por pantalla
print("\n" + "="*60)
print("RESUMEN DEL DATASET DESL-EPFL")
print("="*60)
print(f"Sesiones válidas:     {len(df)}")
print(f"Días observados:      {df['Arrival'].dt.date.nunique()}")
print(f"Sesiones/día:         {resumen_df[resumen_df['metrica']=='sesiones_por_dia']['valor'].values[0]:.1f}")
print(f"Energía media:        {df['energia_kwh'].mean():.1f} kWh")
print(f"Energía mediana:      {df['energia_kwh'].median():.1f} kWh")
print(f"Duración media:       {df['duracion_min'].mean():.0f} min")
print(f"Duración mediana:     {df['duracion_min'].median():.0f} min")
print(f"SOC llegada media:    {df['SOC arrival'].mean():.0f}%")
print(f"SOC salida media:     {df['SOC departure'].mean():.0f}%")
print(f"Potencia media:       {df['potencia_media_kw'].mean():.1f} kW")
print(f"\nLaborables:           {resumen_tipo[resumen_tipo['tipo_dia']=='laborable']['sesiones_por_dia'].values[0]:.1f} sesiones/día")
print(f"Findes:               {resumen_tipo[resumen_tipo['tipo_dia']=='findesemana']['sesiones_por_dia'].values[0]:.1f} sesiones/día")
print(f"\nGráficas guardadas en: {FIG_DIR}")
print(f"CSVs guardados en:     {DATA_DIR}")
