/// Number formatting shared by all readouts. Units are always shown by callers.
String fmt(double? v, {int decimals = 1}) {
  if (v == null || v.isNaN || v.isInfinite) return '—';
  return v.toStringAsFixed(decimals);
}

/// Hours as "4.5 h" or "45 min" under one hour.
String fmtHours(double h) => h < 1 ? '${(h * 60).round()} min' : '${h.toStringAsFixed(1)} h';

/// Display labels and units for sensor keys (matches backend /provenance).
const sensorMeta = <String, ({String label, String unit, int decimals})>{
  'do_pct': (label: 'Dissolved oxygen', unit: '% sat', decimals: 1),
  'ph': (label: 'pH', unit: '', decimals: 2),
  'temp_c': (label: 'Temperature', unit: '°C', decimals: 1),
  'rpm': (label: 'Agitation', unit: 'rpm', decimals: 0),
  'aeration': (label: 'Aeration', unit: 'm³/min', decimals: 0),
  'feed': (label: 'Sugar feed', unit: 'L/h', decimals: 0),
  'co2_offgas_pct': (label: 'Off-gas CO₂', unit: '%', decimals: 2),
  'o2_offgas_pct': (label: 'Off-gas O₂', unit: '%', decimals: 1),
  'our': (label: 'Oxygen uptake', unit: 'mg/L/h', decimals: 2),
  'power_kw': (label: 'Power', unit: 'kW', decimals: 0),
  'kwh_cum': (label: 'Energy used', unit: 'kWh', decimals: 0),
};

String sensorLabel(String key) => sensorMeta[key]?.label ?? key.replaceAll('_', ' ');
