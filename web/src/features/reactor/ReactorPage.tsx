import { ArrowLeft, CheckCircle2 } from "lucide-react";
import { Link, useParams } from "react-router-dom";

import { Chat } from "@/components/Chat";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { EmptyState, Panel, ProvenanceChip, Skeleton, StatusPill } from "@/components/primitives";
import { InsightCardView, MetricReadout, PonrCountdown } from "@/components/readouts";
import { TimelineScrubber } from "@/components/Timeline";
import { EnergyPanel, ForecastFan, Gauge, HealthRing } from "@/components/viz";
import { api } from "@/lib/api/client";
import type { HealthState } from "@/lib/api/types";
import { fmtInt, SENSORS, stateVar, strategyLabel, valueOf } from "@/lib/format";
import { statusSentence } from "@/lib/narrate";
import { useLive } from "@/lib/store/live";
import { ReactorScene } from "@/three/Stage";

const VITALS = ["feed", "aeration", "rpm", "our", "power_kw", "kwh_cum"];

export default function ReactorPage() {
  const { id = "" } = useParams();
  const r = useLive((s) => s.reactors[id]);
  const status = useLive((s) => s.status);
  const patch = useLive((s) => s.patch);

  if (!r) {
    return status === "live" ? (
      <EmptyState title={`No reactor ${id}`} action={<Link to="/" className="text-accent-500">Back to fleet</Link>} />
    ) : (
      <Skeleton className="m-6 h-[80vh]" />
    );
  }

  const tick = r.tick;
  const f = tick?.forecast;
  const h = tick?.health;
  const story = statusSentence(r);
  const lastAlarm = [...r.alarms].reverse().find((a) => a.state === "alarm");
  const ponr = lastAlarm?.ponr_hours ?? null;
  const ponrLeft = ponr !== null && tick && lastAlarm ? Math.max(0, ponr - (tick.t_h - lastAlarm.t_h)) : null;
  const contributors = new Set(h?.top_contributors.map((c) => c.var) ?? []);
  const accentFor = (k: string, state: HealthState) => (state !== "normal" && contributors.has(k) ? stateVar[state] : undefined);
  const hist = (k: string) => r.history.slice(-90).map((t) => valueOf(t, k) ?? NaN);
  const lastCard = r.alarms.length ? r.alarms[r.alarms.length - 1]!.contributors.map((c) => c.var) : [];
  const oxygenAlarm =
    r.state !== "normal" &&
    [...contributors, ...lastCard].some((c) => ["do_pct", "o2_offgas_pct", "co2_offgas_pct", "our", "cer"].includes(c));

  return (
    <div className="grid h-full grid-cols-[320px_minmax(0,1fr)_380px] grid-rows-[auto_minmax(0,1fr)_auto] gap-4 p-4">
      {/* Header: who, and how it is doing, in a sentence */}
      <Panel className="col-span-3 flex items-center gap-5 px-5 py-3">
        <Link to="/" aria-label="Back to fleet" className="rounded-control p-1.5 text-text-secondary hover:bg-bg-elevated hover:text-text-primary">
          <ArrowLeft size={18} />
        </Link>
        <HealthRing score={h?.score ?? null} state={h?.state ?? r.state} size={56} />
        <div className="min-w-0">
          <div className="flex items-center gap-3">
            <h1 className="display-num text-3xl font-semibold">{r.id}</h1>
            <StatusPill state={r.state} />
            <span className="text-sm text-text-muted">
              Batch {r.batchId} · {strategyLabel(r.strategy)}
            </span>
          </div>
          <p className="truncate text-lg">
            <span className="font-medium" style={{ color: r.state === "normal" ? undefined : stateVar[r.state] }}>
              {story.headline}.
            </span>{" "}
            <span className="text-text-secondary">{story.detail}</span>
          </p>
        </div>
        <div className="ml-auto flex shrink-0 items-center gap-3">
          {r.acknowledged && r.state !== "normal" && (
            <span className="flex items-center gap-1.5 text-sm text-text-secondary">
              <CheckCircle2 size={15} /> Acknowledged by operator
            </span>
          )}
          {r.state === "alarm" && !r.acknowledged && (
            <button
              onClick={() => {
                patch(r.id, { acknowledged: true });
                void api.ack(r.id);
              }}
              className="rounded-control px-4 py-2 text-sm font-medium text-white"
              style={{ background: "var(--color-state-alarm)" }}
            >
              Acknowledge alarm
            </button>
          )}
        </div>
      </Panel>

      {/* Left rail: gauges, forecast fan, settings */}
      <Panel className="overflow-y-auto px-4 py-4">
        <h2 className="text-base font-medium">Process at a glance</h2>
        <div className="mt-2 grid grid-cols-2 gap-x-2 gap-y-3">
          <Gauge label="Dissolved oxygen" unit="% sat" value={valueOf(tick ?? null, "do_pct")} min={0} max={120} band={[45, 110]} warnBelow={25} history={hist("do_pct")} />
          <Gauge label="pH" unit="" value={valueOf(tick ?? null, "ph")} min={5.8} max={7.2} band={[6.3, 6.7]} decimals={2} history={hist("ph")} />
          <Gauge label="Temperature" unit="°C" value={valueOf(tick ?? null, "temp_c")} min={23} max={27} band={[24.6, 25.4]} decimals={2} history={hist("temp_c")} />
          <Gauge label="Off-gas O₂" unit="%" value={valueOf(tick ?? null, "o2_offgas_pct")} min={12} max={22} band={[18.5, 20.5]} history={hist("o2_offgas_pct")} />
        </div>

        <div className="mt-5 flex items-center justify-between">
          <h2 className="text-base font-medium">Where the batch is heading</h2>
          {f && <ProvenanceChip provenance={f.provenance} source="model estimate trained on the IndPenSim simulator; 80% interval" />}
        </div>
        {f ? (
          <>
            <p className="mt-1 text-sm text-text-secondary">
              Final yield{" "}
              <span className="display-num text-lg font-semibold text-text-primary">
                {fmtInt(f.p50)} {f.unit}
              </span>
              , likely between {fmtInt(f.p10)} and {fmtInt(f.p90)} ({Math.round(f.vs_golden_pct)}% of a typical batch).
            </p>
            <div className="mt-2">
              <ForecastFan reactorId={r.id} ticks={r.history} />
            </div>
          </>
        ) : (
          <p className="mt-1 text-sm text-text-muted">The forecast starts once about 8% of the batch has run.</p>
        )}

        <h2 className="mt-5 text-base font-medium">Settings and energy</h2>
        <div className="divide-y divide-border-subtle">
          {VITALS.map((k) => {
            const meta = SENSORS[k]!;
            return (
              <MetricReadout
                key={k}
                label={meta.label}
                value={valueOf(tick ?? null, k)}
                unit={meta.unit}
                decimals={meta.decimals}
                provenance={meta.provenance}
                source={meta.provenance === "assumed" ? "physics correlation with assumed geometry and efficiencies" : "IndPenSim simulator"}
                history={hist(k)}
                accent={accentFor(k, r.state)}
              />
            );
          })}
        </div>
      </Panel>

      {/* Centre: the twin above the oxygen/energy trade-off */}
      <div className="grid min-h-0 grid-rows-[minmax(0,1fr)_auto] gap-4">
        <div className="relative min-h-0 overflow-hidden rounded-card border border-border-subtle">
          <ErrorBoundary title="3D view unavailable">
            <ReactorScene tick={tick ?? null} state={r.state} />
          </ErrorBoundary>
          {h && r.state === "alarm" && h.state !== "alarm" && (
            <div className="pointer-events-none absolute left-4 top-4 max-w-[15rem] rounded-control border border-border-subtle bg-bg-surface px-3 py-2 text-xs text-text-secondary">
              The detector reads {h.state} now; the alarm stays latched until someone acknowledges it.
            </div>
          )}
          <p className="pointer-events-none absolute bottom-3 right-4 text-xs text-text-muted">
            Hover the impeller, broth, sparger or oxygen ring · drag to orbit
          </p>
        </div>
        <Panel className="px-5 py-4">
          <div className="mb-2 flex items-baseline justify-between">
            <h2 className="text-base font-medium">{oxygenAlarm ? "Get the oxygen back" : "Oxygen transfer vs energy"}</h2>
            <span className="text-xs text-text-muted">Agitation and aeration are the big electricity users</span>
          </div>
          <ErrorBoundary title="Energy panel unavailable">
            <EnergyPanel reactorId={r.id} tick={tick ?? null} mode={oxygenAlarm ? "rescue" : "energy"} />
          </ErrorBoundary>
        </Panel>
      </div>

      {/* Right rail: copilot */}
      <Panel className="flex min-h-0 flex-col gap-4 overflow-hidden p-4">
        <h2 className="text-base font-medium">Copilot</h2>
        <div className="max-h-[55%] shrink-0 space-y-4 overflow-y-auto">
          {ponrLeft !== null && ponr !== null && <PonrCountdown remainingH={ponrLeft} totalH={ponr} size={150} />}
          {r.insight && r.state !== "normal" ? (
            <InsightCardView insight={r.insight} state={r.state} />
          ) : (
            <p className="text-sm text-text-secondary">
              Nothing needs your attention. Kairos compares every signal with how healthy batches looked at this same hour.
            </p>
          )}
        </div>
        <div className="min-h-0 flex-1 border-t border-border-subtle pt-3">
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
      </Panel>

      {/* Bottom: flight recorder */}
      <Panel className="col-span-3 px-4 py-3">
        <TimelineScrubber r={r} />
      </Panel>
    </div>
  );
}
