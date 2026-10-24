import { ArrowLeft, CheckCircle2, Gauge as GaugeIcon, Layers, RotateCcw, Sparkles, TrendingUp, Zap } from "lucide-react";
import { useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";

import { Chat } from "@/components/Chat";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { FloatingPanel } from "@/components/FloatingPanel";
import { EmptyState, ProvenanceChip, Skeleton, StatusPill } from "@/components/primitives";
import { InsightCardView, PonrCountdown } from "@/components/readouts";
import { TimelineScrubber } from "@/components/Timeline";
import { EnergyPanel, ForecastFan, Gauge, HealthRing } from "@/components/viz";
import { api } from "@/lib/api/client";
import { fmt, fmtInt, stateVar, strategyLabel, valueOf } from "@/lib/format";
import { statusSentence } from "@/lib/narrate";
import { useLive } from "@/lib/store/live";
import { useMedia } from "@/lib/useMedia";
import { ReactorScene } from "@/three/Stage";

type LayerId = "vitals" | "forecast" | "energy";
const LAYERS: { id: LayerId; label: string }[] = [
  { id: "vitals", label: "Process gauges" },
  { id: "forecast", label: "Yield forecast" },
  { id: "energy", label: "Energy" },
];

function Quick({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-control bg-bg-inset px-2.5 py-1.5">
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
  const stage = useRef<HTMLDivElement>(null);
  const floating = useMedia("(min-width: 1280px)");
  // On very wide screens every panel opens; otherwise secondary panels start collapsed so the reactor stays visible.
  const roomy = useMedia("(min-width: 1760px)");
  const [layers, setLayers] = useState<Record<LayerId, boolean>>({ vitals: true, forecast: true, energy: true });
  const [resetKey, setResetKey] = useState(0);
  const [menu, setMenu] = useState(false);

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
  const oxygenAlarm = r.state !== "normal" && contributors.some((c) => ["do_pct", "o2_offgas_pct", "co2_offgas_pct", "our", "cer"].includes(c));
  const show = (l: LayerId) => !floating || layers[l];
  const hide = (l: LayerId) => () => setLayers((s) => ({ ...s, [l]: false }));

  const statusCard = (
    <div className={floating ? "glass absolute left-4 top-4 z-10 w-[330px] rounded-card p-4" : "rounded-card border border-border-subtle bg-bg-surface p-4"}>
      <div className="flex items-center gap-3">
        <Link to={`/app/plants/${plantId || r.plantId}`} aria-label="Back to plant" className="rounded-control p-1 text-text-secondary hover:bg-bg-elevated hover:text-text-primary">
          <ArrowLeft size={18} />
        </Link>
        <HealthRing score={h?.score ?? null} state={h?.state ?? r.state} size={52} />
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h1 className="display-num text-2xl font-semibold tracking-tight">{r.id}</h1>
            <StatusPill state={r.state} compact />
          </div>
          <div className="truncate text-xs text-text-muted">
            Batch {r.batchId} · {strategyLabel(r.strategy)} · {fmt(tick?.t_h, 1)} h
          </div>
        </div>
      </div>
      <p className="mt-3 text-sm leading-snug">
        <span className="font-semibold" style={{ color: r.state === "normal" ? undefined : stateVar[r.state] }}>
          {story.headline}.
        </span>{" "}
        <span className="text-text-secondary">{story.detail}</span>
      </p>
      {r.state === "alarm" && h && h.state !== "alarm" && (
        <p className="mt-2 text-xs text-text-muted">Detector reads {h.state} now; the alarm stays latched until acknowledged.</p>
      )}
      {r.state === "alarm" && !r.acknowledged ? (
        <button
          onClick={() => {
            patch(r.id, { acknowledged: true });
            void api.ack(r.id);
          }}
          className="mt-3 w-full rounded-control py-2 text-sm font-semibold text-white"
          style={{ background: "var(--color-state-alarm)" }}
        >
          Acknowledge alarm
        </button>
      ) : r.acknowledged && r.state !== "normal" ? (
        <p className="mt-3 flex items-center gap-1.5 text-xs text-text-secondary">
          <CheckCircle2 size={14} /> Acknowledged by operator
        </p>
      ) : null}
    </div>
  );

  const panels = (
    <>
      {show("vitals") && (
        <FloatingPanel
          title="Process gauges"
          icon={<GaugeIcon size={15} />}
          position={{ left: 16, top: 250 }}
          bounds={stage}
          floating={floating}
          width={280}
          onClose={hide("vitals")}
          resetKey={resetKey}
          defaultOpen={!floating || roomy}
        >
          <div className="grid grid-cols-2 gap-x-1 gap-y-2">
            <Gauge label="Dissolved oxygen" unit="% sat" value={valueOf(tick, "do_pct")} min={0} max={120} band={[45, 110]} warnBelow={25} history={hist("do_pct")} />
            <Gauge label="pH" unit="" value={valueOf(tick, "ph")} min={5.8} max={7.2} band={[6.3, 6.7]} decimals={2} history={hist("ph")} />
            <Gauge label="Temperature" unit="°C" value={valueOf(tick, "temp_c")} min={23} max={27} band={[24.6, 25.4]} decimals={2} history={hist("temp_c")} />
            <Gauge label="Off-gas O₂" unit="%" value={valueOf(tick, "o2_offgas_pct")} min={12} max={22} band={[18.5, 20.5]} history={hist("o2_offgas_pct")} />
          </div>
          <div className="mt-2 grid grid-cols-3 gap-1.5">
            <Quick label="Sugar feed" value={`${fmtInt(valueOf(tick, "feed"))} L/h`} />
            <Quick label="Aeration" value={`${fmtInt(valueOf(tick, "aeration"))} m³/min`} />
            <Quick label="Agitation" value={`${fmtInt(valueOf(tick, "rpm"))} rpm`} />
          </div>
        </FloatingPanel>
      )}
      {show("forecast") && (
        <FloatingPanel
          title="Yield forecast"
          icon={<TrendingUp size={15} />}
          position={{ right: 16, top: 16 }}
          bounds={stage}
          floating={floating}
          width={300}
          onClose={hide("forecast")}
          resetKey={resetKey}
        >
          {f ? (
            <>
              <div className="flex items-baseline justify-between">
                <div>
                  <span className="display-num text-2xl font-semibold">{fmtInt(f.p50)}</span>
                  <span className="ml-1 text-sm text-text-muted">{f.unit} final yield</span>
                </div>
                <ProvenanceChip provenance={f.provenance} source="model estimate on held-out IndPenSim data; 80% interval" />
              </div>
              <div className="text-xs text-text-secondary">
                likely {fmtInt(f.p10)}–{fmtInt(f.p90)} · {Math.round(f.vs_golden_pct)}% of a typical batch
              </div>
              <div className="mt-2">
                <ForecastFan reactorId={r.id} ticks={r.history} />
              </div>
            </>
          ) : (
            <p className="text-sm text-text-muted">The forecast starts once about 8% of the batch has run.</p>
          )}
        </FloatingPanel>
      )}
      {show("energy") && (
        <FloatingPanel
          title={oxygenAlarm ? "Get the oxygen back" : "Oxygen transfer vs energy"}
          icon={<Zap size={15} />}
          position={{ right: 16, bottom: 84 }}
          bounds={stage}
          floating={floating}
          width={330}
          onClose={hide("energy")}
          resetKey={resetKey}
          defaultOpen={!floating || roomy}
        >
          <ErrorBoundary title="Energy panel unavailable">
            <EnergyPanel reactorId={r.id} tick={tick} mode={oxygenAlarm ? "rescue" : "energy"} />
          </ErrorBoundary>
        </FloatingPanel>
      )}
    </>
  );

  return (
    <div className="h-full overflow-y-auto xl:overflow-hidden">
      <div className="flex flex-col gap-4 p-4 xl:h-full xl:flex-row">
        {/* Stage: the twin is the hero; information floats over it */}
        <div className="flex min-w-0 flex-1 flex-col gap-4">
          <div ref={stage} className="relative h-[460px] overflow-hidden rounded-card border border-border-subtle md:h-[560px] xl:h-auto xl:flex-1">
            <ErrorBoundary title="3D view unavailable">
              <ReactorScene tick={tick} state={r.state} />
            </ErrorBoundary>
            {floating && statusCard}
            {floating && panels}
            {floating && (
              <div className="absolute left-1/2 top-4 z-20 -translate-x-1/2">
                <button onClick={() => setMenu((m) => !m)} className="glass flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium" aria-expanded={menu}>
                  <Layers size={14} /> Layers
                </button>
                {menu && (
                  <div className="glass absolute left-1/2 mt-2 w-52 -translate-x-1/2 rounded-card p-1.5">
                    {LAYERS.map((l) => (
                      <label key={l.id} className="flex cursor-pointer items-center gap-2 rounded-control px-2 py-1.5 text-sm hover:bg-bg-elevated">
                        <input
                          type="checkbox"
                          checked={layers[l.id]}
                          onChange={(e) => setLayers((s) => ({ ...s, [l.id]: e.target.checked }))}
                          className="accent-[var(--color-accent-500)]"
                        />
                        {l.label}
                      </label>
                    ))}
                    <button
                      onClick={() => {
                        setLayers({ vitals: true, forecast: true, energy: true });
                        setResetKey((k) => k + 1);
                        setMenu(false);
                      }}
                      className="mt-1 flex w-full items-center gap-2 rounded-control px-2 py-1.5 text-sm text-text-secondary hover:bg-bg-elevated"
                    >
                      <RotateCcw size={13} /> Reset layout
                    </button>
                  </div>
                )}
              </div>
            )}
            {floating && (
              <div className="glass absolute inset-x-4 bottom-4 z-10 rounded-card px-4 py-2.5">
                <TimelineScrubber r={r} />
              </div>
            )}
          </div>
          {!floating && (
            <>
              {statusCard}
              <div className="rounded-card border border-border-subtle bg-bg-surface px-4 py-3">
                <TimelineScrubber r={r} />
              </div>
              <div className="grid gap-4 md:grid-cols-2">{panels}</div>
            </>
          )}
        </div>

        {/* Copilot: the product's voice, visually set apart */}
        <aside className="copilot-rail flex min-h-[560px] flex-col overflow-hidden rounded-card border xl:min-h-0 xl:w-[380px] xl:shrink-0">
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
