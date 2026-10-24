import { ArrowLeft, CheckCircle2 } from "lucide-react";
import { Link, useParams } from "react-router-dom";

import { Chat } from "@/components/Chat";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { EmptyState, Panel, Skeleton, StatusPill } from "@/components/primitives";
import { InsightCardView, MetricReadout, PonrCountdown } from "@/components/readouts";
import { TimelineScrubber } from "@/components/Timeline";
import { api } from "@/lib/api/client";
import type { HealthState } from "@/lib/api/types";
import { SENSORS, strategyLabel, stateVar, unitDecimals, valueOf } from "@/lib/format";
import { useLive } from "@/lib/store/live";
import { ReactorScene } from "@/three/Stage";

const VITALS = ["do_pct", "ph", "temp_c", "rpm", "aeration", "feed", "our", "power_kw", "kwh_cum"];

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
  const lastAlarm = [...r.alarms].reverse().find((a) => a.state === "alarm");
  const ponr = lastAlarm?.ponr_hours ?? null;
  const ponrLeft = ponr !== null && tick && lastAlarm ? Math.max(0, ponr - (tick.t_h - lastAlarm.t_h)) : null;
  const contributors = new Set(h?.top_contributors.map((c) => c.var) ?? []);
  const accentFor = (k: string, state: HealthState) => (state !== "normal" && contributors.has(k) ? stateVar[state] : undefined);

  return (
    <div className="grid h-full grid-cols-[300px_minmax(0,1fr)_380px] grid-rows-[minmax(0,1fr)_auto] gap-4 p-4">
      {/* Left rail: vitals */}
      <Panel className="row-span-1 overflow-y-auto px-4 py-3">
        <Link to="/" className="mb-2 inline-flex items-center gap-1 text-sm text-text-secondary hover:text-text-primary">
          <ArrowLeft size={14} /> Fleet
        </Link>
        <div className="flex items-center justify-between">
          <h1 className="num text-2xl font-semibold">{r.id}</h1>
          <StatusPill state={r.state} />
        </div>
        <p className="text-sm text-text-muted">
          Batch {r.batchId} · {strategyLabel(r.strategy)}
        </p>
        {r.acknowledged && r.state !== "normal" && (
          <p className="mt-2 flex items-center gap-1.5 text-sm text-text-secondary">
            <CheckCircle2 size={14} /> Acknowledged by operator
          </p>
        )}
        <div className="mt-3 border-t border-border-subtle pt-1">
          <div className="overline mt-2">Final yield forecast</div>
          {f ? (
            <MetricReadout
              label={`${Math.round(f.vs_golden_pct)}% of a typical batch`}
              value={f.p50}
              unit={f.unit}
              decimals={unitDecimals(f.unit)}
              range={[f.p10, f.p90]}
              provenance={f.provenance}
              source="model estimate trained on the IndPenSim simulator; 80% interval"
              history={r.history.map((t) => t.forecast?.p50 ?? NaN)}
              large
            />
          ) : (
            <p className="py-3 text-sm text-text-muted">Forecast starts after ~8% of the batch.</p>
          )}
        </div>
        <div className="overline mt-3">Vitals</div>
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
                history={r.history.slice(-90).map((t) => valueOf(t, k) ?? NaN)}
                accent={accentFor(k, r.state)}
              />
            );
          })}
        </div>
      </Panel>

      {/* Centre: the twin */}
      <div className="relative min-h-0 overflow-hidden rounded-card border border-border-subtle">
        <ErrorBoundary title="3D view unavailable">
          <ReactorScene tick={tick ?? null} state={r.state} />
        </ErrorBoundary>
        {h && (
          <div className="pointer-events-none absolute left-4 top-4 rounded-control border border-border-subtle bg-bg-surface px-3 py-2">
            <div className="overline">Health</div>
            <div className="num text-2xl font-semibold" style={{ color: stateVar[h.state] }}>
              {Math.round(h.score)}
            </div>
            {r.state === "alarm" && h.state !== "alarm" && (
              <div className="mt-0.5 max-w-[11rem] text-xs text-text-secondary">
                Detector reads {h.state === "normal" ? "normal" : "watch"} now. Alarm stays latched until acknowledged.
              </div>
            )}
          </div>
        )}
        <p className="pointer-events-none absolute bottom-3 right-4 text-xs text-text-muted">
          Hover the impeller, broth, sparger or DO ring · drag to orbit
        </p>
      </div>

      {/* Right rail: copilot */}
      <Panel className="flex min-h-0 flex-col gap-4 overflow-hidden p-4">
        <div className="flex items-center justify-between">
          <span className="overline">Copilot</span>
          {r.state === "alarm" && !r.acknowledged && (
            <button
              onClick={() => {
                patch(r.id, { acknowledged: true });
                void api.ack(r.id);
              }}
              className="rounded-control px-3 py-1 text-sm font-medium text-bg-base"
              style={{ background: "var(--color-state-alarm)" }}
            >
              Acknowledge
            </button>
          )}
        </div>
        <div className="max-h-[55%] shrink-0 space-y-4 overflow-y-auto">
          {ponrLeft !== null && ponr !== null && <PonrCountdown remainingH={ponrLeft} totalH={ponr} size={150} />}
          {r.insight && r.state !== "normal" ? (
            <InsightCardView insight={r.insight} state={r.state} />
          ) : (
            <p className="text-sm text-text-secondary">
              No active issues. Kairos is watching {VITALS.length} signals against normal batches.
            </p>
          )}
        </div>
        <div className="min-h-0 flex-1 border-t border-border-subtle pt-3">
          <ErrorBoundary title="Copilot chat unavailable">
          <Chat
            reactorId={r.id}
            suggestions={[
              `Why is ${r.id} drifting and what should I do?`,
              `How confident is the yield forecast for ${r.id}?`,
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
