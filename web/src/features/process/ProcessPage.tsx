import { useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { ArrowRight, Dna, ExternalLink, Gauge as GaugeIcon, ShieldAlert, Sprout, TrendingUp, Zap } from "lucide-react";
import { useEffect, type ReactNode } from "react";
import { useSearchParams } from "react-router-dom";

import { EmptyState, ErrorState, Panel, ProvenanceChip, Skeleton, Tip } from "@/components/primitives";
import { api } from "@/lib/api/client";
import { fmt, fmtInt } from "@/lib/format";
import {
  FAMILY_LABEL,
  FIT_LABEL,
  useProcess,
  useProcesses,
  useProcessStore,
  useSelectedProcess,
  type Family,
  type ProcessDetail,
  type ProcessSummary,
} from "@/lib/process";

import { FermenterDiagram, REACTOR_LABEL } from "./FermenterDiagram";

const FAMILY_ICON: Record<Family, typeof Sprout> = { biomass: Sprout, precision: Dna };
const FIT_COLOR = {
  high: "var(--color-state-healthy)",
  medium: "var(--color-state-watch)",
  low: "var(--color-state-alarm)",
} as const;

const SETPOINT_LABEL: Record<string, string> = {
  temp_c: "Temperature",
  ph: "pH",
  do_pct: "Dissolved oxygen",
  dilution_rate_per_h: "Dilution rate",
  methanol_g_l: "Methanol",
  glucose_g_l: "Glucose",
  light_umol_m2_s: "Light",
  h2_o2_ratio: "H₂ : O₂ ratio",
  co2_pct: "CO₂",
  pressure_bar: "Pressure",
  biomass_g_l: "Biomass",
  rna_reduction_temp_c: "RNA-reduction heat step",
  rq: "Respiratory quotient",
  productivity_g_l_h: "Productivity",
};

const UNIT: Record<string, string> = {
  temp_c: "°C",
  do_pct: "% sat",
  dilution_rate_per_h: "1/h",
  methanol_g_l: "g/L",
  glucose_g_l: "g/L",
  light_umol_m2_s: "µmol/m²/s",
  co2_pct: "%",
  pressure_bar: "bar",
  biomass_g_l: "g/L",
  rna_reduction_temp_c: "°C",
  productivity_g_l_h: "g/L/h",
};

function Chip({ children }: { children: ReactNode }) {
  return <span className="rounded-full border border-border-subtle bg-bg-inset px-2.5 py-0.5 text-xs text-text-secondary">{children}</span>;
}

function Gallery({ list, current }: { list: ProcessSummary[]; current: string }) {
  const select = useProcessStore((s) => s.select);
  return (
    <div className="grid grid-cols-2 gap-4">
      {(["biomass", "precision"] as Family[]).map((fam) => {
        const Icon = FAMILY_ICON[fam];
        return (
          <div key={fam}>
            <div className="eyebrow mb-2 flex items-center gap-1.5">
              <Icon size={12} /> {FAMILY_LABEL[fam]}
            </div>
            <div className="grid grid-cols-4 gap-2">
              {list
                .filter((p) => p.family === fam)
                .map((p) => (
                  <button
                    key={p.id}
                    onClick={() => select(p.id)}
                    aria-pressed={p.id === current}
                    className="rounded-card border p-2.5 text-left transition-colors hover:border-border-strong"
                    style={{
                      borderColor: p.id === current ? "var(--color-accent-500)" : "var(--color-border-subtle)",
                      background: p.id === current ? "var(--color-accent-glow)" : "var(--color-bg-surface)",
                    }}
                  >
                    <div className="text-sm font-medium leading-tight">{p.name}</div>
                    <div className="mt-0.5 truncate text-xs text-text-muted">{p.example?.company ?? p.organism}</div>
                  </button>
                ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function Hero({ p }: { p: ProcessDetail }) {
  const fit = p.kairos?.benchmark_fit ?? "medium";
  const Icon = FAMILY_ICON[p.family];
  return (
    <div className="flex items-start justify-between gap-6">
      <div className="min-w-0">
        <div className="flex items-center gap-2 text-sm" style={{ color: "var(--color-accent-500)" }}>
          <Icon size={15} /> {FAMILY_LABEL[p.family]}
        </div>
        <h1 className="mt-1 text-3xl font-semibold tracking-tight md:text-4xl">{p.name}</h1>
        <p className="mt-1 max-w-3xl text-lg text-text-secondary">{p.product}</p>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <Chip>
            <i>{p.organism}</i>
          </Chip>
          <Chip>{p.mode.replace("_", "-")}</Chip>
          <Chip>{REACTOR_LABEL[p.reactor] ?? p.reactor}</Chip>
          <Chip>product: {p.product_location}</Chip>
          {p.example?.company && (
            <a
              href={p.example.url}
              target="_blank"
              rel="noreferrer"
              className="flex items-center gap-1 rounded-full border border-border-subtle px-2.5 py-0.5 text-xs text-text-secondary hover:text-text-primary"
            >
              Commercial example: {p.example.company} <ExternalLink size={11} />
            </a>
          )}
        </div>
        {p.naming_note && <p className="mt-2 text-xs text-text-muted">{p.naming_note}</p>}
      </div>
      <Tip content={`How well our live benchmark (IndPenSim penicillin fed-batch, an aerobic filamentous fungus) represents this process: ${p.kairos?.benchmark_fit_why}`}>
        <div tabIndex={0} className="shrink-0 rounded-card border border-border-subtle bg-bg-surface px-4 py-3 text-center">
          <div className="eyebrow">Benchmark fit</div>
          <div className="display mt-1 text-lg font-semibold" style={{ color: FIT_COLOR[fit] }}>
            {FIT_LABEL[fit]}
          </div>
          <div className="max-w-[13rem] text-xs text-text-muted">{p.kairos?.benchmark_fit_why}</div>
        </div>
      </Tip>
    </div>
  );
}

function Setpoints({ p }: { p: ProcessDetail }) {
  const rows = Object.entries(p.setpoints ?? {});
  return (
    <table className="w-full text-sm">
      <caption className="sr-only">Typical setpoints</caption>
      <tbody>
        {rows.map(([k, r]) => (
          <tr key={k} className="border-t border-border-subtle">
            <td className="py-1.5 text-text-secondary">{SETPOINT_LABEL[k] ?? k.replaceAll("_", " ")}</td>
            <td className="num text-right">
              {r.value !== undefined ? r.value : r.min === r.max ? r.min : `${r.min}–${r.max}`} {r.unit ?? UNIT[k] ?? ""}
            </td>
            <td className="w-8 pl-2 text-right">
              <ProvenanceChip provenance={r.provenance} source={r.source} />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function Phases({ p }: { p: ProcessDetail }) {
  return (
    <ol className="grid gap-3" style={{ gridTemplateColumns: `repeat(${p.phases.length}, minmax(0, 1fr))` }}>
      {p.phases.map((ph, i) => (
        <motion.li
          key={ph.name}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: i * 0.06, duration: 0.2 }}
          className="relative rounded-card border border-border-subtle bg-bg-surface p-4"
        >
          <div className="flex items-center gap-2">
            <span
              className="display-num flex h-7 w-7 items-center justify-center rounded-full text-sm font-semibold"
              style={{ background: "var(--color-accent-glow)", color: "var(--color-accent-500)" }}
            >
              {i + 1}
            </span>
            <span className="text-xs text-text-muted">{ph.duration}</span>
          </div>
          <h3 className="display mt-2 font-semibold leading-snug">{ph.name}</h3>
          <p className="mt-1 text-sm text-text-secondary">{ph.goal}</p>
          <ul className="mt-3 space-y-1.5">
            {ph.controls.map((c) => (
              <li key={c.param + c.action} className="text-xs">
                <span className="font-medium text-text-primary">{c.param}</span>
                <span className="text-text-secondary"> · {c.action}</span>
              </li>
            ))}
          </ul>
          {i < p.phases.length - 1 && (
            <ArrowRight size={16} className="absolute -right-3 top-1/2 z-10 -translate-y-1/2 rounded-full bg-bg-base text-text-muted" aria-hidden />
          )}
        </motion.li>
      ))}
    </ol>
  );
}

function HelpCard({ icon, kpi, title, children }: { icon: ReactNode; kpi: string; title: string; children: ReactNode }) {
  return (
    <Panel className="p-5">
      <div className="flex items-center gap-2">
        <span className="flex h-8 w-8 items-center justify-center rounded-control" style={{ background: "var(--color-accent-glow)", color: "var(--color-accent-500)" }}>
          {icon}
        </span>
        <span className="eyebrow">{kpi}</span>
      </div>
      <h3 className="display mt-2 text-lg font-semibold">{title}</h3>
      <div className="mt-2 space-y-2 text-sm text-text-secondary">{children}</div>
    </Panel>
  );
}

function HowKairosHelps({ p }: { p: ProcessDetail }) {
  const metrics = useQuery({ queryKey: ["metrics"], queryFn: api.metrics, staleTime: 60_000 });
  const m = metrics.data;
  const c30 = m?.yield?.checkpoints.find((c) => c.progress === 0.3);
  const k = m?.faults?.summary.kairos;
  return (
    <div className="grid grid-cols-3 gap-4">
      <HelpCard icon={<TrendingUp size={16} />} kpi="KPI 1 · Early yield" title="Know the outcome early">
        <p>{p.kairos.yield_signal}</p>
        {c30 && (
          <p className="text-xs text-text-muted">
            On the benchmark: {fmtInt(c30.models.kairos!.mae)} kg error at 30% of the batch vs {fmtInt(c30.models.naive_mean!.mae)} kg naive.
          </p>
        )}
      </HelpCard>
      <HelpCard icon={<ShieldAlert size={16} />} kpi="KPI 2 + 3 · Faults, few false alarms" title="Catch drift and contamination">
        <ul className="list-disc space-y-1 pl-4">
          {p.kairos.fault_signatures.map((f) => (
            <li key={f}>{f}</li>
          ))}
        </ul>
        {k && (
          <p className="text-xs text-text-muted">
            On the benchmark: {k.detected}/{k.n_fault_batches} faults caught, {fmt(k.false_alarms_per_batch, 1)} false alarms per batch.
          </p>
        )}
      </HelpCard>
      <HelpCard icon={<Zap size={16} />} kpi="KPI 4 · Energy vs oxygen" title="Use less energy and feedstock">
        <ul className="list-disc space-y-1 pl-4">
          {p.kairos.energy_levers.map((e) => (
            <li key={e}>{e}</li>
          ))}
        </ul>
        {m?.energy && (
          <p className="text-xs text-text-muted">
            On the benchmark: {fmt(m.energy.mean_saving_pct, 0)}% less agitation + aeration energy at a safe oxygen level.
          </p>
        )}
      </HelpCard>
    </div>
  );
}

export default function ProcessPage() {
  const list = useProcesses();
  const current = useSelectedProcess();
  const [params] = useSearchParams();
  const select = useProcessStore((s) => s.select);
  const wanted = params.get("process");
  useEffect(() => {
    if (wanted) select(wanted); // deep link, e.g. /process?process=whey
  }, [wanted, select]);
  const detail = useProcess(current?.id ?? null);

  if (list.isLoading || (current && detail.isLoading))
    return (
      <div className="space-y-4 p-8">
        <Skeleton className="h-24" />
        <Skeleton className="h-[28rem]" />
      </div>
    );
  if (list.isError) return <ErrorState title="Could not load the process library" onRetry={() => void list.refetch()} />;
  if (!current) return <EmptyState title="The process library is empty" message="Add processes to backend/app/processes/catalog.yaml." />;
  if (detail.isError || !detail.data) return <ErrorState title="Could not load this process" onRetry={() => void detail.refetch()} />;
  const p = detail.data;

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto max-w-7xl space-y-6 p-8">
        <Gallery list={list.data!.processes} current={p.id} />
        <Hero p={p} />

        <div className="grid grid-cols-[minmax(0,2fr)_minmax(0,1fr)] gap-5">
          <Panel className="p-5">
            <div className="flex items-baseline justify-between">
              <h2 className="text-lg font-medium">{REACTOR_LABEL[p.reactor] ?? "Fermenter"} and its control environment</h2>
              <span className="text-xs text-text-muted">Schematic · values are typical ranges</span>
            </div>
            {p.reactor_note && <p className="mt-0.5 text-sm text-text-secondary">{p.reactor_note}</p>}
            <div className="mt-3">
              <FermenterDiagram process={p} />
            </div>
          </Panel>
          <div className="space-y-5">
            <Panel className="p-5">
              <h2 className="flex items-center gap-2 text-lg font-medium">
                <GaugeIcon size={17} /> Control loops
              </h2>
              <ul className="mt-2 space-y-2.5">
                {p.control_loops.map((c) => (
                  <li key={c.measure + c.actuator} className="text-sm">
                    <div className="flex items-center gap-1.5 font-medium">
                      {c.measure} <ArrowRight size={13} className="text-text-muted" /> {c.actuator}
                    </div>
                    <div className="text-xs text-text-secondary">{c.purpose}</div>
                  </li>
                ))}
              </ul>
            </Panel>
            <Panel className="p-5">
              <h2 className="text-lg font-medium">Typical setpoints</h2>
              <Setpoints p={p} />
            </Panel>
          </div>
        </div>

        <section>
          <h2 className="mb-3 text-lg font-medium">From inoculation to harvest</h2>
          <Phases p={p} />
        </section>

        <section>
          <h2 className="mb-3 text-lg font-medium">How Kairos makes this process more efficient</h2>
          <HowKairosHelps p={p} />
        </section>

        <div className="grid grid-cols-2 gap-5">
          <Panel className="p-5">
            <h2 className="text-lg font-medium">What can go wrong</h2>
            <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-text-secondary">
              {p.critical_risks.map((r) => (
                <li key={r}>{r}</li>
              ))}
            </ul>
          </Panel>
          <Panel className="p-5">
            <h2 className="text-lg font-medium">Where the energy goes</h2>
            <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-text-secondary">
              {p.energy_hotspots.map((r) => (
                <li key={r}>{r}</li>
              ))}
            </ul>
          </Panel>
        </div>

        <Panel className="p-5">
          <h2 className="text-lg font-medium">Sources</h2>
          <ul className="mt-2 space-y-1 text-sm">
            {p.sources.map((s) => (
              <li key={s.url}>
                <a href={s.url} target="_blank" rel="noreferrer" className="text-accent-500 hover:underline">
                  {s.title}
                </a>
              </li>
            ))}
          </ul>
          <p className="mt-3 text-xs text-text-muted">
            Live reactors replay the IndPenSim penicillin benchmark (synthetic). Setpoints of proprietary processes are typical
            published ranges, not company values.
          </p>
        </Panel>
      </div>
    </div>
  );
}
