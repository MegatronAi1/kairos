import { motion, useReducedMotion } from "framer-motion";
import { useMemo, useState, type ReactNode } from "react";

/*
 * Impact charts. Same conventions as components/charts.tsx: token colours, one
 * y-axis, recessive grid, legend + direct labels, hover tooltip on every mark.
 */

export interface StackKey {
  key: string;
  label: string;
  color: string;
}

const M = { top: 22, right: 16, bottom: 34, left: 64 };

function niceStep(raw: number): number {
  const p = 10 ** Math.floor(Math.log10(Math.max(raw, 1e-9)));
  const f = raw / p;
  return (f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10) * p;
}

function ticks(hi: number, n = 4): number[] {
  const step = niceStep(hi / n);
  const out: number[] = [];
  for (let v = 0; v <= hi + 1e-9; v += step) out.push(v);
  return out;
}

export function Legend({ items }: { items: { label: string; color: string; dashed?: boolean; swatch?: "bar" | "line" }[] }) {
  return (
    <div className="mb-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-text-secondary">
      {items.map((s) => (
        <span key={s.label} className="flex items-center gap-1.5">
          {s.swatch === "line" ? (
            <svg width="18" height="6" aria-hidden>
              <line x1="0" y1="3" x2="18" y2="3" stroke={s.color} strokeWidth="2" strokeDasharray={s.dashed ? "4 3" : undefined} />
            </svg>
          ) : (
            <span className="h-2.5 w-2.5 rounded-sm" style={{ background: s.color }} aria-hidden />
          )}
          {s.label}
        </span>
      ))}
    </div>
  );
}

function Tooltip({ leftPct, children }: { leftPct: number; children: ReactNode }) {
  const right = leftPct > 60;
  return (
    <div
      className="pointer-events-none absolute top-2 z-10 min-w-[180px] rounded-control border border-border-subtle bg-bg-elevated px-3 py-2 text-xs shadow-lg"
      style={right ? { right: `${100 - leftPct + 2}%` } : { left: `${leftPct + 2}%` }}
      role="status"
    >
      {children}
    </div>
  );
}

export function TipRow({ color, label, value, strong }: { color?: string; label: string; value: string; strong?: boolean }) {
  return (
    <div className={`flex items-center justify-between gap-4 ${strong ? "mt-1 border-t border-border-subtle pt-1 font-semibold text-text-primary" : "text-text-secondary"}`}>
      <span className="flex items-center gap-1.5">
        {color && <span className="h-2 w-2 rounded-sm" style={{ background: color }} aria-hidden />}
        {label}
      </span>
      <span className="num text-text-primary">{value}</span>
    </div>
  );
}

/** Stacked bars per period, with a marker at the go-live period. */
export function StackedBars({
  labels,
  keys,
  rows,
  format,
  liveIndex,
  height = 300,
  yLabel,
}: {
  labels: string[];
  keys: StackKey[];
  rows: Record<string, number>[];
  format: (v: number) => string;
  liveIndex: number;
  height?: number;
  yLabel: string;
}) {
  const reduce = useReducedMotion();
  const [hover, setHover] = useState<number | null>(null);
  const width = 1000;
  const iw = width - M.left - M.right;
  const ih = height - M.top - M.bottom;
  const totals = rows.map((r) => keys.reduce((s, k) => s + (r[k.key] ?? 0), 0));
  const hi = Math.max(...totals, 1) * 1.1;
  const yt = useMemo(() => ticks(hi), [hi]);
  const ys = (v: number) => M.top + ih - (v / hi) * ih;
  const slot = iw / Math.max(labels.length, 1);
  const bw = Math.min(56, slot * 0.68);
  const xc = (i: number) => M.left + slot * i + slot / 2;
  const every = Math.ceil(labels.length / 12);
  const peak = totals.indexOf(Math.max(...totals));

  return (
    <figure className="relative m-0">
      <Legend items={keys.map((k) => ({ label: k.label, color: k.color }))} />
      <svg viewBox={`0 0 ${width} ${height}`} className="w-full" role="img" aria-label={`${yLabel} per period, stacked by source`} onMouseLeave={() => setHover(null)}>
        {yt.map((t) => (
          <g key={t}>
            <line x1={M.left} x2={M.left + iw} y1={ys(t)} y2={ys(t)} stroke="var(--color-chart-grid)" />
            <text x={M.left - 8} y={ys(t) + 4} textAnchor="end" fontSize="11" fill="var(--color-text-muted)" className="num">
              {format(t)}
            </text>
          </g>
        ))}
        {liveIndex >= 0 && liveIndex < labels.length && (
          <g>
            <line
              x1={M.left + slot * liveIndex}
              x2={M.left + slot * liveIndex}
              y1={M.top - 8}
              y2={M.top + ih}
              stroke="var(--color-accent-500)"
              strokeDasharray="4 4"
              strokeWidth={1.5}
            />
            <text x={M.left + slot * liveIndex + 6} y={M.top - 8} fontSize="11" fontWeight={600} fill="var(--color-text-primary)">
              Kairos goes live
            </text>
            {liveIndex > 0 && (
              <text x={M.left + slot * liveIndex - 6} y={M.top - 8} fontSize="11" textAnchor="end" fill="var(--color-text-muted)">
                before Kairos: no savings
              </text>
            )}
          </g>
        )}
        {rows.map((r, i) => {
          let acc = 0;
          const segs = keys.map((k) => {
            const v = r[k.key] ?? 0;
            const y0 = ys(acc);
            acc += v;
            return { k, y: ys(acc), h: Math.max(0, y0 - ys(acc)) };
          });
          const last = [...segs].reverse().find((s) => s.h > 0);
          return (
            <g key={labels[i]} onMouseEnter={() => setHover(i)}>
              <rect x={xc(i) - slot / 2} y={M.top} width={slot} height={ih} fill="transparent" />
              {hover === i && <rect x={xc(i) - slot / 2} y={M.top} width={slot} height={ih} fill="var(--color-bg-elevated)" opacity={0.6} />}
              <motion.g
                initial={reduce ? false : { scaleY: 0 }}
                animate={{ scaleY: 1 }}
                transition={{ duration: 0.5, delay: reduce ? 0 : i * 0.02, ease: "easeOut" }}
                style={{ transformOrigin: `${xc(i)}px ${M.top + ih}px`, transformBox: "view-box" }}
              >
                {segs.map((s) =>
                  s.h > 0 ? (
                    <rect
                      key={s.k.key}
                      x={xc(i) - bw / 2}
                      y={s.y}
                      width={bw}
                      // 2px surface gap between stacked segments
                      height={Math.max(0, s.h - (s === last ? 0 : 2))}
                      rx={s === last ? 4 : 0}
                      fill={s.k.color}
                    />
                  ) : null,
                )}
              </motion.g>
              {(i === peak || (i === rows.length - 1 && rows.length - 1 - peak > 1)) && totals[i]! > 0 && (
                <text x={xc(i)} y={ys(totals[i]!) - 6} textAnchor="middle" fontSize="11" fill="var(--color-text-secondary)" className="num">
                  {format(totals[i]!)}
                </text>
              )}
              {(i % every === 0 || (i === labels.length - 1 && i % every >= 2)) && (
                <text x={xc(i)} y={M.top + ih + 18} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)" className="num">
                  {labels[i]}
                </text>
              )}
            </g>
          );
        })}
        <line x1={M.left} x2={M.left + iw} y1={M.top + ih} y2={M.top + ih} stroke="var(--color-border-strong)" />
      </svg>
      {hover !== null && (
        <Tooltip leftPct={(xc(hover) / width) * 100}>
          <div className="mb-1 font-semibold text-text-primary">{labels[hover]}</div>
          {[...keys].reverse().map((k) => (
            <TipRow key={k.key} color={k.color} label={k.label} value={format(rows[hover]![k.key] ?? 0)} />
          ))}
          <TipRow label="Total" value={format(totals[hover]!)} strong />
        </Tooltip>
      )}
    </figure>
  );
}

export interface LineSeries {
  key: string;
  label: string;
  color: string;
  values: number[];
  dashed?: boolean;
  area?: boolean;
}

/** Lines over categorical periods with a crosshair tooltip and end labels. */
export function PeriodLines({
  labels,
  series,
  format,
  height = 260,
  yLabel,
  extraTip,
  legend = true,
}: {
  labels: string[];
  series: LineSeries[];
  format: (v: number) => string;
  height?: number;
  yLabel: string;
  extraTip?: (i: number) => ReactNode;
  legend?: boolean;
}) {
  const reduce = useReducedMotion();
  const [hover, setHover] = useState<number | null>(null);
  const width = 1000;
  const right = 110;
  const iw = width - M.left - right;
  const ih = height - M.top - M.bottom;
  const hi = Math.max(...series.flatMap((s) => s.values), 1) * 1.1;
  const yt = useMemo(() => ticks(hi), [hi]);
  const ys = (v: number) => M.top + ih - (v / hi) * ih;
  const n = labels.length;
  const xs = (i: number) => M.left + (n <= 1 ? iw / 2 : (i / (n - 1)) * iw);
  const every = Math.ceil(n / 12);

  const ends = series.map((s) => ({ s, y: ys(s.values[n - 1] ?? 0) })).sort((a, b) => a.y - b.y);
  for (let i = 1; i < ends.length; i++) if (ends[i]!.y - ends[i - 1]!.y < 14) ends[i]!.y = ends[i - 1]!.y + 14;

  const onMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const px = ((e.clientX - rect.left) / rect.width) * width;
    const i = n <= 1 ? 0 : Math.round(((px - M.left) / iw) * (n - 1));
    setHover(Math.max(0, Math.min(n - 1, i)));
  };

  return (
    <figure className="relative m-0">
      {legend && <Legend items={series.map((s) => ({ label: s.label, color: s.color, dashed: s.dashed, swatch: "line" as const }))} />}
      <svg viewBox={`0 0 ${width} ${height}`} className="w-full" role="img" aria-label={yLabel} onMouseMove={onMove} onMouseLeave={() => setHover(null)}>
        {yt.map((t) => (
          <g key={t}>
            <line x1={M.left} x2={M.left + iw} y1={ys(t)} y2={ys(t)} stroke="var(--color-chart-grid)" />
            <text x={M.left - 8} y={ys(t) + 4} textAnchor="end" fontSize="11" fill="var(--color-text-muted)" className="num">
              {format(t)}
            </text>
          </g>
        ))}
        {labels.map((l, i) =>
          i % every === 0 || (i === n - 1 && i % every >= 2) ? (
            <text key={l} x={xs(i)} y={M.top + ih + 18} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)" className="num">
              {l}
            </text>
          ) : null,
        )}
        {series.map((s) => {
          const pts = s.values.map((v, i) => `${xs(i)},${ys(v)}`).join(" ");
          return (
            <g key={s.key}>
              {s.area && (
                <polygon points={`${xs(0)},${ys(0)} ${pts} ${xs(n - 1)},${ys(0)}`} fill={s.color} opacity={0.12} />
              )}
              <motion.polyline
                fill="none"
                stroke={s.color}
                strokeWidth={2}
                strokeDasharray={s.dashed ? "5 4" : undefined}
                strokeLinejoin="round"
                points={pts}
                initial={reduce || s.dashed ? false : { pathLength: 0 }}
                animate={{ pathLength: 1 }}
                transition={{ duration: 0.8, ease: "easeOut" }}
              />
            </g>
          );
        })}
        {ends.map(({ s, y }) => (
          <text key={s.key} x={M.left + iw + 8} y={y + 4} fontSize="11" fill="var(--color-text-secondary)">
            {s.label.length > 16 ? `${s.label.slice(0, 15)}…` : s.label}
          </text>
        ))}
        {hover !== null && (
          <g>
            <line x1={xs(hover)} x2={xs(hover)} y1={M.top} y2={M.top + ih} stroke="var(--color-border-strong)" />
            {series.map((s) => (
              <circle key={s.key} cx={xs(hover)} cy={ys(s.values[hover] ?? 0)} r={5} fill={s.color} stroke="var(--color-bg-surface)" strokeWidth={2} />
            ))}
          </g>
        )}
      </svg>
      {hover !== null && (
        <Tooltip leftPct={(xs(hover) / width) * 100}>
          <div className="mb-1 font-semibold text-text-primary">{labels[hover]}</div>
          {series.map((s) => (
            <TipRow key={s.key} color={s.color} label={s.label} value={format(s.values[hover] ?? 0)} />
          ))}
          {extraTip?.(hover)}
        </Tooltip>
      )}
    </figure>
  );
}

/** Horizontal bars for one measure across plants; hover shows every measure. */
export function PlantBars({
  items,
  format,
  detail,
  selected,
  onSelect,
}: {
  items: { id: string; label: string; sub: string; value: number }[];
  format: (v: number) => string;
  detail: (id: string) => ReactNode;
  selected?: string;
  onSelect?: (id: string) => void;
}) {
  const reduce = useReducedMotion();
  const [hover, setHover] = useState<string | null>(null);
  const max = Math.max(...items.map((i) => i.value), 1e-9);
  return (
    <ul className="space-y-1">
      {items.map((it, idx) => {
        const active = selected === it.id;
        return (
          <li key={it.id} className="relative" onMouseEnter={() => setHover(it.id)} onMouseLeave={() => setHover(null)}>
            <button
              type="button"
              onClick={() => onSelect?.(it.id)}
              className={`grid w-full grid-cols-[minmax(0,150px)_1fr_auto] items-center gap-3 rounded-control px-2 py-1.5 text-left text-sm transition-colors hover:bg-bg-elevated sm:grid-cols-[minmax(0,220px)_1fr_auto] ${active ? "bg-bg-elevated" : ""}`}
              aria-pressed={active}
            >
              <span className="min-w-0">
                <span className="block truncate font-medium">{it.label}</span>
                <span className="block truncate text-xs text-text-muted">{it.sub}</span>
              </span>
              <span className="h-3 overflow-hidden rounded-r bg-bg-inset">
                <motion.span
                  className="block h-full rounded-r"
                  style={{ background: active || !selected ? "var(--color-chart-series1)" : "var(--color-chart-reference)" }}
                  initial={reduce ? false : { width: 0 }}
                  animate={{ width: `${(it.value / max) * 100}%` }}
                  transition={{ duration: 0.6, delay: reduce ? 0 : idx * 0.04, ease: "easeOut" }}
                />
              </span>
              <span className="num w-24 text-right">{format(it.value)}</span>
            </button>
            {hover === it.id && (
              <div className="pointer-events-none absolute right-28 top-full z-10 -mt-1 min-w-[220px] rounded-control border border-border-subtle bg-bg-elevated px-3 py-2 text-xs shadow-lg" role="status">
                <div className="mb-1 font-semibold text-text-primary">{it.label}</div>
                {detail(it.id)}
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}
