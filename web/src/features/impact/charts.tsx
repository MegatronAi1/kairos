import { motion, useReducedMotion } from "framer-motion";
import { useEffect, useMemo, useRef, useState, type ReactNode, type RefObject } from "react";

/*
 * Impact charts. Same conventions as components/charts.tsx: token colours, one
 * y-axis, recessive grid, legend + direct labels, hover tooltip on every mark.
 * Every chart measures its container and draws at real pixel size, so text stays
 * 11-12px at any width (no viewBox scaling).
 */

export interface StackKey {
  key: string;
  label: string;
  color: string;
}

const FONT = 11;
const M = { top: 26, right: 12, bottom: 30, left: 60 };

/** Container width in px, kept current with a ResizeObserver. */
export function useWidth<T extends HTMLElement>(): [RefObject<T>, number] {
  const ref = useRef<T>(null);
  const [w, setW] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    setW(el.clientWidth);
    const ro = new ResizeObserver((entries) => setW(Math.round(entries[0]!.contentRect.width)));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, w];
}

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

/** Period label shortened for narrow axes: "2025-11" -> "Nov 25", "2026-Q1" -> "Q1 26". */
export function shortPeriod(p: string): string {
  const [y, rest] = p.split("-");
  if (!rest) return p;
  if (rest.startsWith("Q")) return `${rest} ${y!.slice(2)}`;
  const m = new Date(Number(y), Number(rest) - 1, 1).toLocaleString("en-US", { month: "short" });
  return `${m} ${y!.slice(2)}`;
}

export function Legend({ items }: { items: { label: string; color: string; dashed?: boolean; swatch?: "bar" | "line" }[] }) {
  return (
    <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-text-secondary">
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

function Tooltip({ x, width, children }: { x: number; width: number; children: ReactNode }) {
  const flip = x > width / 2;
  return (
    <div
      className="pointer-events-none absolute top-8 z-10 min-w-[190px] rounded-control border border-border-subtle bg-bg-elevated px-3 py-2 text-xs shadow-lg"
      style={flip ? { right: width - x + 12 } : { left: x + 12 }}
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

function YGrid({ yt, ys, x0, x1, format }: { yt: number[]; ys: (v: number) => number; x0: number; x1: number; format: (v: number) => string }) {
  return (
    <>
      {yt.map((t) => (
        <g key={t}>
          <line x1={x0} x2={x1} y1={ys(t)} y2={ys(t)} stroke="var(--color-chart-grid)" />
          <text x={x0 - 8} y={ys(t) + 4} textAnchor="end" fontSize={FONT} fill="var(--color-text-muted)" className="num">
            {format(t)}
          </text>
        </g>
      ))}
    </>
  );
}

/** Show at most one axis label per `minPx` pixels. */
function labelEvery(slotPx: number, minPx = 64): number {
  return Math.max(1, Math.ceil(minPx / Math.max(slotPx, 1)));
}

function LiveMarker({ x, top, bottom, showBefore }: { x: number; top: number; bottom: number; showBefore: boolean }) {
  return (
    <g>
      <line x1={x} x2={x} y1={top - 12} y2={bottom} stroke="var(--color-accent-500)" strokeDasharray="4 4" strokeWidth={1.5} />
      <text x={x + 6} y={top - 12} fontSize={FONT} fontWeight={600} fill="var(--color-text-primary)">
        Kairos live
      </text>
      {showBefore && (
        <text x={x - 6} y={top - 12} fontSize={FONT} textAnchor="end" fill="var(--color-text-muted)">
          before
        </text>
      )}
    </g>
  );
}

/** Bars per period (stacked when there is more than one key), with a go-live marker. */
export function StackedBars({
  labels,
  keys,
  rows,
  format,
  liveIndex,
  height = 320,
  yLabel,
  legend = true,
  extraTip,
}: {
  labels: string[];
  keys: StackKey[];
  rows: Record<string, number>[];
  format: (v: number) => string;
  liveIndex: number;
  height?: number;
  yLabel: string;
  legend?: boolean;
  extraTip?: (i: number) => ReactNode;
}) {
  const reduce = useReducedMotion();
  const [ref, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  const iw = Math.max(0, width - M.left - M.right);
  const ih = height - M.top - M.bottom;
  const totals = rows.map((r) => keys.reduce((s, k) => s + (r[k.key] ?? 0), 0));
  const hi = Math.max(...totals, 1e-9) * 1.12;
  const yt = useMemo(() => ticks(hi), [hi]);
  const ys = (v: number) => M.top + ih - (v / hi) * ih;
  const slot = iw / Math.max(labels.length, 1);
  const bw = Math.max(4, Math.min(44, slot - 6));
  const xc = (i: number) => M.left + slot * i + slot / 2;
  const every = labelEvery(slot);
  const peak = totals.indexOf(Math.max(...totals));

  return (
    <figure className="relative m-0 space-y-2">
      {legend && keys.length > 1 && <Legend items={keys.map((k) => ({ label: k.label, color: k.color }))} />}
      <div ref={ref} className="w-full" style={{ height }}>
        {width > 0 && (
          <svg width={width} height={height} role="img" aria-label={`${yLabel} per period`} onMouseLeave={() => setHover(null)}>
            <YGrid yt={yt} ys={ys} x0={M.left} x1={M.left + iw} format={format} />
            {liveIndex >= 0 && liveIndex < labels.length && (
              <LiveMarker x={M.left + slot * liveIndex} top={M.top} bottom={M.top + ih} showBefore={liveIndex > 1 && slot * liveIndex > 70} />
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
                  <rect x={xc(i) - slot / 2} y={M.top} width={slot} height={ih} fill={hover === i ? "var(--color-bg-elevated)" : "transparent"} opacity={0.7} />
                  <motion.g
                    initial={reduce ? false : { scaleY: 0 }}
                    animate={{ scaleY: 1 }}
                    transition={{ duration: 0.5, delay: reduce ? 0 : i * 0.015, ease: "easeOut" }}
                    style={{ transformOrigin: `${xc(i)}px ${M.top + ih}px` }}
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
                          rx={s === last ? Math.min(4, bw / 3) : 0}
                          fill={s.k.color}
                        />
                      ) : null,
                    )}
                  </motion.g>
                  {i === peak && totals[i]! > 0 && (
                    <text x={xc(i)} y={ys(totals[i]!) - 6} textAnchor="middle" fontSize={FONT} fontWeight={600} fill="var(--color-text-secondary)" className="num">
                      {format(totals[i]!)}
                    </text>
                  )}
                  {(i % every === 0) && (
                    <text x={xc(i)} y={M.top + ih + 18} textAnchor="middle" fontSize={FONT} fill="var(--color-text-muted)" className="num">
                      {shortPeriod(labels[i]!)}
                    </text>
                  )}
                </g>
              );
            })}
            <line x1={M.left} x2={M.left + iw} y1={M.top + ih} y2={M.top + ih} stroke="var(--color-border-strong)" />
          </svg>
        )}
      </div>
      {hover !== null && width > 0 && (
        <Tooltip x={xc(hover)} width={width}>
          <div className="mb-1 font-semibold text-text-primary">{labels[hover]}</div>
          {keys.length > 1 &&
            [...keys].reverse().map((k) => <TipRow key={k.key} color={k.color} label={k.label} value={format(rows[hover]![k.key] ?? 0)} />)}
          <TipRow label={keys.length > 1 ? "Total" : keys[0]!.label} value={format(totals[hover]!)} strong={keys.length > 1} />
          {extraTip?.(hover)}
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
  liveIndex = -1,
}: {
  labels: string[];
  series: LineSeries[];
  format: (v: number) => string;
  height?: number;
  yLabel: string;
  extraTip?: (i: number) => ReactNode;
  legend?: boolean;
  liveIndex?: number;
}) {
  const reduce = useReducedMotion();
  const [ref, width] = useWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);
  // End labels need room when there are several series; a single series is named by the title.
  const right = width < 480 || series.length < 2 ? 16 : 100;
  const iw = Math.max(0, width - M.left - right);
  const ih = height - M.top - M.bottom;
  const all = series.flatMap((s) => s.values);
  const lo = Math.min(...all);
  const hiRaw = Math.max(...all, 1e-9);
  // Zero baseline unless every value sits far above it (then a tight range reads better).
  const base = lo > hiRaw * 0.6 ? niceStep((lo * 0.9) / 2) * Math.floor((lo * 0.9) / niceStep((lo * 0.9) / 2)) : 0;
  const hi = hiRaw * 1.06;
  const yt = useMemo(() => {
    const step = niceStep((hi - base) / 4);
    const out: number[] = [];
    for (let v = base; v <= hi + 1e-9; v += step) out.push(v);
    return out;
  }, [hi, base]);
  const ys = (v: number) => M.top + ih - ((v - base) / (hi - base)) * ih;
  const n = labels.length;
  const xs = (i: number) => M.left + (n <= 1 ? iw / 2 : (i / (n - 1)) * iw);
  const every = labelEvery(n > 1 ? iw / (n - 1) : iw);

  const ends = series.map((s) => ({ s, y: ys(s.values[n - 1] ?? 0) })).sort((a, b) => a.y - b.y);
  for (let i = 1; i < ends.length; i++) if (ends[i]!.y - ends[i - 1]!.y < 14) ends[i]!.y = ends[i - 1]!.y + 14;

  const onMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const px = e.clientX - e.currentTarget.getBoundingClientRect().left;
    const i = n <= 1 ? 0 : Math.round(((px - M.left) / iw) * (n - 1));
    setHover(Math.max(0, Math.min(n - 1, i)));
  };

  return (
    <figure className="relative m-0 space-y-2">
      {legend && <Legend items={series.map((s) => ({ label: s.label, color: s.color, dashed: s.dashed, swatch: "line" as const }))} />}
      <div ref={ref} className="w-full" style={{ height }}>
        {width > 0 && (
          <svg width={width} height={height} role="img" aria-label={yLabel} onMouseMove={onMove} onMouseLeave={() => setHover(null)}>
            <YGrid yt={yt} ys={ys} x0={M.left} x1={M.left + iw} format={format} />
            {liveIndex > 0 && liveIndex < n && (
              <LiveMarker x={xs(liveIndex)} top={M.top} bottom={M.top + ih} showBefore={false} />
            )}
            {labels.map((l, i) =>
              i % every === 0 ? (
                <text key={l} x={xs(i)} y={M.top + ih + 18} textAnchor="middle" fontSize={FONT} fill="var(--color-text-muted)" className="num">
                  {shortPeriod(l)}
                </text>
              ) : null,
            )}
            {series.map((s) => {
              const pts = s.values.map((v, i) => `${xs(i)},${ys(v)}`).join(" ");
              return (
                <g key={s.key}>
                  {s.area && <polygon points={`${xs(0)},${ys(base)} ${pts} ${xs(n - 1)},${ys(base)}`} fill={s.color} opacity={0.12} />}
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
            {right > 40 &&
              ends.map(({ s, y }) => (
                <text key={s.key} x={M.left + iw + 8} y={y + 4} fontSize={FONT} fill="var(--color-text-secondary)">
                  {s.label.length > 14 ? `${s.label.slice(0, 13)}…` : s.label}
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
        )}
      </div>
      {hover !== null && width > 0 && (
        <Tooltip x={xs(hover)} width={width}>
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

/** Tiny trend line for KPI tiles and the hero (no axes, no text). */
export function Sparkline({ values, color, height = 36, area = true }: { values: number[]; color: string; height?: number; area?: boolean }) {
  const [ref, width] = useWidth<HTMLDivElement>();
  const n = values.length;
  const hi = Math.max(...values, 1e-9);
  const lo = Math.min(...values, 0);
  const x = (i: number) => (n <= 1 ? width / 2 : (i / (n - 1)) * (width - 4) + 2);
  const y = (v: number) => height - 3 - ((v - lo) / (hi - lo || 1)) * (height - 8);
  const pts = values.map((v, i) => `${x(i)},${y(v)}`).join(" ");
  return (
    <div ref={ref} className="w-full" style={{ height }} aria-hidden>
      {width > 0 && n > 0 && (
        <svg width={width} height={height}>
          {area && <polygon points={`${x(0)},${height} ${pts} ${x(n - 1)},${height}`} fill={color} opacity={0.14} />}
          <polyline points={pts} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
          <circle cx={x(n - 1)} cy={y(values[n - 1]!)} r={3} fill={color} />
        </svg>
      )}
    </div>
  );
}

/** One proportional bar split into parts, with labels and shares underneath. */
export function ShareBar({ parts, format }: { parts: { label: string; value: number; color: string }[]; format: (v: number) => string }) {
  const total = parts.reduce((s, p) => s + p.value, 0) || 1;
  return (
    <div>
      <div className="flex h-3 w-full gap-[2px] overflow-hidden rounded-full" role="img" aria-label="Share of savings by source">
        {parts.map((p) => (
          <span key={p.label} className="h-full first:rounded-l-full last:rounded-r-full" style={{ width: `${(p.value / total) * 100}%`, background: p.color }} />
        ))}
      </div>
      <div className="mt-3 grid grid-cols-3 gap-3">
        {parts.map((p) => (
          <div key={p.label} className="min-w-0">
            <div className="flex items-center gap-1.5 text-xs text-text-secondary">
              <span className="h-2 w-2 shrink-0 rounded-sm" style={{ background: p.color }} aria-hidden />
              <span className="truncate">{p.label}</span>
            </div>
            <div className="num mt-0.5 text-sm font-semibold text-text-primary">{Math.round((p.value / total) * 100)}%</div>
            <div className="num truncate text-xs text-text-muted">{format(p.value)}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

/** Ranked horizontal bars for one measure across plants; click filters, hover shows every measure. */
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
  const total = items.reduce((s, i) => s + i.value, 0) || 1;
  return (
    <ul className="space-y-1">
      {items.map((it, idx) => {
        const active = selected === it.id;
        const lit = active || hover === it.id;
        const dim = (!!selected || !!hover) && !lit;
        return (
          <li key={it.id} className="relative" onMouseEnter={() => setHover(it.id)} onMouseLeave={() => setHover(null)}>
            <button
              type="button"
              onClick={() => onSelect?.(it.id)}
              className={`w-full rounded-control px-2.5 py-2 text-left transition-colors hover:bg-bg-elevated ${active ? "bg-bg-elevated ring-1 ring-accent-500" : ""}`}
              aria-pressed={active}
            >
              <div className="flex items-baseline justify-between gap-3 text-sm">
                <span className="min-w-0 truncate">
                  <span className="num mr-2 text-xs text-text-muted">{idx + 1}</span>
                  <span className="font-medium">{it.label}</span>
                  <span className="ml-2 text-xs text-text-muted">{it.sub}</span>
                </span>
                <span className="shrink-0">
                  <span className="num font-semibold">{format(it.value)}</span>
                  <span className="num ml-2 inline-block w-9 text-right text-xs text-text-muted">{Math.round((it.value / total) * 100)}%</span>
                </span>
              </div>
              <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-bg-inset">
                <motion.div
                  className="h-full rounded-full"
                  style={{ background: "var(--color-chart-series1)", opacity: lit ? 1 : dim ? 0.35 : 0.72 }}
                  initial={reduce ? false : { width: 0 }}
                  animate={{ width: `${(it.value / max) * 100}%` }}
                  transition={{ duration: 0.6, delay: reduce ? 0 : idx * 0.04, ease: "easeOut" }}
                />
              </div>
            </button>
            {hover === it.id && (
              <div className="pointer-events-none absolute right-2 top-full z-10 -mt-1 min-w-[220px] rounded-control border border-border-subtle bg-bg-elevated px-3 py-2 text-xs shadow-lg" role="status">
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
