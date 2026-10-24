import { useMemo, useRef, useState } from "react";

/*
 * Minimal SVG charts styled by tokens. One y-axis only, recessive grid, 2px lines,
 * legend + direct labels for <= 4 series, crosshair tooltip on hover.
 */

export interface Series {
  key: string;
  label: string;
  color: string; // a token var
  values: (number | null)[];
  dashed?: boolean;
}

const M = { top: 16, right: 92, bottom: 34, left: 56 };

function ticks(lo: number, hi: number, n = 4): number[] {
  const step = niceStep((hi - lo) / n);
  const start = Math.ceil(lo / step) * step;
  const out: number[] = [];
  for (let v = start; v <= hi + 1e-9; v += step) out.push(Number(v.toFixed(6)));
  return out;
}

function niceStep(raw: number): number {
  const p = 10 ** Math.floor(Math.log10(Math.max(raw, 1e-9)));
  const f = raw / p;
  return (f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10) * p;
}

export function LineChart({
  x,
  series,
  xLabel,
  yLabel,
  xFormat = (v) => String(v),
  yFormat = (v) => String(Math.round(v)),
  height = 300,
  yMin,
  yMax,
}: {
  x: number[];
  series: Series[];
  xLabel: string;
  yLabel: string;
  xFormat?: (v: number) => string;
  yFormat?: (v: number) => string;
  height?: number;
  yMin?: number;
  /** Cap the axis; values above it are clipped at the top edge (say so in the caption). */
  yMax?: number;
}) {
  const ref = useRef<SVGSVGElement>(null);
  const [hover, setHover] = useState<number | null>(null);
  const width = 1000;
  const iw = width - M.left - M.right;
  const ih = height - M.top - M.bottom;
  const all = series.flatMap((s) => s.values.filter((v): v is number => v !== null && Number.isFinite(v)));
  const lo = yMin ?? Math.min(0, ...all);
  const hi = yMax ?? Math.max(...all) * 1.08;
  const xs = (v: number) => M.left + ((v - x[0]!) / (x[x.length - 1]! - x[0]!)) * iw;
  const ys = (v: number) => M.top + ih - ((Math.min(v, hi) - lo) / (hi - lo)) * ih;
  const yt = useMemo(() => ticks(lo, hi), [lo, hi]);

  const onMove = (e: React.MouseEvent<SVGSVGElement>) => {
    const rect = ref.current?.getBoundingClientRect();
    if (!rect) return;
    const px = ((e.clientX - rect.left) / rect.width) * width;
    let best = 0;
    x.forEach((v, i) => {
      if (Math.abs(xs(v) - px) < Math.abs(xs(x[best]!) - px)) best = i;
    });
    setHover(best);
  };

  // Direct labels at the line ends, nudged apart to avoid collisions.
  const ends = series
    .map((s) => ({ s, y: ys(s.values[s.values.length - 1] ?? lo) }))
    .sort((a, b) => a.y - b.y);
  for (let i = 1; i < ends.length; i++) if (ends[i]!.y - ends[i - 1]!.y < 14) ends[i]!.y = ends[i - 1]!.y + 14;

  return (
    <figure className="m-0">
      <div className="mb-2 flex flex-wrap gap-4 text-xs text-text-secondary" aria-hidden>
        {series.map((s) => (
          <span key={s.key} className="flex items-center gap-1.5">
            <svg width="18" height="6">
              <line x1="0" y1="3" x2="18" y2="3" stroke={s.color} strokeWidth="2" strokeDasharray={s.dashed ? "4 3" : undefined} />
            </svg>
            {s.label}
          </span>
        ))}
      </div>
      <svg
        ref={ref}
        viewBox={`0 0 ${width} ${height}`}
        className="w-full"
        role="img"
        aria-label={`${yLabel} by ${xLabel}`}
        onMouseMove={onMove}
        onMouseLeave={() => setHover(null)}
      >
        {yt.map((t) => (
          <g key={t}>
            <line x1={M.left} x2={M.left + iw} y1={ys(t)} y2={ys(t)} stroke="var(--color-chart-grid)" />
            <text x={M.left - 8} y={ys(t) + 4} textAnchor="end" fontSize="11" fill="var(--color-text-muted)" className="num">
              {yFormat(t)}
            </text>
          </g>
        ))}
        {x.map((v, i) =>
          i % Math.ceil(x.length / 6) === 0 || i === x.length - 1 ? (
            <text key={v} x={xs(v)} y={M.top + ih + 18} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)" className="num">
              {xFormat(v)}
            </text>
          ) : null,
        )}
        <text x={M.left + iw / 2} y={height - 2} textAnchor="middle" fontSize="11" fill="var(--color-text-secondary)">
          {xLabel}
        </text>
        <text x={12} y={M.top + ih / 2} fontSize="11" fill="var(--color-text-secondary)" transform={`rotate(-90 12 ${M.top + ih / 2})`} textAnchor="middle">
          {yLabel}
        </text>
        {series.map((s) => (
          <polyline
            key={s.key}
            fill="none"
            stroke={s.color}
            strokeWidth={2}
            strokeDasharray={s.dashed ? "5 4" : undefined}
            strokeLinejoin="round"
            points={s.values
              .map((v, i) => (v === null ? null : `${xs(x[i]!)},${ys(v)}`))
              .filter(Boolean)
              .join(" ")}
          />
        ))}
        {ends.map(({ s, y }) => (
          <text key={s.key} x={M.left + iw + 6} y={y + 4} fontSize="11" fill="var(--color-text-secondary)">
            {s.label}
          </text>
        ))}
        {hover !== null && (
          <g>
            <line x1={xs(x[hover]!)} x2={xs(x[hover]!)} y1={M.top} y2={M.top + ih} stroke="var(--color-border-strong)" />
            {series.map((s) =>
              s.values[hover] !== null ? (
                <circle key={s.key} cx={xs(x[hover]!)} cy={ys(s.values[hover]!)} r={4} fill={s.color} stroke="var(--color-bg-surface)" strokeWidth={2} />
              ) : null,
            )}
          </g>
        )}
      </svg>
      {hover !== null && (
        <div className="num mt-1 flex flex-wrap gap-x-4 text-xs text-text-secondary" role="status">
          <span className="text-text-primary">{xFormat(x[hover]!)}</span>
          {series.map((s) => (
            <span key={s.key}>
              {s.label}: {s.values[hover] === null ? "—" : yFormat(s.values[hover]!)}
            </span>
          ))}
        </div>
      )}
    </figure>
  );
}

/** Horizontal bars for a single measure (one series: no legend, title names it). */
export function BarList({ items, format }: { items: { label: string; value: number }[]; format: (v: number) => string }) {
  const max = Math.max(...items.map((i) => i.value), 1e-9);
  return (
    <ul className="space-y-2">
      {items.map((i) => (
        <li key={i.label} className="grid grid-cols-[180px_1fr_56px] items-center gap-3 text-sm">
          <span className="truncate text-text-secondary">{i.label}</span>
          <span className="h-2.5 rounded-r" style={{ width: `${(i.value / max) * 100}%`, background: "var(--color-chart-series1)" }} />
          <span className="num text-right">{format(i.value)}</span>
        </li>
      ))}
    </ul>
  );
}
