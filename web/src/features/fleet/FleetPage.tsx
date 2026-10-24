import { Link, useNavigate } from "react-router-dom";

import { ErrorState, Skeleton, StatusPill } from "@/components/primitives";
import { HealthRing } from "@/components/viz";
import { statusSentence } from "@/lib/narrate";
import { FAMILY_LABEL, FIT_LABEL, useSelectedProcess } from "@/lib/process";
import { fmt, fmtInt, stateVar, strategyLabel, valueOf } from "@/lib/format";
import { sortedReactors, useLive } from "@/lib/store/live";
import { FleetScene } from "@/three/Stage";

export function FleetPage() {
  const navigate = useNavigate();
  const status = useLive((s) => s.status);
  const reactors = sortedReactors(useLive((s) => s.reactors));

  if (reactors.length === 0) {
    return status === "offline" ? (
      <ErrorState title="Cannot reach the Kairos server" message="Retrying automatically. Is the backend running on port 8000?" />
    ) : (
      <div className="grid h-full grid-cols-4 gap-6 p-8">
        {[0, 1, 2, 3].map((i) => (
          <Skeleton key={i} className="h-full" />
        ))}
      </div>
    );
  }

  return (
    <div className="relative h-full">
      <h1 className="sr-only">Fleet</h1>
      <ProcessBanner />
      <div className="absolute inset-0">
        <FleetScene reactors={reactors} onSelect={(id) => navigate(`/reactor/${id}`)} />
      </div>
      {/* Accessible summary strip (also the keyboard path into each reactor) */}
      <div className="pointer-events-none absolute inset-x-0 bottom-0 flex justify-center gap-3 p-5">
        {reactors.map((r) => {
          const f = r.tick?.forecast;
          return (
            <button
              key={r.id}
              onClick={() => navigate(`/reactor/${r.id}`)}
              className="pointer-events-auto w-64 rounded-card border p-3 text-left backdrop-blur hover:border-border-strong"
              style={{
                background: "color-mix(in srgb, var(--color-bg-surface) 88%, transparent)",
                borderColor: r.state === "normal" ? "var(--color-border-subtle)" : stateVar[r.state],
              }}
              aria-label={`Open reactor ${r.id}`}
            >
              <div className="flex items-center gap-3">
                <HealthRing score={r.tick?.health?.score ?? null} state={r.tick?.health?.state ?? r.state} size={48} />
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="display-num text-xl font-semibold">{r.id}</span>
                    <StatusPill state={r.state} compact />
                  </div>
                  <div className="truncate text-xs text-text-muted">
                    Batch {r.batchId} · {strategyLabel(r.strategy)}
                  </div>
                </div>
              </div>
              <p
                className="mt-2 line-clamp-1 text-sm font-medium"
                style={{ color: r.state === "normal" ? undefined : stateVar[r.state] }}
              >
                {statusSentence(r).headline}
              </p>
              <p className="line-clamp-2 text-xs text-text-secondary">{statusSentence(r).detail}</p>
              <div className="mt-2 flex justify-between border-t border-border-subtle pt-2 text-xs text-text-secondary">
                <span>
                  Forecast <span className="num text-text-primary">{f ? `${fmtInt(f.p50)} ${f.unit}` : "—"}</span>
                </span>
                <span>
                  DO <span className="num text-text-primary">{fmt(valueOf(r.tick, "do_pct"), 0)}%</span>
                </span>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function ProcessBanner() {
  const p = useSelectedProcess();
  if (!p) return null;
  return (
    <Link
      to="/process"
      className="absolute left-5 top-5 z-10 max-w-md rounded-card border border-border-subtle p-4 backdrop-blur hover:border-border-strong"
      style={{ background: "color-mix(in srgb, var(--color-bg-surface) 85%, transparent)" }}
    >
      <div className="overline">{FAMILY_LABEL[p.family]}</div>
      <div className="display mt-0.5 text-2xl font-semibold">{p.name}</div>
      <div className="text-sm text-text-secondary">
        {p.example?.company ? `${p.example.company} · ` : ""}
        <i>{p.organism}</i>
      </div>
      <div className="mt-2 text-xs text-text-muted">
        Reactors replay the IndPenSim fed-batch benchmark · {p.benchmark_fit ? FIT_LABEL[p.benchmark_fit].toLowerCase() : "fit pending"} for this
        process. Open the process view →
      </div>
    </Link>
  );
}
