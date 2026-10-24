import { motion } from "framer-motion";
import { useState } from "react";

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

/** Compact alarm card for the copilot rail: what happened, what to do, how long is
 * left. Summary, expected effect and evidence open on demand. */
export function InsightCardView({
  insight,
  state,
  ponrLeftH = null,
  onSimulate,
}: {
  insight: InsightEvent;
  state: HealthState;
  ponrLeftH?: number | null;
  onSimulate?: () => void;
}) {
  const c = insight.card;
  const [more, setMore] = useState(false);
  const color = stateVar[state];
  return (
    <motion.article
      key={`${insight.ts}-${insight.source}`}
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2, ease: [0.2, 0.8, 0.2, 1] }}
      className="overflow-hidden rounded-card border border-border-subtle bg-bg-surface"
      style={{ borderLeft: `3px solid ${color}` }}
    >
      <div className="space-y-2 px-3.5 py-3">
        <div className="flex items-start gap-2">
          <h3 className="min-w-0 flex-1 text-sm font-semibold leading-snug">{c.title}</h3>
          {ponrLeftH !== null && (
            <Tip content={PONR_TOOLTIP}>
              <span
                tabIndex={0}
                className="num shrink-0 rounded-full px-2 py-0.5 text-[11px] font-semibold"
                style={{ color, background: `color-mix(in srgb, ${color} 14%, transparent)` }}
              >
                {ponrLeftH > 0 ? `${fmtHours(ponrLeftH)} left` : "PONR passed"}
              </span>
            </Tip>
          )}
        </div>
        <p className="text-[13px] leading-snug">
          <span className="font-semibold" style={{ color: "var(--color-accent-500)" }}>
            Do this:{" "}
          </span>
          {c.action}
        </p>
        {more && (
          <div className="space-y-2 border-t border-border-subtle pt-2 text-xs text-text-secondary">
            <p>{c.summary}</p>
            {c.expected_effect && (
              <p>
                Expected: {c.expected_effect}
                {/estimate/i.test(c.expected_effect) ? "" : " (model estimate)"}
              </p>
            )}
            <div className="flex flex-wrap items-center gap-1.5">
              <ConfidenceMeter confidence={c.confidence} />
              {c.evidence.map((e) => (
                <EvidenceChip key={e} source={e} />
              ))}
            </div>
          </div>
        )}
        <div className="flex items-center gap-3 pt-0.5 text-xs">
          {onSimulate && state === "alarm" && (
            <button onClick={onSimulate} className="font-semibold hover:underline" style={{ color: "var(--color-accent-500)" }}>
              Simulate the fix
            </button>
          )}
          <button onClick={() => setMore((m) => !m)} className="text-text-muted hover:text-text-primary" aria-expanded={more}>
            {more ? "Less" : "Why and evidence"}
          </button>
          <span className="ml-auto text-[11px] text-text-muted">{insight.source === "agent" ? "Copilot" : "Rules"}</span>
        </div>
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
          <span className="num text-3xl font-semibold">{remainingH > 0 ? fmtHours(remainingH) : "Passed"}</span>
          <span className="text-xs text-text-secondary">{remainingH > 0 ? "to point of no return" : "act now to limit the loss"}</span>
          <span className="text-[11px] text-text-muted">model estimate</span>
        </div>
      </div>
    </Tip>
  );
}
