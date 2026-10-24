import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { FileSpreadsheet, FileText, Info, Loader2 } from "lucide-react";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";

import { Page, PageHeader, SectionTitle, StatTile } from "@/components/layout";
import { ErrorState, Panel, ProvenanceChip, Skeleton } from "@/components/primitives";
import { api, downloadImpact, type Impact, type ImpactPeriod, type ImpactRow } from "@/lib/api/client";
import type { Provenance } from "@/lib/api/types";

import { PeriodLines, PlantBars, StackedBars, TipRow } from "./charts";

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
      className="inline-flex items-center gap-2 rounded-control border border-border-strong bg-bg-surface px-3 py-2 text-sm font-medium hover:bg-bg-elevated disabled:opacity-60"
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

  return (
    <Page wide>
      <PageHeader
        eyebrow="Impact"
        title="What Kairos saves"
        subtitle="Money, energy and raw material saved across the plants, month by month. Plant history is simulated; the improvement rates are Kairos's measured results on held-out batches."
        actions={
          <>
            <ExportButton ext="xlsx" period={period} plant={plant} />
            <ExportButton ext="pdf" period={period} plant={plant} />
          </>
        }
      />
      <div className="flex flex-wrap items-center gap-3">
        <Segmented value={period} options={PERIODS} onChange={setPeriod} label="Period" />
        <label className="flex items-center gap-2 text-sm">
          <span className="text-text-secondary">Plant</span>
          <select
            value={plant}
            onChange={(e) => setPlant(e.target.value)}
            className="rounded-control border border-border-strong bg-bg-surface px-3 py-2 text-sm text-text-primary"
          >
            <option value="all">All plants</option>
            {q.data?.by_plant.map((p) => (
              <option key={p.plant_id} value={p.plant_id}>
                {p.name}
              </option>
            ))}
          </select>
        </label>
        <Segmented
          value={currency}
          options={[
            { id: "INR", label: "₹ INR" },
            { id: "USD", label: "$ USD" },
          ]}
          onChange={setCurrency}
          label="Currency"
        />
        {q.isFetching && !q.isLoading && <Loader2 size={16} className="animate-spin text-text-muted" aria-label="Updating" />}
      </div>
      <div
        className="flex items-start gap-3 rounded-card border px-4 py-3 text-sm"
        style={{
          borderColor: "color-mix(in srgb, var(--color-state-watch) 45%, transparent)",
          background: "color-mix(in srgb, var(--color-state-watch) 8%, transparent)",
        }}
      >
        <Info size={18} className="mt-0.5 shrink-0" style={{ color: "var(--color-state-watch)" }} aria-hidden />
        <p className="text-text-secondary">
          <span className="font-semibold text-text-primary">Plant financials are simulated for this demo.</span> Reduction
          rates come from Kairos evaluation on held-out batches (
          <Link to="/app/evidence" className="text-accent-500 underline-offset-2 hover:underline">
            Evidence page
          </Link>
          ). Assumptions are listed below; with a plant's own ledger the same model uses its real numbers.
        </p>
      </div>
      {q.isLoading ? (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-24" />
            ))}
          </div>
          <Skeleton className="h-80" />
        </div>
      ) : q.isError || !q.data ? (
        <Panel>
          <ErrorState title="Impact data unavailable" message="The server did not return impact figures." onRetry={() => void q.refetch()} />
        </Panel>
      ) : (
        <ImpactBody data={q.data} currency={currency} period={period} plant={plant} onPlant={setPlant} />
      )}
    </Page>
  );
}

function ImpactBody({
  data,
  currency,
  period,
  plant,
  onPlant,
}: {
  data: Impact;
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
  const scope = plant === "all" ? "all plants" : (data.by_plant.find((p) => p.plant_id === plant)?.name ?? plant);
  const measured = data.provenance.measured_rates;

  return (
    <>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile
          label="Money saved, last 12 months"
          value={money(t.money_saved_inr)}
          tone="var(--color-chart-series1)"
          sub={`${money(t.money_saved_inr / 12)} per month on average · ${scope}`}
        />
        <StatTile
          label="Energy saved"
          value={mwh(t.energy_saved_kwh)}
          tone="var(--color-chart-series2)"
          sub={`${pct(t.energy_saved_kwh, t.energy_kwh_baseline)} of agitation + aeration · ${tonnes(t.co2_saved_kg)} CO₂ avoided`}
        />
        <StatTile
          label="Feedstock saved"
          value={tonnes(t.feedstock_saved_kg)}
          tone="var(--color-chart-series3)"
          sub="sugar not wasted in failed batches + tighter feeding"
        />
        <StatTile
          label="Batches rescued"
          value={t.batches_rescued.toLocaleString("en-US")}
          sub={`failed batches ${b.failed_actual} → ${t.failed_actual} year on year (${t.batches.toLocaleString("en-US")} run)`}
        />
      </div>

      <Panel className="p-4 md:p-5">
        <SectionTitle aside={`${currency} per ${period} · Kairos live from ${monthName(data.kairos_live_from)}`}>Savings by source</SectionTitle>
        <StackedBars
          labels={labels}
          keys={SOURCES}
          rows={breakdownRows(data.series)}
          format={money}
          liveIndex={liveIndex}
          yLabel="Money saved"
          height={320}
        />
        <p className="mt-2 text-xs text-text-muted">
          Before go-live Kairos saves nothing by construction; adoption ramps 30% → 60% → 90% of batches over the first three months.
        </p>
      </Panel>

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel className="p-4 md:p-5">
          <SectionTitle aside={currency}>Cumulative savings</SectionTitle>
          <PeriodLines
            labels={labels}
            legend={false}
            series={[{ key: "cum", label: "Cumulative", color: "var(--color-chart-series1)", values: cumulative, area: true }]}
            format={money}
            yLabel="Cumulative money saved"
            extraTip={(i) => <TipRow label="This period" value={money(data.series[i]!.money_saved_inr)} />}
          />
        </Panel>
        <Panel className="p-4 md:p-5">
          <SectionTitle aside="agitation + aeration, MWh">Energy consumption</SectionTitle>
          <PeriodLines
            labels={labels}
            series={[
              { key: "base", label: "Without Kairos", color: "var(--color-chart-reference)", values: data.series.map((r) => r.energy_kwh_baseline / 1000), dashed: true },
              { key: "act", label: "With Kairos", color: "var(--color-chart-series2)", values: data.series.map((r) => r.energy_kwh_actual / 1000) },
            ]}
            format={(v) => `${Math.round(v).toLocaleString("en-US")}`}
            yLabel="Energy consumption, MWh"
            extraTip={(i) => (
              <>
                <TipRow label="Saved" value={mwh(data.series[i]!.energy_saved_kwh)} strong />
                <TipRow label="CO₂ avoided" value={tonnes(data.series[i]!.co2_saved_kg)} />
              </>
            )}
          />
        </Panel>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Panel className="p-4 md:p-5">
          <SectionTitle aside="tonnes of sugar feedstock">Raw material saved</SectionTitle>
          <PeriodLines
            labels={labels}
            series={[
              { key: "feed", label: "Feedstock saved", color: "var(--color-chart-series3)", values: data.series.map((r) => r.feedstock_saved_kg / 1000), area: true },
            ]}
            legend={false}
            format={(v) => `${v.toLocaleString("en-US", { maximumFractionDigits: 0 })} t`}
            yLabel="Feedstock saved, tonnes"
            extraTip={(i) => (
              <>
                <TipRow label="Batches rescued" value={String(data.series[i]!.batches_rescued)} />
                <TipRow label="Failures without Kairos" value={String(data.series[i]!.failed_before_baseline)} />
                <TipRow label="Failures" value={String(data.series[i]!.failed_actual)} />
              </>
            )}
          />
        </Panel>
        <Panel className="p-4 md:p-5">
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
      </div>

      <Panel className="p-4 md:p-5">
        <SectionTitle aside={`measured rates: ${Math.round(measured.detection_rate * 100)}% faults caught · ${measured.energy_saving_pct}% energy`}>
          Assumptions
        </SectionTitle>
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
        <p className="mt-3 text-xs text-text-muted">{data.provenance.simulated}</p>
      </Panel>
    </>
  );
}
