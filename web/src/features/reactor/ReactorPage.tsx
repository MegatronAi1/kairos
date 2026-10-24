import { AnimatePresence, motion } from "framer-motion";
import { ArrowLeft, CheckCircle2, ChevronUp, Sparkles } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { Link, useParams } from "react-router-dom";

import { Chat } from "@/components/Chat";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { EmptyState, ProvenanceChip, Skeleton, StatusPill } from "@/components/primitives";
import { InsightCardView, PonrCountdown, Sparkline } from "@/components/readouts";
import { TimelineScrubber } from "@/components/Timeline";
import { EnergyPanel, ForecastFan, Gauge, HealthRing } from "@/components/viz";
import { api } from "@/lib/api/client";
import { fmt, fmtInt, stateVar, strategyLabel, valueOf } from "@/lib/format";
import { statusSentence } from "@/lib/narrate";
import { useProcessStore } from "@/lib/process";
import { useLive } from "@/lib/store/live";
import { ReactorScene } from "@/three/Stage";

type Detail = "process" | "forecast" | "energy";

/** A live summary tile in the instrument dock; clicking it opens the matching detail view. */
function DockTile({
  label,
  value,
  unit,
  note,
  tone,
  history,
  active,
  onClick,
}: {
  label: string;
  value: string;
  unit?: string;
  note: string;
  tone?: string;
  history: number[];
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      aria-pressed={active}
      className="group flex min-w-0 flex-col rounded-card border p-3 text-left transition-colors hover:border-border-strong"
      style={{
        borderColor: active ? "var(--color-accent-500)" : undefined,
        background: active ? "color-mix(in srgb, var(--color-accent-500) 7%, var(--color-bg-surface))" : "var(--color-bg-surface)",
      }}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="truncate text-xs font-medium text-text-secondary">{label}</span>
        <ChevronUp size={14} className={`shrink-0 text-text-muted transition-transform ${active ? "" : "rotate-180"}`} aria-hidden />
      </div>
      <div className="mt-1 flex items-end justify-between gap-2">
        <div className="min-w-0 whitespace-nowrap">
          <span className="display-num text-2xl font-semibold" style={{ color: tone }}>
            {value}
          </span>
          {unit && <span className="ml-1 text-xs text-text-muted">{unit}</span>}
        </div>
        <Sparkline values={history} color={tone ?? "var(--color-accent-500)"} width={64} height={24} />
      </div>
      <span className="mt-1 truncate text-[11px] text-text-muted">{note}</span>
    </button>
  );
}

function Quick({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-control bg-bg-inset px-3 py-2">
      <div className="text-[11px] text-text-muted">{label}</div>
      <div className="display-num text-sm font-semibold">{value}</div>
    </div>
  );
}

export default function ReactorPage() {
  const { id = "", plantId = "" } = useParams();
  const r = useLive((s) => s.reactors[id]);
  const status = useLive((s) => s.status);
  const patch = useLive((s) => s.patch);
  const [detail, setDetail] = useState<Detail | null>(null);
  const detailRef = useRef<HTMLDivElement>(null);
  const plants = useQuery({ queryKey: ["plants"], queryFn: api.plants });
  const selectProcess = useProcessStore((s) => s.select);
  const plantProcess = plants.data?.find((p) => p.id === (plantId || r?.plantId))?.process_id;
  useEffect(() => {
    if (plantProcess) selectProcess(plantProcess); // deep links keep the right process context
  }, [plantProcess, selectProcess]);

  if (!r) {
    return status === "live" ? (
      <EmptyState title={`No reactor ${id}`} action={<Link to="/app" className="text-accent-500">Back to operations</Link>} />
    ) : (
      <Skeleton className="m-6 h-[80vh]" />
    );
  }

  const tick = r.tick ?? null;
  const f = tick?.forecast;
  const h = tick?.health;
  const story = statusSentence(r);
  const lastAlarm = [...r.alarms].reverse().find((a) => a.state === "alarm");
  const ponr = lastAlarm?.ponr_hours ?? null;
  const ponrLeft = ponr !== null && tick && lastAlarm ? Math.max(0, ponr - (tick.t_h - lastAlarm.t_h)) : null;
  const hist = (k: string) => r.history.slice(-90).map((t) => valueOf(t, k) ?? NaN);
  const contributors = [...(h?.top_contributors.map((c) => c.var) ?? []), ...(lastAlarm?.contributors.map((c) => c.var) ?? [])];
  const hot = (k: string) => (r.state !== "normal" && contributors.includes(k) ? stateVar[r.state] : undefined);
  const oxygenAlarm = r.state !== "normal" && contributors.some((c) => ["do_pct", "o2_offgas_pct", "co2_offgas_pct", "our", "cer"].includes(c));
  const doPct = valueOf(tick, "do_pct");

  const open = (d: Detail) => {
    setDetail((cur) => (cur === d ? null : d));
    requestAnimationFrame(() => detailRef.current?.scrollIntoView({ behavior: "smooth", block: "nearest" }));
  };

  return (
    <div className="h-full overflow-y-auto">
      <div className="flex flex-col gap-4 p-4 xl:flex-row xl:items-start">
        <div className="flex min-w-0 flex-1 flex-col gap-4">
          {/* Header strip: identity, state, one sentence, the one action */}
          <section className="flex flex-wrap items-center gap-4 rounded-card border border-border-subtle bg-bg-surface px-4 py-3">
            <Link
              to={`/app/plants/${plantId || r.plantId}`}
              aria-label="Back to plant"
              className="rounded-control p-1.5 text-text-secondary hover:bg-bg-elevated hover:text-text-primary"
            >
              <ArrowLeft size={18} />
            </Link>
            <HealthRing score={h?.score ?? null} state={h?.state ?? r.state} size={52} />
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-x-3 gap-y-1">
                <h1 className="display-num text-2xl font-semibold tracking-tight">{r.id}</h1>
                <StatusPill state={r.state} />
                <span className="text-xs text-text-muted">
                  Batch {r.batchId} · {strategyLabel(r.strategy)} · {fmt(tick?.t_h, 1)} h
                </span>
              </div>
              <p className="mt-0.5 text-sm">
                <span className="font-semibold" style={{ color: r.state === "normal" ? undefined : stateVar[r.state] }}>
                  {story.headline}.
                </span>{" "}
                <span className="text-text-secondary">{story.detail}</span>
              </p>
            </div>
            {r.state === "alarm" && !r.acknowledged ? (
              <button
                onClick={() => {
                  patch(r.id, { acknowledged: true });
                  void api.ack(r.id);
                }}
                className="rounded-control px-4 py-2 text-sm font-semibold text-white"
                style={{ background: "var(--color-state-alarm)" }}
              >
                Acknowledge alarm
              </button>
            ) : r.acknowledged && r.state !== "normal" ? (
              <span className="flex items-center gap-1.5 text-xs text-text-secondary">
                <CheckCircle2 size={14} /> Acknowledged
              </span>
            ) : null}
          </section>

          {/* Hero stage: nothing sits on the reactor */}
          <section className="relative h-[46vh] min-h-[340px] overflow-hidden rounded-card border border-border-subtle xl:h-[52vh]">
            <ErrorBoundary title="3D view unavailable">
              <ReactorScene tick={tick} state={r.state} />
            </ErrorBoundary>
            <span className="pointer-events-none absolute bottom-3 right-4 text-[11px] text-text-muted">Drag to orbit · hover parts for live values</span>
          </section>

          {/* Instrument dock: live tiles, each opens its detail view below */}
          <section className="space-y-3">
            <div className="grid grid-cols-2 gap-3 md:grid-cols-3 2xl:grid-cols-5">
              <DockTile
                label="Dissolved oxygen"
                value={fmt(doPct, 0)}
                unit="% sat"
                note={doPct !== null && doPct < 35 ? "below the safety target" : "oxygen supply is healthy"}
                tone={hot("do_pct") ?? (doPct !== null && doPct < 25 ? "var(--color-state-alarm)" : undefined)}
                history={hist("do_pct")}
                active={detail === "process"}
                onClick={() => open("process")}
              />
              <DockTile
                label="pH"
                value={fmt(valueOf(tick, "ph"), 2)}
                note="held by base dosing"
                tone={hot("ph")}
                history={hist("ph")}
                active={detail === "process"}
                onClick={() => open("process")}
              />
              <DockTile
                label="Temperature"
                value={fmt(valueOf(tick, "temp_c"), 2)}
                unit="°C"
                note="jacket cooling"
                tone={hot("temp_c")}
                history={hist("temp_c")}
                active={detail === "process"}
                onClick={() => open("process")}
              />
              <DockTile
                label="Final yield forecast"
                value={f ? fmtInt(f.p50) : "—"}
                unit={f?.unit}
                note={f ? `${Math.round(f.vs_golden_pct)}% of a typical batch` : "starts at ~8% of the batch"}
                history={r.history.slice(-90).map((t) => t.forecast?.p50 ?? NaN)}
                active={detail === "forecast"}
                onClick={() => open("forecast")}
              />
              <DockTile
                label={oxygenAlarm ? "Oxygen rescue" : "Agitation + aeration"}
                value={fmtInt(valueOf(tick, "power_kw"))}
                unit="kW"
                note={oxygenAlarm ? "see the rescue setting" : "tap for the energy-saving setting"}
                history={hist("power_kw")}
                active={detail === "energy"}
                onClick={() => open("energy")}
              />
            </div>

            <AnimatePresence initial={false}>
              {detail && (
                <motion.div
                  ref={detailRef}
                  key="detail"
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: "auto" }}
                  exit={{ opacity: 0, height: 0 }}
                  transition={{ duration: 0.22, ease: [0.2, 0.8, 0.2, 1] }}
                  className="overflow-hidden"
                >
                  <div className="rounded-card border border-border-subtle bg-bg-surface p-5">
                    <div className="mb-4 flex items-center gap-1 rounded-control bg-bg-inset p-1 text-sm" role="tablist">
                      {(
                        [
                          ["process", "Process"],
                          ["forecast", "Yield forecast"],
                          ["energy", oxygenAlarm ? "Oxygen rescue" : "Energy vs oxygen"],
                        ] as [Detail, string][]
                      ).map(([d, label]) => (
                        <button
                          key={d}
                          role="tab"
                          aria-selected={detail === d}
                          onClick={() => setDetail(d)}
                          className={`flex-1 rounded-[5px] px-3 py-1.5 font-medium ${detail === d ? "bg-bg-surface text-text-primary shadow-sm" : "text-text-secondary hover:text-text-primary"}`}
                        >
                          {label}
                        </button>
                      ))}
                    </div>

                    {detail === "process" && (
                      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_260px]">
                        <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
                          <Gauge label="Dissolved oxygen" unit="% sat" value={doPct} min={0} max={120} band={[45, 110]} warnBelow={25} history={hist("do_pct")} />
                          <Gauge label="pH" unit="" value={valueOf(tick, "ph")} min={5.8} max={7.2} band={[6.3, 6.7]} decimals={2} history={hist("ph")} />
                          <Gauge label="Temperature" unit="°C" value={valueOf(tick, "temp_c")} min={23} max={27} band={[24.6, 25.4]} decimals={2} history={hist("temp_c")} />
                          <Gauge label="Off-gas O₂" unit="%" value={valueOf(tick, "o2_offgas_pct")} min={12} max={22} band={[18.5, 20.5]} history={hist("o2_offgas_pct")} />
                        </div>
                        <div className="grid grid-cols-2 gap-2 self-center">
                          <Quick label="Sugar feed" value={`${fmtInt(valueOf(tick, "feed"))} L/h`} />
                          <Quick label="Aeration" value={`${fmtInt(valueOf(tick, "aeration"))} m³/min`} />
                          <Quick label="Agitation" value={`${fmtInt(valueOf(tick, "rpm"))} rpm`} />
                          <Quick label="Oxygen uptake" value={`${fmt(valueOf(tick, "our"), 2)} mg/L/h`} />
                        </div>
                      </div>
                    )}

                    {detail === "forecast" &&
                      (f ? (
                        <div className="grid gap-6 lg:grid-cols-[260px_minmax(0,1fr)]">
                          <div>
                            <div className="flex items-center gap-2">
                              <span className="display-num text-4xl font-semibold">{fmtInt(f.p50)}</span>
                              <span className="text-sm text-text-muted">{f.unit}</span>
                              <ProvenanceChip provenance={f.provenance} source="model estimate on held-out IndPenSim data; 80% interval" />
                            </div>
                            <p className="mt-1 text-sm text-text-secondary">
                              Likely between {fmtInt(f.p10)} and {fmtInt(f.p90)} {f.unit}, {Math.round(f.vs_golden_pct)}% of a typical batch.
                              The band narrows as the batch matures and widens once a fault is flagged.
                            </p>
                          </div>
                          <ForecastFan reactorId={r.id} ticks={r.history} height={170} />
                        </div>
                      ) : (
                        <p className="text-sm text-text-muted">The forecast starts once about 8% of the batch has run.</p>
                      ))}

                    {detail === "energy" && (
                      <ErrorBoundary title="Energy panel unavailable">
                        <EnergyPanel reactorId={r.id} tick={tick} mode={oxygenAlarm ? "rescue" : "energy"} layout="row" />
                      </ErrorBoundary>
                    )}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            <div className="rounded-card border border-border-subtle bg-bg-surface px-4 py-3">
              <TimelineScrubber r={r} />
            </div>
          </section>
        </div>

        {/* Copilot: the product's voice, visually set apart */}
        <aside className="copilot-rail flex min-h-[600px] flex-col overflow-hidden rounded-card border xl:sticky xl:top-4 xl:h-[calc(100vh-56px-32px)] xl:w-[380px] xl:shrink-0">
          <div className="flex items-center gap-2.5 px-5 pb-3 pt-4">
            <span className="flex h-8 w-8 items-center justify-center rounded-control" style={{ background: "var(--color-accent-500)", color: "var(--color-bg-base)" }}>
              <Sparkles size={16} />
            </span>
            <div>
              <h2 className="display text-base font-semibold leading-tight">Kairos Copilot</h2>
              <p className="text-[11px] text-text-muted">Claude, grounded in Kairos models</p>
            </div>
          </div>
          <div className="max-h-[55%] shrink-0 space-y-4 overflow-y-auto px-5 pb-4">
            {ponrLeft !== null && ponr !== null && <PonrCountdown remainingH={ponrLeft} totalH={ponr} size={140} />}
            {r.insight && r.state !== "normal" ? (
              <InsightCardView insight={r.insight} state={r.state} />
            ) : (
              <div className="rounded-card border border-border-subtle bg-bg-surface p-4">
                <div className="text-sm font-semibold">All clear</div>
                <p className="mt-1 text-sm text-text-secondary">
                  Nothing needs your attention. Kairos compares every signal with how healthy batches looked at this same hour, and
                  will page the operator the moment that changes.
                </p>
              </div>
            )}
          </div>
          <div className="min-h-0 flex-1 border-t border-border-subtle px-5 py-4">
            <ErrorBoundary title="Copilot chat unavailable">
              <Chat
                reactorId={r.id}
                suggestions={[
                  `Why is ${r.id} drifting and what should I do?`,
                  `How much energy can ${r.id} save without risking oxygen?`,
                  "How accurate are your models on held-out batches?",
                ]}
              />
            </ErrorBoundary>
          </div>
        </aside>
      </div>
    </div>
  );
}
