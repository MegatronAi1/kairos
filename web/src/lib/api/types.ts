// Wire types mirroring backend/app/schemas.py (docs/API.md).
// Regenerate the OpenAPI types with `pnpm types` when the schema changes.

export type HealthState = "normal" | "watch" | "alarm";
export type Confidence = "low" | "medium" | "high";
export type Provenance = "measured" | "published" | "assumed" | "synthetic" | "fitted";

export interface Contribution {
  var: string;
  pct: number;
  dir: "high" | "low";
}

export interface Forecast {
  p50: number;
  p10: number;
  p90: number;
  unit: string;
  vs_golden_pct: number;
  confidence: Confidence;
  provenance: Provenance;
}

export interface Health {
  score: number;
  state: HealthState;
  t2: number | null;
  t2_limit: number | null;
  spe: number | null;
  spe_limit: number | null;
  top_contributors: Contribution[];
  since_h: number | null;
}

interface EventBase {
  reactor_id: string;
  ts: number;
  t_h: number;
  progress: number;
  batch_id: number;
}

export interface TickEvent extends EventBase {
  type: "tick";
  sensors: Record<string, number | null>;
  derived: Record<string, number | null>;
  forecast: Forecast | null;
  health: Health | null;
}

export interface AlarmEvent extends EventBase {
  type: "alarm";
  state: HealthState;
  previous_state: HealthState;
  severity: "info" | "warning" | "critical";
  contributors: Contribution[];
  ponr_hours: number | null;
}

export interface InsightCard {
  title: string;
  summary: string;
  action: string;
  expected_effect: string;
  confidence: Confidence;
  ponr_hours: number | null;
  evidence: string[];
}

export interface InsightEvent extends EventBase {
  type: "insight";
  card: InsightCard;
  source: "agent" | "template";
}

export interface AckEvent extends EventBase {
  type: "ack";
  by: string;
}

export type KEvent = TickEvent | AlarmEvent | InsightEvent | AckEvent;

export interface ReactorSummary {
  id: string;
  batch_id: number;
  strategy: string;
  is_fault_batch: boolean;
  running: boolean;
  speed_h_per_s: number;
  t_h: number;
  t_end_h: number;
  progress: number;
  state: HealthState;
  acknowledged: boolean;
  last_tick: TickEvent | null;
  last_insight: InsightEvent | null;
}

export interface SnapshotMessage {
  type: "snapshot";
  reactors: ReactorSummary[];
}

export interface SensorSpec {
  key: string;
  label: string;
  unit: string;
  provenance: Provenance;
  note: string;
}

export interface ProvenanceResponse {
  data_sources: { name: string; provenance: Provenance; note: string; url: string }[];
  sensors: SensorSpec[];
  constants: { key: string; value: number; unit: string; provenance: Provenance; source: string }[];
}

export type ControlAction = "start" | "pause" | "seek" | "speed" | "swap" | "restart";

export interface Trajectory {
  batch_id: number;
  t_h: number[];
  series: Record<string, number[]>;
}

export type ChatEvent =
  | { type: "text"; delta: string }
  | { type: "tool"; name: string; input: Record<string, unknown> }
  | { type: "evidence"; items: string[] }
  | { type: "done" }
  | { type: "error"; message: string };

export interface SetpointOption {
  rpm: number;
  aeration: number;
  power_kw: number;
  do_pct: number;
  feasible: boolean;
}

export interface EnergyRecommendation {
  reactor_id: string;
  mode: "energy" | "rescue";
  t_h: number;
  action: string;
  current: SetpointOption;
  recommended: SetpointOption;
  power_saving_kw: number;
  energy_delta_pct: number;
  kwh_saved_rest_of_batch: number;
  co2_saved_kg: number;
  inr_saved: number;
  target_do_pct: number;
  options: SetpointOption[];
  assumptions: string[];
  provenance: Provenance;
}
