import { motion } from "framer-motion";

import { ConfidenceMeter, EvidenceChip, ProvenanceChip, Tip } from "@/components/primitives";
import type { HealthState, InsightEvent, Provenance } from "@/lib/api/types";
import { fmt, fmtHours, stateVar } from "@/lib/format";

export function Sparkline({ values, color = "var(--color-accent-500)", width = 88, height = 26 }: {
  values: number[];
  color?: string;
  width?: number;
  height?: number;
}) {
  const v = values.filter(Number.isFinite);
  if (v.length < 3) return <span style={{ width, height }} className="inline-block" />;
  let lo = Math.min(...v);
  let hi = Math.max(...v);
  if (hi - lo < 1e-9) {
    lo -= 1;
    hi += 1;
  }
  const pts = v
    .map((y, i) => `${((i / (v.length - 1)) * width).toFixed(1)},${(height - ((y - lo) / (hi - lo)) * height).toFixed(1)}`)
    .join(" ");
  return (
    <svg width={width} height={height} aria-hidden className="shrink-0 overflow-visible">
      <polyline points={pts} fill="none" stroke={color} strokeWidth={1.5} strokeLinejoin="round" opacity={0.85} />
    </svg>
  );
}

/** Label, value, unit, optional p10-p90 range, provenance chip and sparkline. */
export function MetricReadout({
  label,
  value,
  unit,
  decimals = 1,
  range,
  provenance = "synthetic",
  source,
  history = [],
  accent,
  large = false,
}: {
  label: string;
  value: number | null;
  unit: string;
  decimals?: number;
  range?: [number, number];
  provenance?: Provenance;
  source?: string;
  history?: number[];
  accent?: string;
  large?: boolean;
}) {
  return (
    <div className="flex items-center gap-3 py-2.5" aria-label={`${label} ${fmt(value, decimals)} ${unit}`}>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="truncate text-sm text-text-secondary">{label}</span>
          <ProvenanceChip provenance={provenance} source={source} />
        </div>
        <div className="flex items-baseline gap-1">
          <span className={`num font-medium ${large ? "text-2xl" : "text-xl"}`} style={{ color: accent }}>
            {fmt(value, decimals)}
          </span>
          {unit && <span className="text-sm text-text-muted">{unit}</span>}
        </div>
        {range && (
          <div className="num text-xs text-text-muted">
            {fmt(range[0], decimals)} to {fmt(range[1], decimals)} {unit}
          </div>
        )}
      </div>
      <Sparkline values={history} color={accent} />
    </div>
  );
}

export function InsightCardView({ insight, state }: { insight: InsightEvent; state: HealthState }) {
  const c = insight.card;
  return (
    <motion.article
      key={`${insight.ts}-${insight.source}`}
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2, ease: [0.2, 0.8, 0.2, 1] }}
      className="overflow-hidden rounded-card border border-border-subtle bg-bg-surface"
      style={{ borderLeft: `3px solid ${stateVar[state]}` }}
    >
      <div className="p-4">
        <div className="flex items-center justify-between">
          <span className="eyebrow">{insight.source === "agent" ? "Kairos copilot" : "Kairos rules"}</span>
          <ConfidenceMeter confidence={c.confidence} />
        </div>
        <h3 className="mt-2 text-lg font-medium">{c.title}</h3>
        <p className="mt-1 text-text-secondary">{c.summary}</p>
        <div className="mt-3 rounded-control p-3" style={{ background: "var(--color-accent-glow)" }}>
          <div className="eyebrow" style={{ color: "var(--color-accent-500)" }}>
            Do this
          </div>
          <p className="mt-0.5 font-medium">{c.action}</p>
          {c.expected_effect && (
            <p className="mt-1 text-sm text-text-secondary">
              Expected: {c.expected_effect}
              {/estimate/i.test(c.expected_effect) ? "" : " (model estimate)"}
            </p>
          )}
        </div>
        {c.evidence.length > 0 && (
          <div className="mt-3 flex flex-wrap items-center gap-1.5">
            <span className="text-xs text-text-muted">Based on</span>
            {c.evidence.map((e) => (
              <EvidenceChip key={e} source={e} />
            ))}
          </div>
        )}
      </div>
    </motion.article>
  );
}

export const PONR_TOOLTIP =
  "Point of no return: the latest time the best available correction still recovers at least 90% of a normal batch yield, according to Kairos models. Model estimate, not a guarantee.";

/** Large monospace countdown with a draining ring. */
export function PonrCountdown({ remainingH, totalH, size = 168 }: { remainingH: number; totalH: number; size?: number }) {
  const frac = Math.max(0, Math.min(1, remainingH / Math.max(totalH, 1e-6)));
  const r = size / 2 - 6;
  const circ = 2 * Math.PI * r;
  const color = remainingH <= 1 ? "var(--color-state-alarm)" : "var(--color-state-watch)";
  return (
    <Tip content={PONR_TOOLTIP}>
      <div
        tabIndex={0}
        className="relative mx-auto"
        style={{ width: size, height: size }}
        aria-label={`Point of no return in ${fmtHours(remainingH)}, model estimate`}
      >
        <svg width={size} height={size} className="-rotate-90">
          <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--color-border-subtle)" strokeWidth={6} />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={color}
            strokeWidth={6}
            strokeLinecap="round"
            strokeDasharray={circ}
            strokeDashoffset={circ * (1 - frac)}
            style={{ transition: "stroke-dashoffset 320ms cubic-bezier(0.2,0.8,0.2,1)" }}
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <span className="num text-3xl font-semibold">{fmtHours(remainingH)}</span>
          <span className="text-xs text-text-secondary">to point of no return</span>
          <span className="text-[11px] text-text-muted">model estimate</span>
        </div>
      </div>
    </Tip>
  );
}
