"""
Compara los dos conjuntos de datos de carga de coches electricos que se
manejaron: el de Caltech, de carga lenta en un aparcamiento, y el de la EPFL, de
carga rapida. Enfrenta llegadas, potencias, energias y duraciones para justificar
por que la estacion se modela con el segundo. Deja las graficas en
codigo/data/comparativa_l2_l3 y necesita pandas, openpyxl, numpy y matplotlib.
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')

# Configuracion: rutas de entrada y de salida
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR_CALTECH = os.path.join(SCRIPT_DIR, "..", "data", "caltech")
DATA_DIR_DESL    = os.path.join(SCRIPT_DIR, "..", "data", "desl_epfl")
FIG_DIR          = os.path.join(SCRIPT_DIR, "..", "data", "comparativa_l2_l3")
os.makedirs(FIG_DIR, exist_ok=True)

# 1. Datos de Caltech, carga lenta
print("=" * 60)
print("CARGANDO DATOS CALTECH (Level 2, ~6.6 kW)")
print("=" * 60)

caltech_path = os.path.join(DATA_DIR_CALTECH, "acndata_caltech.csv")
if not os.path.exists(caltech_path):
    print(f"\n[ERROR] No se encuentra {caltech_path}")
    print("Ejecuta primero: python descarga_caltech.py")
    exit(1)

df_l2 = pd.read_csv(caltech_path)
print(f"  Sesiones totales: {len(df_l2)}")

# Calcular duración en minutos
df_l2['duracion_min'] = df_l2['duracion_horas'] * 60
df_l2['energia_kwh'] = df_l2['kWhDelivered']

# Extraer hora de llegada (convertir de UTC a hora local aproximada)
df_l2['connectionTime'] = pd.to_datetime(df_l2['connectionTime'], utc=True)
df_l2['hora_llegada'] = df_l2['connectionTime'].dt.hour  # UTC, pero para patrón relativo sirve
df_l2['dia_semana'] = df_l2['connectionTime'].dt.dayofweek

# Limpiar
df_l2 = df_l2[df_l2['duracion_min'] > 2]
df_l2 = df_l2[df_l2['energia_kwh'] > 0.5]
df_l2 = df_l2[df_l2['duracion_min'] < 24 * 60]  # max 24h
print(f"  Sesiones válidas: {len(df_l2)}")

# 2. Datos de la EPFL, carga rapida
print("\n" + "=" * 60)
print("CARGANDO DATOS DESL-EPFL (Level 3, 172.5 kW)")
print("=" * 60)

desl_path = os.path.join(DATA_DIR_DESL, "Session_data.xlsx")
if not os.path.exists(desl_path):
    print(f"\n[ERROR] No se encuentra {desl_path}")
    exit(1)

df_l3 = pd.read_excel(desl_path)
print(f"  Sesiones totales: {len(df_l3)}")

# Renombrar columnas
col_map = {
    'Stay (min)': 'duracion_min',
    'Energy (Wh)': 'energia_wh',
    'Pmax (W)': 'pmax_w',
}
df_l3 = df_l3.rename(columns=col_map)

df_l3['energia_kwh'] = df_l3['energia_wh'] / 1000
df_l3['hora_llegada'] = pd.to_datetime(df_l3['Arrival']).dt.hour
df_l3['dia_semana'] = pd.to_datetime(df_l3['Arrival']).dt.dayofweek

# Limpiar
df_l3 = df_l3[df_l3['duracion_min'] > 2]
df_l3 = df_l3[df_l3['energia_kwh'] > 0.5]
df_l3 = df_l3[df_l3['SOC arrival'] <= 95]
df_l3 = df_l3[df_l3['SOC departure'] > df_l3['SOC arrival']]
print(f"  Sesiones válidas: {len(df_l3)}")

# 3. Estadisticas comparadas
print("\n" + "=" * 60)
print("ESTADÍSTICAS COMPARATIVAS")
print("=" * 60)

stats = {
    'Métrica': [
        'Nivel de carga',
        'Potencia máxima (kW)',
        'Sesiones totales',
        'Energía media (kWh)',
        'Energía mediana (kWh)',
        'Duración media (min)',
        'Duración mediana (min)',
        'Sesiones/día',
    ],
    'Level 2 (Caltech)': [
        'Level 2 (CA)',
        '~6.6',
        str(len(df_l2)),
        f"{df_l2['energia_kwh'].mean():.1f}",
        f"{df_l2['energia_kwh'].median():.1f}",
        f"{df_l2['duracion_min'].mean():.0f}",
        f"{df_l2['duracion_min'].median():.0f}",
        f"{len(df_l2) / max(df_l2['connectionTime'].dt.date.nunique(), 1):.1f}",
    ],
    'Level 3 (DESL-EPFL)': [
        'Level 3 (DC fast)',
        '172.5',
        str(len(df_l3)),
        f"{df_l3['energia_kwh'].mean():.1f}",
        f"{df_l3['energia_kwh'].median():.1f}",
        f"{df_l3['duracion_min'].mean():.0f}",
        f"{df_l3['duracion_min'].median():.0f}",
        f"{len(df_l3) / pd.to_datetime(df_l3['Arrival']).dt.date.nunique():.1f}",
    ],
}
stats_df = pd.DataFrame(stats)
print(stats_df.to_string(index=False))
stats_df.to_csv(os.path.join(FIG_DIR, 'estadisticas_comparativas.csv'), index=False)

# 4. Graficas comparadas
print("\n--- Generando gráficas comparativas ---")

plt.rcParams.update({
    'font.size': 11,
    'axes.titlesize': 13,
    'axes.labelsize': 11,
    'figure.dpi': 150,
})

COLOR_L2 = '#2196F3'  # azul
COLOR_L3 = '#F44336'  # rojo

# Gráfica 1: Histograma de energía comparativo
fig, axes = plt.subplots(1, 2, figsize=(12, 5), sharey=True)

axes[0].hist(df_l2['energia_kwh'], bins=40, color=COLOR_L2, edgecolor='black', linewidth=0.5, alpha=0.8)
axes[0].axvline(df_l2['energia_kwh'].mean(), color='black', linestyle='--', linewidth=1.5, label=f'Media: {df_l2["energia_kwh"].mean():.1f} kWh')
axes[0].set_title('Level 2 (Caltech, ~6.6 kW)')
axes[0].set_xlabel('Energía cargada (kWh)')
axes[0].set_ylabel('Número de sesiones')
axes[0].legend(fontsize=9)
axes[0].grid(axis='y', alpha=0.3)

axes[1].hist(df_l3['energia_kwh'], bins=40, color=COLOR_L3, edgecolor='black', linewidth=0.5, alpha=0.8)
axes[1].axvline(df_l3['energia_kwh'].mean(), color='black', linestyle='--', linewidth=1.5, label=f'Media: {df_l3["energia_kwh"].mean():.1f} kWh')
axes[1].set_title('Level 3 (DESL-EPFL, 172.5 kW)')
axes[1].set_xlabel('Energía cargada (kWh)')
axes[1].legend(fontsize=9)
axes[1].grid(axis='y', alpha=0.3)

fig.suptitle('Comparación de energía por sesión', fontsize=14, y=1.02)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'comparativa_energia.png'), bbox_inches='tight')
plt.close()
print("  [1/5] comparativa_energia.png")

# Gráfica 2: Histograma de duración comparativo
fig, axes = plt.subplots(1, 2, figsize=(12, 5), sharey=True)

axes[0].hist(df_l2['duracion_min'], bins=50, color=COLOR_L2, edgecolor='black', linewidth=0.5, alpha=0.8)
axes[0].axvline(df_l2['duracion_min'].mean(), color='black', linestyle='--', linewidth=1.5, label=f'Media: {df_l2["duracion_min"].mean():.0f} min')
axes[0].set_title('Level 2 (Caltech, ~6.6 kW)')
axes[0].set_xlabel('Duración de sesión (min)')
axes[0].set_ylabel('Número de sesiones')
axes[0].legend(fontsize=9)
axes[0].grid(axis='y', alpha=0.3)

axes[1].hist(df_l3['duracion_min'], bins=50, color=COLOR_L3, edgecolor='black', linewidth=0.5, alpha=0.8)
axes[1].axvline(df_l3['duracion_min'].mean(), color='black', linestyle='--', linewidth=1.5, label=f'Media: {df_l3["duracion_min"].mean():.0f} min')
axes[1].set_title('Level 3 (DESL-EPFL, 172.5 kW)')
axes[1].set_xlabel('Duración de sesión (min)')
axes[1].legend(fontsize=9)
axes[1].grid(axis='y', alpha=0.3)

fig.suptitle('Comparación de duración de sesión', fontsize=14, y=1.02)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'comparativa_duracion.png'), bbox_inches='tight')
plt.close()
print("  [2/5] comparativa_duracion.png")

# Gráfica 3: Distribución de llegadas comparativa
llegadas_l2 = df_l2['hora_llegada'].value_counts(normalize=True).sort_index() * 100
llegadas_l3 = df_l3['hora_llegada'].value_counts(normalize=True).sort_index() * 100

fig, ax = plt.subplots(figsize=(10, 5))
x = np.arange(24)
width = 0.35

ax.bar(x - width/2, [llegadas_l2.get(h, 0) for h in x], width, label='Level 2 (Caltech)', color=COLOR_L2, alpha=0.8, edgecolor='black', linewidth=0.5)
ax.bar(x + width/2, [llegadas_l3.get(h, 0) for h in x], width, label='Level 3 (DESL-EPFL)', color=COLOR_L3, alpha=0.8, edgecolor='black', linewidth=0.5)

ax.set_xlabel('Hora del día')
ax.set_ylabel('Porcentaje de sesiones (%)')
ax.set_title('Distribución de llegadas: Level 2 vs Level 3')
ax.set_xticks(x)
ax.set_xticklabels([f'{h:02d}' for h in x], rotation=45)
ax.legend()
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'comparativa_llegadas.png'))
plt.close()
print("  [3/5] comparativa_llegadas.png")

# Gráfica 4: Energía vs Duración (scatter)
fig, axes = plt.subplots(1, 2, figsize=(12, 5), sharey=True)

axes[0].scatter(df_l2['duracion_min'], df_l2['energia_kwh'], alpha=0.15, s=8, color=COLOR_L2)
axes[0].set_title('Level 2 (Caltech, ~6.6 kW)')
axes[0].set_xlabel('Duración (min)')
axes[0].set_ylabel('Energía (kWh)')
axes[0].grid(alpha=0.3)

axes[1].scatter(df_l3['duracion_min'], df_l3['energia_kwh'], alpha=0.15, s=8, color=COLOR_L3)
axes[1].set_title('Level 3 (DESL-EPFL, 172.5 kW)')
axes[1].set_xlabel('Duración (min)')
axes[1].grid(alpha=0.3)

fig.suptitle('Relación Energía vs Duración', fontsize=14, y=1.02)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'comparativa_energia_duracion.png'), bbox_inches='tight')
plt.close()
print("  [4/5] comparativa_energia_duracion.png")

# Gráfica 5: Potencia media estimada
fig, ax = plt.subplots(figsize=(8, 5))

# Calcular potencia media por sesión
pot_l2 = df_l2['energia_kwh'] / (df_l2['duracion_min'] / 60)
pot_l3 = df_l3['energia_kwh'] / (df_l3['duracion_min'] / 60)

# Recortar outliers para mejor visualización
pot_l2 = pot_l2[pot_l2 < 30]
pot_l3 = pot_l3[pot_l3 < 250]

ax.hist(pot_l2, bins=40, alpha=0.6, color=COLOR_L2, edgecolor='black', linewidth=0.5, label=f'Level 2 (media: {pot_l2.mean():.1f} kW)')
ax.hist(pot_l3, bins=40, alpha=0.6, color=COLOR_L3, edgecolor='black', linewidth=0.5, label=f'Level 3 (media: {pot_l3.mean():.1f} kW)')

ax.set_xlabel('Potencia media de la sesión (kW)')
ax.set_ylabel('Número de sesiones')
ax.set_title('Distribución de potencia media por sesión')
ax.legend()
ax.grid(axis='y', alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(FIG_DIR, 'comparativa_potencia.png'))
plt.close()
print("  [5/5] comparativa_potencia.png")

# 5. Resumen final
print("\n" + "=" * 60)
print("COMPARATIVA COMPLETADA")
print("=" * 60)
print(f"\nLevel 2 (Caltech):")
print(f"  Potencia:     ~6.6 kW (Level 2 CA)")
print(f"  Energía:      {df_l2['energia_kwh'].mean():.1f} kWh (media)")
print(f"  Duración:     {df_l2['duracion_min'].mean():.0f} min (media)")
print(f"  Potencia avg: {pot_l2.mean():.1f} kW")
print(f"\nLevel 3 (DESL-EPFL):")
print(f"  Potencia:     172.5 kW max (Level 3 CC)")
print(f"  Energía:      {df_l3['energia_kwh'].mean():.1f} kWh (media)")
print(f"  Duración:     {df_l3['duracion_min'].mean():.0f} min (media)")
print(f"  Potencia avg: {pot_l3.mean():.1f} kW")
print(f"\nFactor de reducción Level 3 vs Level 2:")
print(f"  Duración:     {df_l2['duracion_min'].mean() / df_l3['duracion_min'].mean():.1f}x más rápido")
print(f"  Potencia:     {pot_l3.mean() / pot_l2.mean():.1f}x más potencia")
print(f"\nGráficas guardadas en: {FIG_DIR}")
