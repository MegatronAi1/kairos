import { useQuery } from "@tanstack/react-query";
import type { ReactNode } from "react";

import { BarList, LineChart } from "@/components/charts";
import { EmptyState, ErrorState, Panel, ProvenanceChip, Skeleton, Tip } from "@/components/primitives";
import { api, type Metrics } from "@/lib/api/client";
import { fmt, fmtInt } from "@/lib/format";

const S1 = "var(--color-chart-series1)";
const S2 = "var(--color-chart-series2)";
const S3 = "var(--color-chart-series3)";
const REF = "var(--color-chart-reference)";

function Stat({ label, value, sub, tip }: { label: string; value: ReactNode; sub: ReactNode; tip: string }) {
  return (
    <Panel className="p-4">
      <Tip content={tip}>
        <div tabIndex={0} className="eyebrow cursor-help">
          {label}
        </div>
      </Tip>
      <div className="display-num mt-1 text-4xl font-semibold">{value}</div>
      <div className="mt-1 text-sm text-text-secondary">{sub}</div>
    </Panel>
  );
}

function Section({ title, sub, children }: { title: string; sub?: string; children: ReactNode }) {
  return (
    <Panel className="p-5">
      <h2 className="text-lg font-medium">{title}</h2>
      {sub && <p className="mb-4 mt-0.5 text-sm text-text-secondary">{sub}</p>}
      {children}
    </Panel>
  );
}

export default function EvidencePage() {
  const metrics = useQuery({ queryKey: ["metrics"], queryFn: api.metrics });
  const prov = useQuery({ queryKey: ["provenance"], queryFn: api.provenance });

  if (metrics.isLoading)
    return (
      <div className="grid grid-cols-4 gap-4 p-8">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-28" />
        ))}
        <Skeleton className="col-span-4 h-72" />
      </div>
    );
  if (metrics.isError) return <ErrorState title="Could not load evidence" onRetry={() => void metrics.refetch()} />;
  const m = metrics.data as Metrics;
  if (!m.yield || !m.faults) return <EmptyState title="No evaluation results yet" message="Run `make train eval` to produce them." />;

  const y = m.yield;
  const f = m.faults;
  const at = (p: number) => y.checkpoints.find((c) => c.progress === p)!;
  const c30 = at(0.3);
  const better30 = 100 * (1 - c30.models.kairos!.mae / c30.models.naive_mean!.mae);
  const k = f.summary.kairos;
  const b = f.summary.mspc_baseline;
  const curve = y.convergence_curve_mae_kg;

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-6xl space-y-5 p-8">
        <header className="flex items-end justify-between">
          <div>
            <h1 className="text-3xl font-semibold">Evidence</h1>
            <p className="mt-1 text-text-secondary">
              Every number below is produced by <code className="num">make eval</code> on batches the models never saw.
            </p>
          </div>
          <span className="flex items-center gap-2 text-sm text-text-secondary">
            <ProvenanceChip provenance="synthetic" source={y.provenance} /> IndPenSim simulated batches
          </span>
        </header>

        <div className="grid grid-cols-4 gap-4">
          <Stat
            label="KPI 1 · Yield prediction accuracy"
            value={`${fmtInt(c30.models.kairos!.mae)} kg`}
            sub={`error at 30% of the batch, ${Math.round(better30)}% lower than the naive baseline`}
            tip={`Mean absolute error of the final-yield forecast on ${y.n_test_batches} held-out normal batches at 30% progress. Typical batch: ${fmtInt(y.typical_yield_kg)} kg. 90% intervals cover ${Math.round(100 * y.overall_hourly_coverage.coverage_90)}% of outcomes.`}
          />
          <Stat
            label="KPI 2 · Fault detection"
            value={`${k.detected} / ${k.n_fault_batches}`}
            sub={`fault batches caught, median ${fmt(k.median_delay_h)} h after the fault began`}
            tip="Fault batches 91-100. Onsets are exact for input faults and estimated for the others (see the table)."
          />
          <Stat
            label="KPI 3 · False alarms"
            value={fmt(k.false_alarms_per_batch, 1)}
            sub={`per normal batch, versus ${fmt(b.false_alarms_per_batch, 1)} for classic MSPC`}
            tip={`Alarm entries on ${f.per_normal_batch.length} held-out normal batches. Kairos adds golden-trajectory normalisation, EWMA, ${fmt(f.detector.persistence_h)} h persistence and hysteresis.`}
          />
          <Stat
            label="KPI 4 · Oxygen transfer vs energy"
            value={m.energy ? `${fmt(m.energy.mean_saving_pct, 0)}%` : "—"}
            sub={
              m.energy
                ? `less agitation + aeration energy, dissolved oxygen kept above ${fmt(m.energy.target_do_pct, 0)}%`
                : "run make eval"
            }
            tip="Held-out normal batches, hourly step-limited recommendations. Physics model with assumed geometry and compressor efficiency."
          />
        </div>

        <Section
          title="Yield forecast error as the batch progresses"
          sub="Mean absolute error of the final-yield forecast (kg) on held-out normal batches. Lower is better. The mechanistic projection runs off the top of the axis before 20% progress."
        >
          <LineChart
            x={curve.map((c) => c.progress)}
            xLabel="Batch progress"
            yLabel="MAE (kg)"
            xFormat={(v) => `${Math.round(v * 100)}%`}
            yMax={1.6 * (curve[0]?.naive_mean ?? 1000)}
            series={[
              { key: "kairos", label: "Kairos", color: S1, values: curve.map((c) => c.kairos ?? null) },
              { key: "linear", label: "Linear", color: S2, values: curve.map((c) => c.linear ?? null) },
              { key: "prior", label: "Mechanistic", color: S3, values: curve.map((c) => c.mechanistic_prior ?? null) },
              { key: "naive", label: "Naive mean", color: REF, dashed: true, values: curve.map((c) => c.naive_mean ?? null) },
            ]}
          />
          <table className="num mt-4 w-full text-sm">
            <caption className="sr-only">Yield error by checkpoint</caption>
            <thead className="text-left text-text-muted">
              <tr>
                <th className="py-1 font-normal">Progress</th>
                <th className="font-normal">Kairos MAE</th>
                <th className="font-normal">Linear</th>
                <th className="font-normal">Mechanistic</th>
                <th className="font-normal">Naive</th>
                <th className="font-normal">R²</th>
                <th className="font-normal">80% / 90% coverage</th>
              </tr>
            </thead>
            <tbody>
              {y.checkpoints.map((c) => (
                <tr key={c.progress} className="border-t border-border-subtle">
                  <td className="py-1.5">{Math.round(c.progress * 100)}%</td>
                  <td>{fmtInt(c.models.kairos!.mae)} kg</td>
                  <td>{fmtInt(c.models.linear!.mae)}</td>
                  <td>{fmtInt(c.models.mechanistic_prior!.mae)}</td>
                  <td>{fmtInt(c.models.naive_mean!.mae)}</td>
                  <td>{fmt(c.models.kairos!.r2, 2)}</td>
                  <td>
                    {Math.round(c.coverage_80 * 100)}% / {Math.round(c.coverage_90 * 100)}%
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {y.fault_batches && (
            <p className="mt-3 text-sm text-text-secondary">
              Fault batches (leave-one-fault-out): MAE{" "}
              {y.fault_batches.checkpoints.map((c) => `${fmtInt(c.kairos.mae)} kg at ${Math.round(c.progress * 100)}%`).join(", ")}{" "}
              versus naive {fmtInt(y.fault_batches.checkpoints[0]!.naive_mean.mae)} kg. Early fault forecasts are the weakest
              point; intervals widen once an alarm fires.
            </p>
          )}
        </Section>

        <div className="grid grid-cols-2 gap-5">
          <Section title="Fault detection by batch" sub="Delay from fault onset to the first alarm (hours).">
            <table className="num w-full text-sm">
              <caption className="sr-only">Detection delay per fault batch</caption>
              <thead className="text-left text-text-muted">
                <tr>
                  <th className="py-1 font-normal">Batch</th>
                  <th className="font-normal">Fault</th>
                  <th className="font-normal">Onset</th>
                  <th className="font-normal">Kairos</th>
                  <th className="font-normal">MSPC</th>
                </tr>
              </thead>
              <tbody>
                {f.per_fault_batch.map((r) => (
                  <tr key={r.batch} className="border-t border-border-subtle">
                    <td className="py-1.5">{r.batch}</td>
                    <td className="font-[inherit] text-text-secondary">{r.fault_variable.replace(/_lph|_k$/, "")}</td>
                    <td>
                      <Tip content={r.onset_method}>
                        <span tabIndex={0}>
                          {fmt(r.onset_h)} h{r.onset_method.startsWith("estimated") ? "*" : ""}
                        </span>
                      </Tip>
                    </td>
                    <td style={{ color: r.detected ? undefined : "var(--color-state-alarm)" }}>
                      {r.delay_h === null ? "missed" : `+${fmt(r.delay_h)} h`}
                    </td>
                    <td className="text-text-secondary">{r.baseline_delay_h === null ? "missed" : `+${fmt(r.baseline_delay_h)} h`}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="mt-2 text-xs text-text-muted">
              * onset estimated from the data (no input change to anchor it). Classic MSPC often shows +0.0 h because it is
              already alarming on noise: {fmt(f.summary.mspc_baseline.false_alarms_per_batch, 1)} false alarms per normal batch.
            </p>
          </Section>

          <Section
            title="Detection delay versus false alarms"
            sub="Each dot is one threshold / persistence setting on held-out batches. Down and left is better."
          >
            <TradeoffChart m={m} />
          </Section>
        </div>

        {m.energy && <EnergySection e={m.energy} />}

        {m.drivers && (
          <div className="grid grid-cols-2 gap-5">
            <Section title="What drives the final yield" sub="Share of the forecast explained by each input (mean |attribution|).">
              <BarList
                items={m.drivers.drivers.map((d) => ({ label: d.label, value: d.share * 100 }))}
                format={(v) => `${v.toFixed(0)}%`}
              />
            </Section>
            <Section title="How inputs interact" sub="Strongest SHAP interaction pairs in the tree model.">
              <ul className="space-y-3 text-sm">
                {m.drivers.interactions.map((i) => (
                  <li key={`${i.a_label}-${i.b_label}`}>
                    <span className="font-medium">
                      {i.a_label} × {i.b_label}
                    </span>
                    <p className="text-text-secondary">{i.sentence}</p>
                  </li>
                ))}
              </ul>
            </Section>
          </div>
        )}

        <Section title="Data provenance" sub="Every input with its label. Assumed values are never shown as published.">
          {prov.isLoading ? (
            <Skeleton className="h-40" />
          ) : prov.isError ? (
            <ErrorState title="Could not load provenance" onRetry={() => void prov.refetch()} />
          ) : (
            <table className="w-full text-sm">
              <caption className="sr-only">Provenance of every constant</caption>
              <thead className="text-left text-text-muted">
                <tr>
                  <th className="py-1 font-normal">Input</th>
                  <th className="font-normal">Value</th>
                  <th className="font-normal">Label</th>
                  <th className="font-normal">Source</th>
                </tr>
              </thead>
              <tbody>
                {prov.data!.data_sources.map((d) => (
                  <tr key={d.name} className="border-t border-border-subtle">
                    <td className="py-1.5">{d.name}</td>
                    <td className="text-text-secondary">time series</td>
                    <td>
                      <ProvenanceChip provenance={d.provenance} />
                    </td>
                    <td>
                      <a href={d.url} target="_blank" rel="noreferrer" className="text-accent-500 hover:underline">
                        {d.note}
                      </a>
                    </td>
                  </tr>
                ))}
                {prov.data!.constants.map((c) => (
                  <tr key={c.key} className="border-t border-border-subtle">
                    <td className="py-1.5">{c.key.replaceAll("_", " ")}</td>
                    <td className="num">
                      {c.value} {c.unit !== "-" ? c.unit : ""}
                    </td>
                    <td>
                      <ProvenanceChip provenance={c.provenance} source={c.source} />
                    </td>
                    <td className="text-text-secondary">{c.source}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Section>

        <Section title="Caveats">
          <ul className="list-disc space-y-1 pl-5 text-sm text-text-secondary">
            {[...y.notes, ...f.notes].map((n) => (
              <li key={n}>{n}</li>
            ))}
          </ul>
        </Section>
      </div>
    </div>
  );
}

function TradeoffChart({ m }: { m: Metrics }) {
  const f = m.faults!;
  const pts = f.tradeoff.filter((t) => t.median_delay_h !== null);
  const base = f.summary.mspc_baseline;
  const chosen = f.detector;
  const W = 520;
  const H = 240;
  const P = { l: 48, r: 16, t: 12, b: 36 };
  const maxX = Math.max(base.false_alarms_per_batch, ...pts.map((p) => p.false_alarms_per_batch)) * 1.1;
  const maxY = Math.max(base.median_delay_h ?? 0, ...pts.map((p) => p.median_delay_h!)) * 1.15 || 1;
  const xs = (v: number) => P.l + (v / maxX) * (W - P.l - P.r);
  const ys = (v: number) => H - P.b - (v / maxY) * (H - P.t - P.b);
  return (
    <figure className="m-0">
      <div className="mb-2 flex gap-4 text-xs text-text-secondary" aria-hidden>
        <span className="flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full" style={{ background: S1 }} /> Kairos settings
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-2.5 w-2.5 rounded-full" style={{ background: S2 }} /> Classic MSPC
        </span>
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label="Median detection delay versus false alarms per batch">
        <line x1={P.l} x2={W - P.r} y1={H - P.b} y2={H - P.b} stroke="var(--color-chart-grid)" />
        <line x1={P.l} x2={P.l} y1={P.t} y2={H - P.b} stroke="var(--color-chart-grid)" />
        <text x={(W + P.l) / 2} y={H - 6} textAnchor="middle" fontSize="11" fill="var(--color-text-secondary)">
          False alarms per normal batch
        </text>
        <text x={12} y={(H - P.b) / 2} fontSize="11" fill="var(--color-text-secondary)" textAnchor="middle" transform={`rotate(-90 12 ${(H - P.b) / 2})`}>
          Median delay (h)
        </text>
        {[0, maxX / 2, maxX].map((v) => (
          <text key={v} x={xs(v)} y={H - P.b + 14} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)" className="num">
            {v.toFixed(1)}
          </text>
        ))}
        {[0, maxY / 2, maxY].map((v) => (
          <text key={v} x={P.l - 6} y={ys(v) + 4} textAnchor="end" fontSize="11" fill="var(--color-text-muted)" className="num">
            {v.toFixed(1)}
          </text>
        ))}
        {pts.map((p) => {
          const isChosen = p.threshold === chosen.alarm_threshold && Math.abs(p.persistence_rows * 0.2 - chosen.persistence_h) < 1e-6;
          return (
            <g key={`${p.threshold}-${p.persistence_rows}`}>
              <title>{`threshold ${p.threshold}, ${p.persistence_rows * 0.2} h persistence: ${p.detected}/10 detected, median ${fmt(p.median_delay_h)} h, ${fmt(p.false_alarms_per_batch, 2)} false alarms/batch`}</title>
              <circle cx={xs(p.false_alarms_per_batch)} cy={ys(p.median_delay_h!)} r={isChosen ? 7 : 5} fill={S1} stroke="var(--color-bg-surface)" strokeWidth={2} />
              {isChosen && (
                <text x={xs(p.false_alarms_per_batch) + 10} y={ys(p.median_delay_h!) - 8} fontSize="11" fill="var(--color-text-primary)">
                  chosen on validation
                </text>
              )}
            </g>
          );
        })}
        {base.median_delay_h !== null && (
          <g>
            <title>{`Classic MSPC: ${base.detected}/10 detected, median ${fmt(base.median_delay_h)} h, ${fmt(base.false_alarms_per_batch, 1)} false alarms/batch`}</title>
            <circle cx={xs(base.false_alarms_per_batch)} cy={ys(base.median_delay_h)} r={6} fill={S2} stroke="var(--color-bg-surface)" strokeWidth={2} />
            <text x={xs(base.false_alarms_per_batch) - 10} y={ys(base.median_delay_h) - 10} textAnchor="end" fontSize="11" fill="var(--color-text-secondary)">
              classic MSPC
            </text>
          </g>
        )}
      </svg>
    </figure>
  );
}

function EnergySection({ e }: { e: NonNullable<Metrics["energy"]> }) {
  const pts = e.pareto.points;
  const W = 620;
  const H = 280;
  const P = { l: 52, r: 20, t: 14, b: 40 };
  const xMax = Math.max(e.pareto.actual_kwh, ...pts.map((p) => p.kwh)) * 1.05;
  const xMin = Math.min(...pts.map((p) => p.kwh)) * 0.95;
  const yMax = Math.max(100, ...pts.map((p) => p.do_p5_pct));
  const yMin = Math.min(0, ...pts.map((p) => p.do_p5_pct));
  const xs = (v: number) => P.l + ((v - xMin) / (xMax - xMin)) * (W - P.l - P.r);
  const ys = (v: number) => H - P.b - ((v - yMin) / (yMax - yMin)) * (H - P.t - P.b);
  const tiles: [string, string][] = [
    [fmtInt(e.kwh_saved_per_batch), "kWh saved per batch"],
    [`${fmt(e.co2_saved_kg_per_batch / 1000, 1)} t`, "CO₂ avoided per batch"],
    [`₹${fmtInt(e.inr_saved_per_batch)}`, "saved per batch"],
  ];
  return (
    <Section
      title="Oxygen transfer versus energy"
      sub={`Each dot is one agitation × aeration setting held for a whole batch (batch ${e.pareto.batch}): the energy it uses against the oxygen floor it leaves (5th percentile of dissolved oxygen). Up and left is better.`}
    >
      <div className="grid grid-cols-[minmax(0,3fr)_minmax(0,2fr)] gap-6">
        <figure className="m-0">
          <div className="mb-2 flex gap-4 text-xs text-text-secondary" aria-hidden>
            <span className="flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-full" style={{ background: S1 }} /> Keeps oxygen safe
            </span>
            <span className="flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-full" style={{ background: S3 }} /> Falls below the safety target
            </span>
          </div>
          <svg viewBox={`0 0 ${W} ${H}`} className="w-full" role="img" aria-label="Energy per batch versus oxygen floor for each setting">
            <rect
              x={P.l}
              y={ys(e.target_do_pct)}
              width={W - P.l - P.r}
              height={H - P.b - ys(e.target_do_pct)}
              fill="color-mix(in srgb, var(--color-state-alarm) 8%, transparent)"
            />
            <line x1={P.l} x2={W - P.r} y1={ys(e.target_do_pct)} y2={ys(e.target_do_pct)} stroke="var(--color-state-alarm)" strokeDasharray="4 4" />
            <text x={W - P.r} y={ys(e.target_do_pct) - 6} textAnchor="end" fontSize="11" fill="var(--color-text-secondary)">
              safety target {fmt(e.target_do_pct, 0)}% sat
            </text>
            <line x1={xs(e.pareto.actual_kwh)} x2={xs(e.pareto.actual_kwh)} y1={P.t} y2={H - P.b} stroke="var(--color-chart-reference)" strokeDasharray="5 4" />
            <text x={xs(e.pareto.actual_kwh) - 6} y={P.t + 10} textAnchor="end" fontSize="11" fill="var(--color-text-secondary)">
              as actually run: {fmtInt(e.pareto.actual_kwh)} kWh
            </text>
            {pts.map((p) => (
              <circle
                key={`${p.rpm}-${p.aeration}`}
                cx={xs(p.kwh)}
                cy={ys(p.do_p5_pct)}
                r={5}
                fill={p.do_p5_pct >= e.target_do_pct ? S1 : S3}
                stroke="var(--color-bg-surface)"
                strokeWidth={2}
              >
                <title>{`${p.rpm} rpm, ${p.aeration} m³/min: ${fmtInt(p.kwh)} kWh, oxygen floor ${fmt(p.do_p5_pct, 0)}% sat`}</title>
              </circle>
            ))}
            {[xMin, (xMin + xMax) / 2, xMax].map((v) => (
              <text key={v} x={xs(v)} y={H - P.b + 16} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)" className="num">
                {fmtInt(v)}
              </text>
            ))}
            {[0, 50, 100].map((v) => (
              <text key={v} x={P.l - 8} y={ys(v) + 4} textAnchor="end" fontSize="11" fill="var(--color-text-muted)" className="num">
                {v}%
              </text>
            ))}
            <text x={(W + P.l) / 2} y={H - 4} textAnchor="middle" fontSize="11" fill="var(--color-text-secondary)">
              Energy per batch (kWh)
            </text>
            <text x={12} y={(H - P.b) / 2} fontSize="11" fill="var(--color-text-secondary)" textAnchor="middle" transform={`rotate(-90 12 ${(H - P.b) / 2})`}>
              Oxygen floor (% sat)
            </text>
          </svg>
        </figure>
        <div className="space-y-4">
          <div className="grid grid-cols-3 gap-2 text-center">
            {tiles.map(([v, l]) => (
              <div key={l} className="rounded-control bg-bg-inset px-2 py-3">
                <div className="display-num text-xl font-semibold">{v}</div>
                <div className="text-xs text-text-muted">{l}</div>
              </div>
            ))}
          </div>
          <p className="text-sm text-text-secondary">
            Kairos picks the cheapest agitation and aeration that keep dissolved oxygen above {fmt(e.target_do_pct, 0)}% sat, one
            cautious step at a time. The yield model sees no harm: forecasts move {fmt(e.yield_check_pct_change_at_70pct.min, 1)}% to
            +{fmt(e.yield_check_pct_change_at_70pct.max, 1)}%.
          </p>
          <div>
            <div className="eyebrow mb-1">Does the safety margin matter?</div>
            <table className="num w-full text-sm">
              <caption className="sr-only">Energy saving by safety margin</caption>
              <tbody>
                {e.sensitivity.map((s) => (
                  <tr key={s.margin_pct} className="border-t border-border-subtle">
                    <td className="py-1 text-text-secondary">DO kept ≥ {fmt(s.target_do_pct, 0)}% sat</td>
                    <td className="text-right">{fmt(s.mean_saving_pct, 1)}% saved</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="flex items-center gap-2 text-xs text-text-muted">
            <ProvenanceChip provenance="assumed" source={e.provenance} /> CO₂ and ₹ use an assumed India grid factor and tariff.
          </p>
        </div>
      </div>
    </Section>
  );
}
