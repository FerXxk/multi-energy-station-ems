"""
Mira que pinta tienen los perfiles de demanda que ha generado
Demanda_Coches_Aleatoria.m: cuantos coches llegan, a que horas, cuanta energia
piden y cuanto hidrogeno se despacha. Carga los .mat de los perfiles, saca unas
cuantas cifras por pantalla y deja los histogramas en codigo/data/perfil_ev.
Necesita scipy, numpy y matplotlib.
"""

import os
import numpy as np
import scipy.io as sio
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')

# Configuracion: rutas de entrada y de salida
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "..", "data")
CARS_DIR = os.path.join(SCRIPT_DIR, "..", "..", "SimugridElectrolinera", "Datos", "Cars")
FIG_DIR = os.path.join(DATA_DIR, "perfil_ev")
os.makedirs(FIG_DIR, exist_ok=True)

# 1. Carga de datos
print("=" * 60)
print("CARGANDO PERFILES DE DEMANDA EV/H2")
print("=" * 60)

ev_path = os.path.join(CARS_DIR, "perfil_EV.mat")
h2_path = os.path.join(CARS_DIR, "perfil_H2.mat")

if not os.path.exists(ev_path):
    raise FileNotFoundError(f"perfil_EV.mat no encontrado en {ev_path}. Ejecuta Demanda_Coches_Aleatoria.m primero.")

ev_data = sio.loadmat(ev_path, squeeze_me=True)
h2_data = sio.loadmat(h2_path, squeeze_me=True) if os.path.exists(h2_path) else None

# Extraer timeseries (scipy las carga como structs con campos 'Time' y 'Data')
def extract_ts(mat_struct, var_name):
    """Extrae Time y Data de un timeseries guardado por MATLAB.
    Primero intenta leer los arrays crudos (*_time, *_data).
    Si no existen, intenta leer el struct timeseries MCOS."""
    time_key = f'{var_name}_time'
    data_key = f'{var_name}_data'
    if time_key in mat_struct and data_key in mat_struct:
        time = np.array(mat_struct[time_key]).flatten()
        data = np.array(mat_struct[data_key]).flatten()
        return time, data
    # Fallback: intentar struct MCOS (scipy generalmente no puede leer esto)
    raise ValueError(f"No se encontraron arrays crudos '{time_key}'/'{data_key}' en el .mat")

print("\nVariables disponibles en perfil_EV.mat:")
for k in ev_data.keys():
    if not k.startswith('_'):
        print(f"  - {k}")

# Cargar todas las variables
variables = {}
for var_name in ['demanda_EV_lab', 'demanda_EV_finde', 'pot_EV_lab', 'pot_EV_finde']:
    if var_name in ev_data:
        try:
            time, data = extract_ts(ev_data, var_name)
            variables[var_name] = {'time': time, 'data': data}
            print(f"  {var_name}: {len(data)} puntos, rango [{data.min():.4f}, {data.max():.4f}]")
        except Exception as e:
            print(f"  {var_name}: Error al extraer - {e}")
    else:
        print(f"  {var_name}: NO ENCONTRADO")

if h2_data is not None:
    print("\nVariables disponibles en perfil_H2.mat:")
    for k in h2_data.keys():
        if not k.startswith('_'):
            print(f"  - {k}")
    for var_name in ['demanda_H2_lab', 'demanda_H2_finde']:
        if var_name in h2_data:
            try:
                time, data = extract_ts(h2_data, var_name)
                variables[var_name] = {'time': time, 'data': data}
                print(f"  {var_name}: {len(data)} puntos, rango [{data.min():.4f}, {data.max():.4f}]")
            except Exception as e:
                print(f"  {var_name}: Error al extraer - {e}")

# 2. Metricas de cada perfil
print("\n" + "=" * 60)
print("MÉTRICAS DE DEMANDA")
print("=" * 60)

def compute_metrics(time_s, data, label):
    """Calcula métricas de un perfil de demanda."""
    duration_h = (time_s[-1] - time_s[0]) / 3600
    n_points = len(data)

    metrics = {
        'label': label,
        'duration_h': duration_h,
        'n_points': n_points,
        'mean': np.mean(data),
        'std': np.std(data),
        'max': np.max(data),
        'min': np.min(data),
        'median': np.median(data),
        'p95': np.percentile(data, 95),
        'p99': np.percentile(data, 99),
        'hours_above_0': np.sum(data > 0),
        'hours_above_1': np.sum(data >= 1),
        'hours_above_2': np.sum(data >= 2),
        'utilization': np.sum(data > 0) / len(data) * 100,
    }

    # Potencia promedio (si es variable de potencia)
    if 'pot' in label.lower():
        metrics['mean_kW'] = np.mean(data)
        metrics['max_kW'] = np.max(data)
        metrics['energy_kWh'] = np.sum(data) * (time_s[1] - time_s[0]) / 3600 if n_points > 1 else 0

    print(f"\n--- {label} ---")
    print(f"  Duración:           {metrics['duration_h']:.1f} h ({n_points} puntos)")
    print(f"  Media:              {metrics['mean']:.4f}")
    print(f"  Desviación típica:  {metrics['std']:.4f}")
    print(f"  Máximo:             {metrics['max']:.4f}")
    print(f"  Mínimo:             {metrics['min']:.4f}")
    print(f"  Mediana:            {metrics['median']:.4f}")
    print(f"  P95:                {metrics['p95']:.4f}")
    print(f"  P99:                {metrics['p99']:.4f}")
    print(f"  Horas con demanda:  {metrics['hours_above_0']:.0f} h ({metrics['utilization']:.1f}%)")
    print(f"  Horas >= 1 EV:      {metrics['hours_above_1']:.0f} h")
    print(f"  Horas >= 2 EV:      {metrics['hours_above_2']:.0f} h")
    if 'mean_kW' in metrics:
        print(f"  Potencia media:     {metrics['mean_kW']:.1f} kW")
        print(f"  Potencia máxima:    {metrics['max_kW']:.1f} kW")
        print(f"  Energía total:      {metrics['energy_kWh']:.1f} kWh")

    return metrics

all_metrics = {}
for var_name, var_data in variables.items():
    all_metrics[var_name] = compute_metrics(var_data['time'], var_data['data'], var_name)

# 3. Graficas
print("\n" + "=" * 60)
print("GENERANDO GRÁFICAS")
print("=" * 60)

# Colores consistentes
COLORS = {
    'lab': '#2196F3',    # azul
    'finde': '#FF9800',  # naranja
    'pot': '#4CAF50',    # verde
    'h2': '#9C27B0',     # púrpura
}

def plot_profile(time_s, data, title, xlabel, ylabel, color, filename):
    """Gráfica de perfil temporal."""
    time_h = time_s / 3600  # convertir a horas
    fig, ax = plt.subplots(figsize=(12, 4))
    ax.fill_between(time_h, data, alpha=0.3, color=color)
    ax.plot(time_h, data, color=color, linewidth=0.8)
    ax.set_xlabel(xlabel, fontsize=11)
    ax.set_ylabel(ylabel, fontsize=11)
    ax.set_title(title, fontsize=13, fontweight='bold')
    ax.grid(True, alpha=0.3)
    ax.set_xlim([time_h[0], time_h[-1]])
    plt.tight_layout()
    plt.savefig(os.path.join(FIG_DIR, filename), dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  {filename}")

def plot_histogram(data, title, xlabel, color, filename, bins=30):
    """Histograma de valores."""
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.hist(data, bins=bins, color=color, alpha=0.7, edgecolor='white', linewidth=0.5)
    ax.set_xlabel(xlabel, fontsize=11)
    ax.set_ylabel('Frecuencia (horas)', fontsize=11)
    ax.set_title(title, fontsize=13, fontweight='bold')
    ax.grid(True, alpha=0.3, axis='y')
    plt.tight_layout()
    plt.savefig(os.path.join(FIG_DIR, filename), dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  {filename}")

def plot_profiles_comparison(time1, data1, label1, time2, data2, label2,
                              title, xlabel, ylabel, color1, color2, filename):
    """Comparación de dos perfiles en la misma gráfica."""
    fig, axes = plt.subplots(2, 1, figsize=(12, 6), sharex=True)

    for ax, time_s, data, label, color in [
        (axes[0], time1, data1, label1, color1),
        (axes[1], time2, data2, label2, color2)
    ]:
        time_h = time_s / 3600
        ax.fill_between(time_h, data, alpha=0.3, color=color)
        ax.plot(time_h, data, color=color, linewidth=0.8)
        ax.set_ylabel(ylabel, fontsize=11)
        ax.set_title(label, fontsize=12, fontweight='bold')
        ax.grid(True, alpha=0.3)
        ax.set_xlim([time_h[0], time_h[-1]])

    axes[1].set_xlabel(xlabel, fontsize=11)
    fig.suptitle(title, fontsize=14, fontweight='bold', y=1.02)
    plt.tight_layout()
    plt.savefig(os.path.join(FIG_DIR, filename), dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  {filename}")

def plot_daily_pattern(time_s, data, title, ylabel, color, filename):
    """Patrón diario promedio (agrupar por hora del día)."""
    time_h = time_s / 3600
    hours_of_day = time_h % 24
    # Promediar por hora del día
    hourly_means = np.zeros(24)
    hourly_counts = np.zeros(24)
    for h in range(24):
        mask = (hours_of_day >= h) & (hours_of_day < h + 1)
        if np.any(mask):
            hourly_means[h] = np.mean(data[mask])
            hourly_counts[h] = np.sum(mask > 0)

    fig, ax = plt.subplots(figsize=(10, 5))
    bars = ax.bar(range(24), hourly_means, color=color, alpha=0.7, edgecolor='white')
    ax.set_xlabel('Hora del día', fontsize=11)
    ax.set_ylabel(ylabel, fontsize=11)
    ax.set_title(title, fontsize=13, fontweight='bold')
    ax.set_xticks(range(24))
    ax.set_xticklabels([f'{h:02d}:00' for h in range(24)], rotation=45, ha='right', fontsize=8)
    ax.grid(True, alpha=0.3, axis='y')
    plt.tight_layout()
    plt.savefig(os.path.join(FIG_DIR, filename), dpi=150, bbox_inches='tight')
    plt.close()
    print(f"  {filename}")

# Gráficas EV
if 'demanda_EV_lab' in variables and 'demanda_EV_finde' in variables:
    plot_profiles_comparison(
        variables['demanda_EV_lab']['time'], variables['demanda_EV_lab']['data'], 'Laborable',
        variables['demanda_EV_finde']['time'], variables['demanda_EV_finde']['data'], 'Fin de semana',
        'Número de EV conectados simultáneamente', 'Tiempo (horas)', 'Nº EVs',
        COLORS['lab'], COLORS['finde'], 'ev_conectadosComparativa.png')

if 'pot_EV_lab' in variables and 'pot_EV_finde' in variables:
    plot_profiles_comparison(
        variables['pot_EV_lab']['time'], variables['pot_EV_lab']['data'], 'Laborable',
        variables['pot_EV_finde']['time'], variables['pot_EV_finde']['data'], 'Fin de semana',
        'Potencia demandada por cargadores EV', 'Tiempo (horas)', 'Potencia (kW)',
        COLORS['lab'], COLORS['finde'], 'potencia_evComparativa.png')

# Histogramas
if 'demanda_EV_lab' in variables:
    plot_histogram(variables['demanda_EV_lab']['data'],
                   'Distribución de EVs conectados (Laborable)',
                   'Nº EVs simultáneos', COLORS['lab'], 'hist_ev_lab.png')
if 'demanda_EV_finde' in variables:
    plot_histogram(variables['demanda_EV_finde']['data'],
                   'Distribución de EVs conectados (Fin de semana)',
                   'Nº EVs simultáneos', COLORS['finde'], 'hist_ev_finde.png')
if 'pot_EV_lab' in variables:
    plot_histogram(variables['pot_EV_lab']['data'],
                   'Distribución de potencia EV (Laborable)',
                   'Potencia (kW)', COLORS['pot'], 'hist_pot_lab.png')
if 'pot_EV_finde' in variables:
    plot_histogram(variables['pot_EV_finde']['data'],
                   'Distribución de potencia EV (Fin de semana)',
                   'Potencia (kW)', COLORS['pot'], 'hist_pot_finde.png')

# Patrón diario
if 'demanda_EV_lab' in variables:
    plot_daily_pattern(variables['demanda_EV_lab']['time'], variables['demanda_EV_lab']['data'],
                       'Patrón diario promedio de EVs conectados (Laborable)',
                       'Nº EVs medio', COLORS['lab'], 'patron_diario_lab.png')
if 'demanda_EV_finde' in variables:
    plot_daily_pattern(variables['demanda_EV_finde']['time'], variables['demanda_EV_finde']['data'],
                       'Patrón diario promedio de EVs conectados (Fin de semana)',
                       'Nº EVs medio', COLORS['finde'], 'patron_diario_finde.png')

# Perfil de potencia para la memoria (figure destacada)
if 'pot_EV_lab' in variables:
    time_h = variables['pot_EV_lab']['time'] / 3600
    data = variables['pot_EV_lab']['data']
    fig, ax = plt.subplots(figsize=(14, 4))
    ax.fill_between(time_h, data, alpha=0.4, color=COLORS['pot'])
    ax.plot(time_h, data, color=COLORS['pot'], linewidth=0.6)
    ax.set_xlabel('Hora del día', fontsize=12)
    ax.set_ylabel('Potencia (kW)', fontsize=12)
    ax.set_title('Perfil de potencia demandada por cargadores EV (Laborable)', fontsize=14, fontweight='bold')
    ax.set_xlim([0, 24])
    ax.set_ylim([0, 110])
    ax.set_xticks(range(0, 25, 2))
    ax.set_xticklabels([f'{h:02d}:00' for h in range(0, 25, 2)])
    ax.axhline(y=100, color='red', linestyle='--', alpha=0.4, label='Máx teórico (2×50 kW)')
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(FIG_DIR, 'potencia_ev_ejemplo.png'), dpi=150, bbox_inches='tight')
    plt.close()
    print("  potencia_ev_ejemplo.png (para la memoria)")

# Gráficas H2
if 'demanda_H2_lab' in variables and 'demanda_H2_finde' in variables:
    plot_profiles_comparison(
        variables['demanda_H2_lab']['time'], variables['demanda_H2_lab']['data'], 'Laborable',
        variables['demanda_H2_finde']['time'], variables['demanda_H2_finde']['data'], 'Fin de semana',
        'Número de FCEV conectados simultáneamente', 'Tiempo (horas)', 'Nº FCEV',
        COLORS['h2'], COLORS['h2'], 'h2_conectadosComparativa.png')

if 'demanda_H2_lab' in variables:
    plot_histogram(variables['demanda_H2_lab']['data'],
                   'Distribución de FCEV conectados (Laborable)',
                   'Nº FCEV simultáneos', COLORS['h2'], 'hist_h2_lab.png')
if 'demanda_H2_finde' in variables:
    plot_histogram(variables['demanda_H2_finde']['data'],
                   'Distribución de FCEV conectados (Fin de semana)',
                   'Nº FCEV simultáneos', COLORS['h2'], 'hist_h2_finde.png')

# 4. Resumen comparativo
print("\n" + "=" * 60)
print("TABLA RESUMEN COMPARATIVA")
print("=" * 60)

print(f"\n{'Métrica':<30} {'EV Lab':>10} {'EV Finde':>10} {'H2 Lab':>10} {'H2 Finde':>10}")
print("-" * 70)
for metric_name in ['mean', 'max', 'hours_above_0', 'utilization']:
    row = f"{metric_name:<30}"
    for var in ['demanda_EV_lab', 'demanda_EV_finde', 'demanda_H2_lab', 'demanda_H2_finde']:
        if var in all_metrics:
            val = all_metrics[var][metric_name]
            if metric_name == 'utilization':
                row += f"{val:>9.1f}%"
            else:
                row += f"{val:>10.1f}"
        else:
            row += f"{'N/A':>10}"
    print(row)

print("\n" + "=" * 60)
print(f"ANÁLISIS COMPLETADO. Figuras guardadas en: {FIG_DIR}")
print("=" * 60)
