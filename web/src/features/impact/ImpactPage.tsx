import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { ArrowDownRight, ChevronDown, FileSpreadsheet, FileText, Info, Loader2 } from "lucide-react";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";

import { Page, PageHeader, SectionTitle } from "@/components/layout";
import { ErrorState, Panel, ProvenanceChip, Skeleton } from "@/components/primitives";
import { api, downloadImpact, type Impact, type ImpactPeriod, type ImpactRow } from "@/lib/api/client";
import type { Provenance } from "@/lib/api/types";

import { PeriodLines, PlantBars, ShareBar, Sparkline, StackedBars, TipRow } from "./charts";

type Currency = "INR" | "USD";

const PERIODS: { id: ImpactPeriod; label: string }[] = [
  { id: "month", label: "Monthly" },
  { id: "quarter", label: "Quarterly" },
  { id: "year", label: "Yearly" },
];

const SOURCES = [
  { key: "rescued_batches", label: "Rescued batches", color: "var(--color-chart-series1)" },
  { key: "energy", label: "Energy", color: "var(--color-chart-series2)" },
  { key: "feedstock", label: "Feedstock", color: "var(--color-chart-series3)" },
];

function moneyFormatter(currency: Currency, fx: number) {
  return (inr: number): string => {
    if (currency === "USD") {
      const v = inr / fx;
      if (Math.abs(v) >= 1e6) return `$${(v / 1e6).toFixed(2)}M`;
      if (Math.abs(v) >= 1e3) return `$${(v / 1e3).toFixed(0)}k`;
      return `$${v.toFixed(0)}`;
    }
    if (Math.abs(inr) >= 1e7) return `₹${(inr / 1e7).toFixed(2)} Cr`;
    if (Math.abs(inr) >= 1e5) return `₹${(inr / 1e5).toFixed(1)} L`;
    return `₹${Math.round(inr).toLocaleString("en-IN")}`;
  };
}

const mwh = (kwh: number) => `${(kwh / 1000).toLocaleString("en-US", { maximumFractionDigits: kwh >= 1e5 ? 0 : 1 })} MWh`;
const tonnes = (kg: number) => `${(kg / 1000).toLocaleString("en-US", { maximumFractionDigits: kg >= 1e5 ? 0 : 1 })} t`;
const pct = (a: number, b: number) => (b > 0 ? `${Math.round((a / b) * 100)}%` : "—");

function periodOf(month: string, period: ImpactPeriod): string {
  const [y, m] = month.split("-");
  if (period === "year") return y!;
  if (period === "quarter") return `${y}-Q${Math.floor((Number(m) - 1) / 3) + 1}`;
  return month;
}

function monthName(m: string): string {
  const [y, mm] = m.split("-");
  return new Date(Number(y), Number(mm) - 1, 1).toLocaleString("en-US", { month: "short", year: "numeric" });
}

function Segmented<T extends string>({ value, options, onChange, label }: { value: T; options: { id: T; label: string }[]; onChange: (v: T) => void; label: string }) {
  return (
    <div className="flex items-center gap-1 rounded-control bg-bg-inset p-1 text-sm" role="group" aria-label={label}>
      {options.map((o) => (
        <button
          key={o.id}
          type="button"
          aria-pressed={o.id === value}
          onClick={() => onChange(o.id)}
          className={`rounded-control px-3 py-1.5 font-medium transition-colors ${
            o.id === value ? "bg-bg-surface text-text-primary shadow-sm" : "text-text-secondary hover:text-text-primary"
          }`}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

function ExportButton({ ext, period, plant }: { ext: "xlsx" | "pdf"; period: ImpactPeriod; plant: string }) {
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  const Icon = ext === "xlsx" ? FileSpreadsheet : FileText;
  return (
    <button
      type="button"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        setFailed(false);
        try {
          await downloadImpact(ext, period, plant);
        } catch {
          setFailed(true);
        } finally {
          setBusy(false);
        }
      }}
      className="inline-flex items-center gap-1.5 rounded-control border border-border-strong bg-bg-surface px-3 py-1.5 text-sm font-medium hover:bg-bg-elevated disabled:opacity-60"
      title={failed ? "Export failed, try again" : `Download ${ext === "xlsx" ? "Excel" : "PDF"} report`}
    >
      {busy ? <Loader2 size={16} className="animate-spin" aria-hidden /> : <Icon size={16} aria-hidden />}
      {failed ? "Retry" : ext === "xlsx" ? "Excel" : "PDF"}
    </button>
  );
}

function breakdownRows(series: ImpactRow[]): Record<string, number>[] {
  return series.map((r) => ({ ...r.breakdown_inr }));
}

export default function ImpactPage() {
  const [period, setPeriod] = useState<ImpactPeriod>("month");
  const [plant, setPlant] = useState("all");
  const [currency, setCurrency] = useState<Currency>("INR");
  const q = useQuery({
    queryKey: ["impact", period, plant],
    queryFn: () => api.impact(period, plant),
    placeholderData: keepPreviousData,
    staleTime: 5 * 60_000,
  });
  // Monthly series for the hero and tile sparklines, whatever period the charts show.
  const monthly = useQuery({
    queryKey: ["impact", "month", plant],
    queryFn: () => api.impact("month", plant),
    placeholderData: keepPreviousData,
    staleTime: 5 * 60_000,
  });

  return (
    <Page wide>
      <PageHeader
        eyebrow="Impact"
        title="What Kairos saves"
        subtitle="Money, energy and raw material saved across the plants. Plant history is simulated; the improvement rates are Kairos's measured results on held-out batches."
      />
      <div className="sticky top-0 z-20 -mx-4 flex flex-wrap items-center gap-2 border-b border-border-subtle bg-bg-base/85 px-4 py-2.5 backdrop-blur md:-mx-8 md:px-8">
        <Segmented value={period} options={PERIODS} onChange={setPeriod} label="Period" />
        <select
          value={plant}
          onChange={(e) => setPlant(e.target.value)}
          aria-label="Plant"
          className="rounded-control border border-border-strong bg-bg-surface px-3 py-2 text-sm text-text-primary"
        >
          <option value="all">All plants</option>
          {q.data?.by_plant.map((p) => (
            <option key={p.plant_id} value={p.plant_id}>
              {p.name}
            </option>
          ))}
        </select>
        <Segmented
          value={currency}
          options={[
            { id: "INR", label: "₹" },
            { id: "USD", label: "$" },
          ]}
          onChange={setCurrency}
          label="Currency"
        />
        {q.isFetching && !q.isLoading && <Loader2 size={16} className="animate-spin text-text-muted" aria-label="Updating" />}
        <div className="ml-auto flex items-center gap-2">
          <ExportButton ext="xlsx" period={period} plant={plant} />
          <ExportButton ext="pdf" period={period} plant={plant} />
        </div>
      </div>
      {q.isLoading ? (
        <div className="space-y-4">
          <Skeleton className="h-52" />
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-32" />
            ))}
          </div>
          <Skeleton className="h-80" />
        </div>
      ) : q.isError || !q.data ? (
        <Panel>
          <ErrorState title="Impact data unavailable" message="The server did not return impact figures." onRetry={() => void q.refetch()} />
        </Panel>
      ) : (
        <ImpactBody data={q.data} months={monthly.data?.series ?? []} currency={currency} period={period} plant={plant} onPlant={setPlant} />
      )}
    </Page>
  );
}

function Delta({ from, to, label, format }: { from: number; to: number; label: string; format: (v: number) => string }) {
  const change = from > 0 ? (to - from) / from : 0;
  return (
    <div className="min-w-0">
      <div className="flex items-center gap-1 text-lg font-semibold" style={{ color: "var(--color-state-healthy)" }}>
        <ArrowDownRight size={18} aria-hidden />
        <span className="display-num">{Math.abs(Math.round(change * 100))}%</span>
      </div>
      <div className="truncate text-xs text-text-secondary">{label}</div>
      <div className="num truncate text-xs text-text-muted">
        {format(from)} → {format(to)}
      </div>
    </div>
  );
}

function KpiTile({ label, value, sub, color, trend }: { label: string; value: string; sub: string; color: string; trend: number[] }) {
  return (
    <div className="flex flex-col rounded-card border border-border-subtle bg-bg-surface p-4">
      <div className="flex items-center gap-2 text-xs font-medium text-text-secondary">
        <span className="h-2 w-2 rounded-full" style={{ background: color }} aria-hidden />
        {label}
      </div>
      <div className="display-num mt-1.5 text-2xl font-semibold text-text-primary">{value}</div>
      <div className="mt-0.5 line-clamp-2 min-h-[2rem] text-xs text-text-muted">{sub}</div>
      <div className="mt-2">
        <Sparkline values={trend} color={color} height={34} />
      </div>
    </div>
  );
}

function ImpactBody({
  data,
  months,
  currency,
  period,
  plant,
  onPlant,
}: {
  data: Impact;
  months: ImpactRow[];
  currency: Currency;
  period: ImpactPeriod;
  plant: string;
  onPlant: (p: string) => void;
}) {
  const fx = Number(data.provenance.assumptions.find((a) => a.key === "fx")?.value ?? 83);
  const money = useMemo(() => moneyFormatter(currency, fx), [currency, fx]);
  const t = data.totals;
  const b = data.baseline_year;
  const labels = data.series.map((r) => r.period);
  const liveIndex = labels.indexOf(periodOf(data.kairos_live_from, period));
  const cumulative = useMemo(() => {
    let acc = 0;
    return data.series.map((r) => (acc += r.money_saved_inr));
  }, [data.series]);
  const live = useMemo(() => months.filter((m) => m.period >= data.kairos_live_from), [months, data.kairos_live_from]);
  const liveCum = useMemo(() => {
    let acc = 0;
    return live.map((r) => (acc += r.money_saved_inr));
  }, [live]);
  const scope = plant === "all" ? "all plants" : (data.by_plant.find((p) => p.plant_id === plant)?.name ?? plant);
  const measured = data.provenance.measured_rates;
  const per = period;

  return (
    <>
      {/* Hero: the one number, what changed, and where it comes from */}
      <section
        className="relative overflow-hidden rounded-card border border-border-subtle p-5 md:p-7"
        style={{
          background:
            "linear-gradient(135deg, color-mix(in srgb, var(--color-accent-500) 14%, var(--color-bg-surface)), var(--color-bg-surface) 62%)",
        }}
      >
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)] lg:gap-12">
          <div className="min-w-0">
            <div className="eyebrow">Saved in the last 12 months · {scope}</div>
            <div className="display-num mt-2 text-4xl font-semibold leading-none tracking-tight text-text-primary sm:text-5xl md:text-6xl">
              {money(t.money_saved_inr)}
            </div>
            <div className="mt-2 text-sm text-text-secondary">
              {money(t.money_saved_inr / 12)} a month on average since Kairos went live in {monthName(data.kairos_live_from)}
            </div>
            <div className="mt-5 max-w-md">
              <Sparkline values={liveCum.length ? liveCum : cumulative} color="var(--color-accent-500)" height={56} />
              <div className="mt-1 text-[11px] text-text-muted">Cumulative savings since go-live</div>
            </div>
          </div>
          <div className="min-w-0 space-y-5">
            <div>
              <div className="mb-2.5 text-xs font-medium text-text-secondary">Where the savings come from</div>
              <ShareBar
                format={money}
                parts={SOURCES.map((src) => ({
                  label: src.label,
                  color: src.color,
                  value: t.breakdown_inr[src.key as keyof ImpactRow["breakdown_inr"]],
                }))}
              />
            </div>
            <div className="border-t border-border-subtle pt-4">
              <div className="mb-2.5 text-xs font-medium text-text-secondary">Versus the year before Kairos</div>
              <div className="grid grid-cols-2 gap-4">
                <Delta from={b.failed_actual} to={t.failed_actual} label="failed batches" format={(v) => v.toLocaleString("en-US")} />
                <Delta from={t.energy_kwh_baseline} to={t.energy_kwh_actual} label="agitation + aeration energy" format={mwh} />
              </div>
            </div>
          </div>
        </div>
      </section>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <KpiTile
          label="Money saved"
          value={money(t.money_saved_inr)}
          sub={`last 12 months · ${scope}`}
          color="var(--color-accent-500)"
          trend={live.map((m) => m.money_saved_inr)}
        />
        <KpiTile
          label="Energy saved"
          value={mwh(t.energy_saved_kwh)}
          sub={`${pct(t.energy_saved_kwh, t.energy_kwh_baseline)} of agitation + aeration · ${tonnes(t.co2_saved_kg)} CO₂ avoided`}
          color="var(--color-chart-series2)"
          trend={live.map((m) => m.energy_saved_kwh)}
        />
        <KpiTile
          label="Raw material saved"
          value={tonnes(t.feedstock_saved_kg)}
          sub="sugar feedstock not wasted in failed batches + tighter feeding"
          color="var(--color-chart-series3)"
          trend={live.map((m) => m.feedstock_saved_kg)}
        />
        <KpiTile
          label="Batches rescued"
          value={t.batches_rescued.toLocaleString("en-US")}
          sub={`of ${t.batches.toLocaleString("en-US")} batches run in the last 12 months`}
          color="var(--color-chart-series1)"
          trend={live.map((m) => m.batches_rescued)}
        />
      </div>

      <Panel className="p-4 md:p-6">
        <SectionTitle aside={`${currency} per ${per}`}>Savings by source</SectionTitle>
        <StackedBars labels={labels} keys={SOURCES} rows={breakdownRows(data.series)} format={money} liveIndex={liveIndex} yLabel="Money saved" height={320} />
        <p className="mt-3 text-xs text-text-muted">
          Before go-live Kairos saves nothing by construction; adoption ramps 30% → 60% → 90% of batches over the first three months.
        </p>
      </Panel>

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel className="p-4 md:p-6">
          <SectionTitle aside={`MWh per ${per}`}>Energy consumption</SectionTitle>
          <PeriodLines
            labels={labels}
            liveIndex={liveIndex}
            series={[
              { key: "base", label: "Without Kairos", color: "var(--color-chart-reference)", values: data.series.map((r) => r.energy_kwh_baseline / 1000), dashed: true },
              { key: "act", label: "With Kairos", color: "var(--color-chart-series2)", values: data.series.map((r) => r.energy_kwh_actual / 1000) },
            ]}
            format={(v) => Math.round(v).toLocaleString("en-US")}
            yLabel="Energy consumption, MWh"
            height={280}
            extraTip={(i) => (
              <>
                <TipRow label="Saved" value={mwh(data.series[i]!.energy_saved_kwh)} strong />
                <TipRow label="CO₂ avoided" value={tonnes(data.series[i]!.co2_saved_kg)} />
              </>
            )}
          />
        </Panel>
        <Panel className="p-4 md:p-6">
          <SectionTitle aside={`tonnes of sugar feedstock per ${per}`}>Raw material saved</SectionTitle>
          <StackedBars
            labels={labels}
            keys={[{ key: "feed", label: "Feedstock saved", color: "var(--color-chart-series3)" }]}
            rows={data.series.map((r) => ({ feed: r.feedstock_saved_kg / 1000 }))}
            format={(v) => `${v.toLocaleString("en-US", { maximumFractionDigits: v < 10 ? 1 : 0 })} t`}
            liveIndex={liveIndex}
            yLabel="Feedstock saved, tonnes"
            height={280}
            extraTip={(i) => (
              <>
                <TipRow label="Batches rescued" value={String(data.series[i]!.batches_rescued)} />
                <TipRow label="Failures without Kairos" value={String(data.series[i]!.failed_before_baseline)} />
                <TipRow label="Failures with Kairos" value={String(data.series[i]!.failed_actual)} />
              </>
            )}
          />
        </Panel>
      </div>

      <div className="grid gap-4 lg:grid-cols-5">
        <Panel className="p-4 md:p-6 lg:col-span-3">
          <SectionTitle aside="last 12 months · click to filter">Savings by plant</SectionTitle>
          <PlantBars
            items={[...data.by_plant]
              .sort((x, y) => y.money_saved_inr - x.money_saved_inr)
              .map((p) => ({ id: p.plant_id, label: p.name, sub: p.city, value: p.money_saved_inr }))}
            format={money}
            selected={plant === "all" ? undefined : plant}
            onSelect={(id) => onPlant(plant === id ? "all" : id)}
            detail={(id) => {
              const p = data.by_plant.find((x) => x.plant_id === id)!;
              return (
                <>
                  <TipRow label="Money saved" value={money(p.money_saved_inr)} />
                  <TipRow label="Energy saved" value={mwh(p.energy_saved_kwh)} />
                  <TipRow label="Feedstock saved" value={tonnes(p.feedstock_saved_kg)} />
                  <TipRow label="Batches rescued" value={String(p.batches_rescued)} />
                </>
              );
            }}
          />
        </Panel>
        <Panel className="p-4 md:p-6 lg:col-span-2">
          <SectionTitle aside={currency}>Cumulative savings</SectionTitle>
          <PeriodLines
            labels={labels}
            legend={false}
            liveIndex={liveIndex}
            series={[{ key: "cum", label: "Cumulative", color: "var(--color-accent-500)", values: cumulative, area: true }]}
            format={money}
            yLabel="Cumulative money saved"
            height={330}
            extraTip={(i) => <TipRow label={`This ${per}`} value={money(data.series[i]!.money_saved_inr)} />}
          />
        </Panel>
      </div>

      <details className="group rounded-card border border-border-subtle bg-bg-surface">
        <summary className="flex cursor-pointer list-none items-center gap-3 px-4 py-3 md:px-6">
          <Info size={16} className="shrink-0 text-text-muted" aria-hidden />
          <span className="min-w-0 flex-1">
            <span className="text-sm font-semibold">Method and assumptions</span>
            <span className="ml-2 text-xs text-text-muted">
              plant financials simulated · measured: {Math.round(measured.detection_rate * 100)}% faults caught, {measured.energy_saving_pct}% energy
            </span>
          </span>
          <ChevronDown size={16} className="shrink-0 text-text-muted transition-transform group-open:rotate-180" aria-hidden />
        </summary>
        <div className="space-y-3 border-t border-border-subtle px-4 py-4 md:px-6">
          <p className="text-sm text-text-secondary">
            Plant financials are simulated for this demo. Reduction rates come from Kairos evaluation on held-out batches (
            <Link to="/app/evidence" className="text-accent-500 underline-offset-2 hover:underline">
              Evidence page
            </Link>
            ). With a plant&apos;s own ledger the same model uses its real numbers.
          </p>
          <div className="overflow-x-auto">
            <table className="w-full min-w-[520px] text-sm">
              <thead>
                <tr className="border-b border-border-subtle text-left text-xs text-text-muted">
                  <th className="py-2 pr-4 font-medium">Input</th>
                  <th className="py-2 pr-4 text-right font-medium">Value</th>
                  <th className="py-2 pr-4 font-medium">Unit</th>
                  <th className="py-2 font-medium">Source</th>
                </tr>
              </thead>
              <tbody>
                {data.provenance.assumptions.map((a) => (
                  <tr key={a.key} className="border-b border-border-subtle last:border-0">
                    <td className="py-2 pr-4">{a.label}</td>
                    <td className="num py-2 pr-4 text-right">{typeof a.value === "number" ? a.value.toLocaleString("en-US") : a.value}</td>
                    <td className="py-2 pr-4 text-text-secondary">{a.unit}</td>
                    <td className="py-2">
                      <span className="inline-flex items-center gap-2 text-text-secondary">
                        <ProvenanceChip
                          provenance={(a.provenance === "simulated" ? "synthetic" : a.provenance) as Provenance}
                          source={a.provenance === "measured" ? measured.source : undefined}
                        />
                        {a.provenance}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="text-xs text-text-muted">{data.provenance.simulated}</p>
        </div>
      </details>
    </>
  );
}
