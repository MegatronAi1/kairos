import type { HealthState, Provenance } from "@/lib/api/types";

export const fmt = (v: number | null | undefined, decimals = 1): string =>
  v === null || v === undefined || !Number.isFinite(v) ? "—" : v.toFixed(decimals);

export const fmtInt = (v: number | null | undefined): string =>
  v === null || v === undefined || !Number.isFinite(v) ? "—" : Math.round(v).toLocaleString("en-IN");

export const fmtHours = (h: number): string => (h < 1 ? `${Math.round(h * 60)} min` : `${h.toFixed(1)} h`);

export const unitDecimals = (unit: string) => (unit === "kg" ? 0 : 1);

export const stateLabel: Record<HealthState, string> = { normal: "Healthy", watch: "Watch", alarm: "Alarm" };

export const stateVar: Record<HealthState, string> = {
  normal: "var(--color-state-healthy)",
  watch: "var(--color-state-watch)",
  alarm: "var(--color-state-alarm)",
};

export const provenanceVar: Record<Provenance, string> = {
  measured: "var(--color-provenance-measured)",
  published: "var(--color-provenance-published)",
  assumed: "var(--color-provenance-assumed)",
  fitted: "var(--color-provenance-assumed)",
  synthetic: "var(--color-provenance-synthetic)",
};

export const strategyLabel = (s: string): string =>
  ({ recipe: "Recipe-driven", operator: "Operator-controlled", pat: "Raman PAT-controlled", fault: "Fault batch" })[
    s
  ] ?? s;

/** Display metadata for sensor and derived keys (matches backend /provenance). */
export const SENSORS: Record<string, { label: string; unit: string; decimals: number; provenance: Provenance }> = {
  do_pct: { label: "Dissolved oxygen", unit: "% sat", decimals: 1, provenance: "synthetic" },
  ph: { label: "pH", unit: "", decimals: 2, provenance: "synthetic" },
  temp_c: { label: "Temperature", unit: "°C", decimals: 2, provenance: "synthetic" },
  rpm: { label: "Agitation", unit: "rpm", decimals: 0, provenance: "synthetic" },
  aeration: { label: "Aeration", unit: "m³/min", decimals: 0, provenance: "synthetic" },
  feed: { label: "Sugar feed", unit: "L/h", decimals: 0, provenance: "synthetic" },
  co2_offgas_pct: { label: "Off-gas CO₂", unit: "%", decimals: 2, provenance: "synthetic" },
  o2_offgas_pct: { label: "Off-gas O₂", unit: "%", decimals: 2, provenance: "synthetic" },
  our: { label: "Oxygen uptake", unit: "mg/L/h", decimals: 2, provenance: "synthetic" },
  cer: { label: "CO₂ evolution", unit: "mg/L/h", decimals: 3, provenance: "synthetic" },
  base_lph: { label: "Base dosing", unit: "L/h", decimals: 1, provenance: "synthetic" },
  cooling_lph: { label: "Cooling water", unit: "L/h", decimals: 0, provenance: "synthetic" },
  heating_lph: { label: "Heating water", unit: "L/h", decimals: 0, provenance: "synthetic" },
  acid_lph: { label: "Acid dosing", unit: "L/h", decimals: 1, provenance: "synthetic" },
  volume_l: { label: "Broth volume", unit: "L", decimals: 0, provenance: "synthetic" },
  power_kw: { label: "Electrical power", unit: "kW", decimals: 0, provenance: "assumed" },
  agitator_kw: { label: "Agitator power", unit: "kW", decimals: 0, provenance: "assumed" },
  compressor_kw: { label: "Compressor power", unit: "kW", decimals: 0, provenance: "assumed" },
  kla: { label: "kLa", unit: "1/h", decimals: 0, provenance: "assumed" },
  kwh_cum: { label: "Energy used", unit: "kWh", decimals: 0, provenance: "assumed" },
};

export const sensorLabel = (k: string) => SENSORS[k]?.label ?? k.replaceAll("_", " ");

export const valueOf = (
  tick: { sensors: Record<string, number | null>; derived: Record<string, number | null> } | null,
  key: string,
): number | null => tick?.sensors[key] ?? tick?.derived[key] ?? null;
