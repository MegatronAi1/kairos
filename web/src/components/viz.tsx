import { useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { Leaf, Zap } from "lucide-react";

import { ProvenanceChip, Skeleton, Tip } from "@/components/primitives";
import { api } from "@/lib/api/client";
import type { HealthState, TickEvent } from "@/lib/api/types";
import { fmt, fmtInt, stateVar } from "@/lib/format";

const arc = (cx: number, cy: number, r: number, a0: number, a1: number) => {
  const p = (a: number) => [cx + r * Math.cos(a), cy + r * Math.sin(a)];
  const [x0, y0] = p(a0);
  const [x1, y1] = p(a1);
  return `M ${x0} ${y0} A ${r} ${r} 0 ${a1 - a0 > Math.PI ? 1 : 0} 1 ${x1} ${y1}`;
};

/** Health 0-100 as a ring coloured by state. */
export function HealthRing({ score, state, size = 64 }: { score: number | null; state: HealthState; size?: number }) {
  const s = Math.max(0, Math.min(100, score ?? 0));
  const r = size / 2 - 5;
  const c = 2 * Math.PI * r;
  return (
    <Tip content="Health score: 100 means indistinguishable from normal batches at this point in the batch.">
      <div tabIndex={0} className="relative shrink-0" style={{ width: size, height: size }} aria-label={`Health ${Math.round(s)} of 100`}>
        <svg width={size} height={size} className="-rotate-90">
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--color-border-subtle)" strokeWidth={5} />
          <motion.circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={stateVar[state]}
            strokeWidth={5}
            strokeLinecap="round"
            strokeDasharray={c}
            animate={{ strokeDashoffset: c * (1 - s / 100) }}
            transition={{ duration: 0.32, ease: [0.2, 0.8, 0.2, 1] }}
          />
        </svg>
        <span className="display-num absolute inset-0 flex items-center justify-center font-semibold" style={{ fontSize: size * 0.3 }}>
          {score === null ? "—" : Math.round(s)}
        </span>
      </div>
    </Tip>
  );
}

/** Semicircular gauge with a shaded normal band and a needle. */
export function Gauge({
  label,
  value,
  unit,
  min,
  max,
  band,
  warnBelow,
  decimals = 1,
  history = [],
}: {
  label: string;
  value: number | null;
  unit: string;
  min: number;
  max: number;
  band: [number, number];
  warnBelow?: number;
  decimals?: number;
  history?: number[];
}) {
  const W = 132;
  const cx = W / 2;
  const cy = 64;
  const r = 52;
  const ang = (v: number) => Math.PI + (Math.max(min, Math.min(max, v)) - min) / (max - min) * Math.PI;
  const v = value ?? min;
  const inBand = value !== null && value >= band[0] && value <= band[1];
  const low = warnBelow !== undefined && value !== null && value < warnBelow;
  const color = low ? "var(--color-state-alarm)" : inBand ? "var(--color-accent-500)" : "var(--color-state-watch)";
  const a = ang(v);
  const trend = history.filter(Number.isFinite);
  const delta = trend.length > 10 ? trend[trend.length - 1]! - trend[trend.length - 11]! : 0;
  return (
    <figure className="m-0 flex flex-col items-center" aria-label={`${label} ${fmt(value, decimals)} ${unit}`}>
      <svg viewBox={`0 0 ${W} 78`} className="w-full max-w-[132px]">
        <path d={arc(cx, cy, r, Math.PI, 2 * Math.PI)} stroke="var(--color-border-subtle)" strokeWidth={8} fill="none" strokeLinecap="round" />
        <path d={arc(cx, cy, r, ang(band[0]), ang(band[1]))} stroke="var(--color-accent-glow)" strokeWidth={8} fill="none" />
        <path d={arc(cx, cy, r, Math.PI, Math.max(Math.PI + 0.001, a))} stroke={color} strokeWidth={8} fill="none" strokeLinecap="round" />
        {warnBelow !== undefined && (
          <line
            x1={cx + (r - 9) * Math.cos(ang(warnBelow))}
            y1={cy + (r - 9) * Math.sin(ang(warnBelow))}
            x2={cx + (r + 9) * Math.cos(ang(warnBelow))}
            y2={cy + (r + 9) * Math.sin(ang(warnBelow))}
            stroke="var(--color-state-alarm)"
            strokeWidth={2}
          />
        )}
        <motion.line
          x1={cx}
          y1={cy}
          animate={{ x2: cx + (r - 14) * Math.cos(a), y2: cy + (r - 14) * Math.sin(a) }}
          transition={{ duration: 0.32 }}
          stroke="var(--color-text-primary)"
          strokeWidth={2}
          strokeLinecap="round"
        />
        <circle cx={cx} cy={cy} r={4} fill="var(--color-text-primary)" />
      </svg>
      <div className="-mt-1 flex items-baseline gap-1">
        <span className="display-num text-xl font-semibold" style={{ color: low ? color : undefined }}>
          {fmt(value, decimals)}
        </span>
        <span className="text-xs text-text-muted">{unit}</span>
        {Math.abs(delta) > 1e-6 && (
          <span className="text-xs text-text-muted" aria-label={delta > 0 ? "rising" : "falling"}>
            {delta > 0 ? "▲" : "▼"}
          </span>
        )}
      </div>
      <figcaption className="text-xs text-text-secondary">{label}</figcaption>
    </figure>
  );
}

/** Forecast fan: the p10-p90 band narrowing over the batch, p50 line, typical-batch reference.
 * Server history (from batch start) is merged with live ticks so it draws immediately. */
export function ForecastFan({ reactorId, ticks, height = 150 }: { reactorId: string; ticks: TickEvent[]; height?: number }) {
  const lastT = ticks.length ? ticks[ticks.length - 1]!.t_h : 0;
  const q = useQuery({
    queryKey: ["forecast-history", reactorId, Math.floor(lastT / 10)],
    queryFn: () => api.forecastHistory(reactorId),
    staleTime: 30_000,
  });
  type P = { t: number; p10: number; p50: number; p90: number };
  const hist: P[] = q.data ? q.data.t_h.map((t, i) => ({ t, p10: q.data!.p10[i]!, p50: q.data!.p50[i]!, p90: q.data!.p90[i]! })) : [];
  const cut = hist.length ? hist[hist.length - 1]!.t : -1;
  const live: P[] = ticks
    .filter((t) => t.forecast && t.t_h > cut)
    .map((t) => ({ t: t.t_h, p10: t.forecast!.p10, p50: t.forecast!.p50, p90: t.forecast!.p90 }));
  const pts = [...hist, ...live];
  if (q.isLoading) return <Skeleton className="h-28 w-full" />;
  if (pts.length < 3) return <p className="text-sm text-text-muted">The fan fills in as the batch runs.</p>;
  const W = 290;
  const H = height;
  const pad = { l: 2, r: 52, t: 8, b: 8 };
  const last = pts[pts.length - 1]!;
  const typical = q.data?.typical ?? last.p50;
  const hi = Math.max(typical * 1.3, ...pts.map((p) => p.p90));
  const t0 = pts[0]!.t;
  const t1 = Math.max(last.t, t0 + 1e-6);
  const x = (v: number) => pad.l + ((v - t0) / (t1 - t0)) * (W - pad.l - pad.r);
  const y = (v: number) => pad.t + (1 - v / hi) * (H - pad.t - pad.b);
  const band =
    pts.map((p, i) => `${i ? "L" : "M"}${x(p.t)},${y(p.p90)}`).join(" ") +
    " " +
    [...pts].reverse().map((p) => `L${x(p.t)},${y(p.p10)}`).join(" ") +
    " Z";
  const line = pts.map((p, i) => `${i ? "L" : "M"}${x(p.t)},${y(p.p50)}`).join(" ");
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label={`Final yield forecast ${fmtInt(last.p50)} kg, range ${fmtInt(last.p10)} to ${fmtInt(last.p90)}`}>
      <path d={band} fill="var(--color-accent-glow)" />
      <line x1={pad.l} x2={W - pad.r} y1={y(typical)} y2={y(typical)} stroke="var(--color-chart-reference)" strokeDasharray="5 4" />
      <text x={W - pad.r + 6} y={y(typical) + 4} fontSize="10" fill="var(--color-text-muted)">
        typical
      </text>
      <path d={line} fill="none" stroke="var(--color-accent-500)" strokeWidth={2} />
      <circle cx={x(last.t)} cy={y(last.p50)} r={4} fill="var(--color-accent-500)" />
      <text x={W - pad.r + 6} y={y(last.p50) + 4} fontSize="11" fill="var(--color-text-primary)" className="num">
        {fmtInt(last.p50)}
      </text>
    </svg>
  );
}

/** Where the electricity goes right now: agitator vs compressor. */
export function PowerDonut({ agitator, compressor, size = 92 }: { agitator: number | null; compressor: number | null; size?: number }) {
  const a = agitator ?? 0;
  const c = compressor ?? 0;
  const total = a + c || 1;
  const r = size / 2 - 7;
  const C = 2 * Math.PI * r;
  const fa = a / total;
  return (
    <div className="flex items-center gap-4">
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} className="-rotate-90" aria-hidden>
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--color-chart-series2)" strokeWidth={9} />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke="var(--color-chart-series1)"
            strokeWidth={9}
            strokeDasharray={`${Math.max(0, fa * C - 2)} ${C}`}
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="display-num text-lg font-semibold">{fmtInt(a + c)}</span>
          <span className="text-[11px] text-text-muted">kW</span>
        </div>
      </div>
      <ul className="space-y-1 text-sm">
        <li className="flex items-center gap-2">
          <span className="h-2.5 w-2.5 rounded-sm" style={{ background: "var(--color-chart-series1)" }} />
          Agitator <span className="num text-text-secondary">{fmtInt(a)} kW</span>
        </li>
        <li className="flex items-center gap-2">
          <span className="h-2.5 w-2.5 rounded-sm" style={{ background: "var(--color-chart-series2)" }} />
          Air compressor <span className="num text-text-secondary">{fmtInt(c)} kW</span>
        </li>
      </ul>
    </div>
  );
}

/** Energy vs oxygen: current power split, and Kairos's cheaper setting that keeps oxygen safe. */
export function EnergyPanel({ reactorId, tick, mode }: { reactorId: string; tick: TickEvent | null; mode: "energy" | "rescue" }) {
  const bucket = tick ? Math.floor(tick.t_h / 4) : 0; // refresh every 4 batch-hours
  const q = useQuery({
    queryKey: ["recommendation", reactorId, mode, bucket],
    queryFn: () => api.recommendation(reactorId, mode),
    enabled: !!tick,
    staleTime: 60_000,
  });
  const rec = q.data;
  return (
    <div className="space-y-3">
      <PowerDonut agitator={tick?.derived.agitator_kw ?? null} compressor={tick?.derived.compressor_kw ?? null} />
      {q.isLoading ? (
        <Skeleton className="h-20" />
      ) : q.isError || !rec ? (
        <p className="text-sm text-text-muted">Recommendation unavailable right now.</p>
      ) : (
        <div className="rounded-control p-3" style={{ background: "var(--color-accent-glow)" }}>
          <div className="flex items-center justify-between">
            <span className="overline" style={{ color: "var(--color-accent-500)" }}>
              {mode === "rescue" ? "Rescue setting" : "Save energy"}
            </span>
            <ProvenanceChip provenance="assumed" source={rec.assumptions.join(" · ")} />
          </div>
          <p className="mt-1 font-medium">{rec.action}</p>
          {mode === "energy" && rec.power_saving_kw > 0.5 ? (
            <div className="mt-2 grid grid-cols-3 gap-2 text-center">
              <Stat icon={<Zap size={13} />} value={`${fmt(rec.power_saving_kw, 1)} kW`} label={`${fmt(rec.energy_delta_pct, 0)}% power`} />
              <Stat icon={<Zap size={13} />} value={`${fmtInt(rec.kwh_saved_rest_of_batch)}`} label="kWh rest of batch" />
              <Stat icon={<Leaf size={13} />} value={`${fmtInt(rec.co2_saved_kg)} kg`} label="CO₂ avoided" />
            </div>
          ) : null}
          <OxygenSafety current={rec.current.do_pct} next={rec.recommended.do_pct} target={rec.target_do_pct} />
        </div>
      )}
    </div>
  );
}

function Stat({ icon, value, label }: { icon: React.ReactNode; value: string; label: string }) {
  return (
    <div className="rounded-control bg-bg-surface px-2 py-1.5">
      <div className="display-num flex items-center justify-center gap-1 font-semibold">
        {icon}
        {value}
      </div>
      <div className="text-[11px] text-text-muted">{label}</div>
    </div>
  );
}

/** DO now vs after the change, against the safety target. */
function OxygenSafety({ current, next, target }: { current: number; next: number; target: number }) {
  const max = 110;
  const pos = (v: number) => `${(Math.max(0, Math.min(max, v)) / max) * 100}%`;
  return (
    <div className="mt-3">
      <div className="flex justify-between text-xs text-text-secondary">
        <span>Dissolved oxygen after the change</span>
        <span className="num">
          {fmt(current, 0)}% → {fmt(next, 0)}% sat
        </span>
      </div>
      <div className="relative mt-1.5 h-2 rounded-full bg-bg-inset">
        <div className="absolute inset-y-0 left-0 rounded-full" style={{ width: pos(target), background: "color-mix(in srgb, var(--color-state-alarm) 25%, transparent)" }} />
        <span className="absolute -top-1 h-4 w-0.5" style={{ left: pos(target), background: "var(--color-state-alarm)" }} />
        <span className="absolute top-1/2 h-3 w-3 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-bg-surface" style={{ left: pos(current), background: "var(--color-text-muted)" }} />
        <span className="absolute top-1/2 h-3 w-3 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-bg-surface" style={{ left: pos(next), background: "var(--color-accent-500)" }} />
      </div>
      <div className="mt-1 text-[11px] text-text-muted">Red zone: below the {fmt(target, 0)}% safety target (critical + margin). Model estimate.</div>
    </div>
  );
}
