import type {
  AckEvent,
  AlarmEvent,
  EnergyRecommendation,
  ChatEvent,
  ControlAction,
  ProvenanceResponse,
  ReactorSummary,
  Trajectory,
} from "./types";

import { authToken } from "@/lib/session";

const BASE = import.meta.env.VITE_API_BASE ?? "";

export const apiUrl = (path: string) => `${BASE}/api/v1${path}`;

export function wsUrl(): string {
  const base = BASE || window.location.origin;
  const url = new URL("/ws", base.replace(/^http/, "ws"));
  const token = authToken();
  if (token) url.searchParams.set("token", token);
  return url.toString();
}

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(apiUrl(path), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(authToken() ? { Authorization: `Bearer ${authToken()}` } : {}),
      ...init.headers,
    },
  });
  if (!res.ok) throw new ApiError(res.status, `${res.status} ${res.statusText}`);
  return (await res.json()) as T;
}

export type FaultKind = "oxygen" | "feed" | "temperature";

export interface FeedbackIn {
  category: "bug" | "idea" | "data" | "other";
  rating: number | null;
  message: string;
  source: "web";
  reactor_id: string | null;
  page: string;
  user: string | null;
}

export const api = {
  reactors: () => request<ReactorSummary[]>("/reactors"),
  events: (id: string) => request<AlarmEvent[]>(`/reactors/${id}/events`),
  control: (id: string, action: ControlAction, extra: Record<string, unknown> = {}) =>
    request<ReactorSummary>(`/reactors/${id}/control`, {
      method: "POST",
      body: JSON.stringify({ action, ...extra }),
    }),
  ack: (id: string) =>
    request<AckEvent>(`/reactors/${id}/ack`, { method: "POST", body: JSON.stringify({ by: "control room" }) }),
  feedback: (body: FeedbackIn) =>
    request<{ id: string; received_at: number }>("/feedback", { method: "POST", body: JSON.stringify(body) }),
  triggerFault: (reactorId: string, kind: FaultKind) =>
    request<{ fault_batch: number; description: string; expected_alarm_in_s: number }>("/demo/trigger-fault", {
      method: "POST",
      body: JSON.stringify({ reactor_id: reactorId, kind }),
    }),
  trajectory: (batch: number, keys: string[], untilH?: number, every = 5) => {
    const q = new URLSearchParams({ every: String(every) });
    keys.forEach((k) => q.append("keys", k));
    if (untilH !== undefined) q.set("until_h", String(untilH));
    return request<Trajectory>(`/batches/${batch}/trajectory?${q}`);
  },
  provenance: () => request<ProvenanceResponse>("/provenance"),
  metrics: () => request<Metrics>("/metrics"),
  whatif: (id: string) => request<import("@/components/viz").WhatIf>(`/reactors/${id}/whatif`),
  forecastHistory: (id: string) =>
    request<{ t_h: number[]; p10: number[]; p50: number[]; p90: number[]; typical: number; unit: string }>(
      `/reactors/${id}/forecast-history`,
    ),
  recommendation: (id: string, mode: "energy" | "rescue" = "energy") =>
    request<EnergyRecommendation>(`/reactors/${id}/recommendation?mode=${mode}`),
  tenant: () => request<{ id: string; name: string; tagline: string; fictional: boolean }>("/tenant"),
  plants: () => request<PlantRollup[]>("/plants"),
  plant: (id: string) => request<PlantRollup & { reactor_summaries: ReactorSummary[] }>(`/plants/${id}`),
  demoAccounts: () => request<{ email: string; password: string; name: string; role: string }[]>("/auth/demo-accounts"),
  login: (email: string, password: string) =>
    request<{ token: string; user: { email: string; name: string; role: string }; tenant: { id: string; name: string } }>(
      "/auth/login",
      { method: "POST", body: JSON.stringify({ email, password }) },
    ),
  agentStatus: () => request<{ enabled: boolean; model_chat: string | null }>("/agent/status"),
  impact: (period: ImpactPeriod, plant = "all") =>
    request<Impact>(`/impact?${new URLSearchParams({ period, plant })}`),
};

/** Streams the copilot's answer (server-sent events over a POST). */
export async function* chatStream(
  messages: { role: "user" | "assistant"; content: string }[],
  reactorId: string | undefined,
  signal?: AbortSignal,
  processId?: string,
): AsyncGenerator<ChatEvent> {
  const res = await fetch(apiUrl("/agent/chat"), {
    method: "POST",
    signal,
    headers: {
      "Content-Type": "application/json",
      ...(authToken() ? { Authorization: `Bearer ${authToken()}` } : {}),
    },
    body: JSON.stringify({ messages, reactor_id: reactorId, process_id: processId }),
  });
  if (!res.ok || !res.body) {
    yield { type: "error", message: `Copilot unavailable (${res.status}).` };
    return;
  }
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const frames = buffer.split(/\r?\n\r?\n/);
    buffer = frames.pop() ?? "";
    for (const frame of frames) {
      const data = frame
        .split(/\r?\n/)
        .filter((l) => l.startsWith("data:"))
        .map((l) => l.slice(5).trim())
        .join("");
      if (data) yield JSON.parse(data) as ChatEvent;
    }
  }
}

// Metrics payloads written by ml/scripts/evaluate_all.py (artifacts/metrics/*.json).
export interface ErrorStats {
  mae: number;
  rmse: number;
  mape_pct: number;
  r2: number;
}

export interface Metrics {
  yield?: {
    unit: string;
    provenance: string;
    n_test_batches: number;
    typical_yield_kg: number;
    checkpoints: {
      progress: number;
      models: Record<string, ErrorStats>;
      coverage_80: number;
      coverage_90: number;
      mean_width_80_kg: number;
    }[];
    convergence_curve_mae_kg: ({ progress: number } & Record<string, number>)[];
    overall_hourly_coverage: { coverage_80: number; coverage_90: number };
    fault_batches?: {
      checkpoints: { progress: number; kairos: ErrorStats; naive_mean: ErrorStats; coverage_80: number }[];
    };
    notes: string[];
  };
  faults?: {
    detector: Record<string, unknown> & { alarm_threshold: number; persistence_h: number; monitored: string[] };
    per_fault_batch: {
      batch: number;
      onset_h: number;
      onset_method: string;
      fault_variable: string;
      detected: boolean;
      first_alarm_h: number | null;
      delay_h: number | null;
      baseline_delay_h: number | null;
    }[];
    per_normal_batch: { batch: number; kairos_false_alarms: number; baseline_false_alarms: number }[];
    summary: Record<
      "kairos" | "mspc_baseline",
      {
        detected: number;
        n_fault_batches: number;
        median_delay_h: number | null;
        false_alarms_per_batch: number;
        false_alarms_per_100_batch_hours: number;
      }
    >;
    tradeoff: {
      threshold: number;
      persistence_rows: number;
      detected: number;
      median_delay_h: number | null;
      false_alarms_per_batch: number;
    }[];
    notes: string[];
  };
  drivers?: {
    method: string;
    drivers: { feature: string; label: string; importance: number; share: number }[];
    interactions: { a_label: string; b_label: string; strength_kg: number; sentence: string }[];
  };
  energy?: {
    provenance: string;
    method: string;
    target_do_pct: number;
    mean_saving_pct: number;
    kwh_saved_per_batch: number;
    co2_saved_kg_per_batch: number;
    inr_saved_per_batch: number;
    per_batch: { batch: number; kwh_now: number; kwh_kairos: number; saving_pct: number }[];
    sensitivity: { margin_pct: number; target_do_pct: number; mean_saving_pct: number }[];
    pareto: {
      batch: number;
      actual_kwh: number;
      target_do_pct: number;
      points: { rpm: number; aeration: number; kwh: number; do_p5_pct: number; hours_below_target_pct: number }[];
    };
    yield_check_pct_change_at_70pct: { mean: number; min: number; max: number };
    notes: string[];
  };
}

export interface PlantRollup {
  id: string;
  code: string;
  name: string;
  city: string;
  country: string;
  lat: number;
  lon: number;
  commissioned: string;
  process_id: string;
  process_name: string;
  process_family: "biomass" | "precision" | null;
  reactor_ids: string[];
  reactors: number;
  state: "normal" | "watch" | "alarm";
  alarms_open: number;
  watch: number;
  power_kw: number;
  energy_kwh: number;
  forecast_vs_typical_pct: number | null;
}

export type ImpactPeriod = "month" | "quarter" | "year";

export interface ImpactRow {
  period: string;
  batches: number;
  failed_before_baseline: number;
  failed_actual: number;
  batches_rescued: number;
  energy_kwh_baseline: number;
  energy_kwh_actual: number;
  energy_saved_kwh: number;
  co2_saved_kg: number;
  feedstock_saved_kg: number;
  money_saved_inr: number;
  money_saved_usd: number;
  breakdown_inr: { rescued_batches: number; energy: number; feedstock: number };
}

export interface ImpactAssumption {
  key: string;
  label: string;
  value: number | string;
  unit: string;
  provenance: "measured" | "assumed" | "simulated";
}

export interface Impact {
  tenant: string;
  period: ImpactPeriod;
  plant: string;
  kairos_live_from: string;
  months: [string, string];
  provenance: {
    simulated: string;
    measured_rates: { detection_rate: number; energy_saving_pct: number; source: string };
    assumptions: ImpactAssumption[];
  };
  series: ImpactRow[];
  totals: ImpactRow;
  baseline_year: ImpactRow;
  by_plant: {
    plant_id: string;
    name: string;
    city: string;
    money_saved_inr: number;
    money_saved_usd: number;
    energy_saved_kwh: number;
    feedstock_saved_kg: number;
    batches_rescued: number;
  }[];
}

/** Downloads an impact export (xlsx | pdf) with the session token. */
export async function downloadImpact(ext: "xlsx" | "pdf", period: ImpactPeriod, plant: string): Promise<void> {
  const res = await fetch(apiUrl(`/impact/export.${ext}?${new URLSearchParams({ period, plant })}`), {
    headers: authToken() ? { Authorization: `Bearer ${authToken()}` } : {},
  });
  if (!res.ok) throw new ApiError(res.status, `${res.status} ${res.statusText}`);
  const name = /filename="([^"]+)"/.exec(res.headers.get("Content-Disposition") ?? "")?.[1] ?? `kairos-impact.${ext}`;
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
