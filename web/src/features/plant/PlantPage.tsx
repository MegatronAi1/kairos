import { useQuery } from "@tanstack/react-query";
import { ArrowRight, Dna, Sprout } from "lucide-react";
import { useEffect } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";

import { ErrorBoundary } from "@/components/ErrorBoundary";
import { Page, PageHeader, StatTile } from "@/components/layout";
import { EmptyState, ErrorState, Skeleton, StatusPill } from "@/components/primitives";
import { HealthRing } from "@/components/viz";
import { api } from "@/lib/api/client";
import { fmt, fmtInt, stateVar, strategyLabel, valueOf } from "@/lib/format";
import { statusSentence } from "@/lib/narrate";
import { useProcessStore } from "@/lib/process";
import { useLive, type ReactorLive } from "@/lib/store/live";
import { FleetScene } from "@/three/Stage";

function ReactorCard({ r, plantId }: { r: ReactorLive; plantId: string }) {
  const f = r.tick?.forecast;
  const story = statusSentence(r);
  return (
    <Link
      to={`/app/plants/${plantId}/reactors/${r.id}`}
      className="group flex flex-col rounded-card border bg-bg-surface p-4 transition-colors hover:border-border-strong"
      style={{ borderColor: r.state === "normal" ? "var(--color-border-subtle)" : stateVar[r.state] }}
      aria-label={`Open reactor ${r.id}`}
    >
      <div className="flex items-center gap-3">
        <HealthRing score={r.tick?.health?.score ?? null} state={r.tick?.health?.state ?? r.state} size={46} />
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-2">
            <span className="display-num text-lg font-semibold">{r.id.split("-").pop()}</span>
            <StatusPill state={r.state} compact />
          </div>
          <div className="truncate text-xs text-text-muted">
            Batch {r.batchId} · {strategyLabel(r.strategy)}
          </div>
        </div>
      </div>
      <p className="mt-3 text-sm font-medium" style={{ color: r.state === "normal" ? undefined : stateVar[r.state] }}>
        {story.headline}
      </p>
      <p className="mt-0.5 line-clamp-2 min-h-[2.5rem] text-xs text-text-secondary">{story.detail}</p>
      <dl className="mt-3 grid grid-cols-3 gap-2 border-t border-border-subtle pt-3 text-xs">
        <div>
          <dt className="text-text-muted">Forecast</dt>
          <dd className="display-num font-semibold">{f ? `${fmtInt(f.p50)} ${f.unit}` : "—"}</dd>
        </div>
        <div>
          <dt className="text-text-muted">DO</dt>
          <dd className="display-num font-semibold">{fmt(valueOf(r.tick, "do_pct"), 0)}%</dd>
        </div>
        <div>
          <dt className="text-text-muted">Power</dt>
          <dd className="display-num font-semibold">{fmtInt(valueOf(r.tick, "power_kw"))} kW</dd>
        </div>
      </dl>
      <span className="mt-3 flex items-center gap-1 text-xs font-medium text-text-secondary group-hover:text-text-primary">
        Open reactor <ArrowRight size={13} />
      </span>
    </Link>
  );
}

export default function PlantPage() {
  const { plantId = "" } = useParams();
  const navigate = useNavigate();
  const plant = useQuery({ queryKey: ["plant", plantId], queryFn: () => api.plant(plantId), refetchInterval: 5_000 });
  const all = useLive((s) => s.reactors);
  const select = useProcessStore((s) => s.select);
  const processId = plant.data?.process_id;
  useEffect(() => {
    if (processId) select(processId); // the plant's process becomes the working context
  }, [processId, select]);

  if (plant.isLoading)
    return (
      <Page wide>
        <Skeleton className="h-16" />
        <Skeleton className="h-[420px]" />
      </Page>
    );
  if (plant.isError || !plant.data) return <ErrorState title="Could not load this plant" onRetry={() => void plant.refetch()} />;
  const p = plant.data;
  const reactors = p.reactor_ids.map((id) => all[id]).filter((r): r is ReactorLive => !!r);
  const FamilyIcon = p.process_family === "precision" ? Dna : Sprout;

  return (
    <Page wide>
      <PageHeader
        eyebrow={`${p.city}, ${p.country}${p.commissioned ? ` · commissioned ${p.commissioned}` : ""}`}
        title={p.name}
        subtitle={
          <span className="flex flex-wrap items-center gap-x-2">
            <FamilyIcon size={14} style={{ color: "var(--color-accent-500)" }} />
            Producing {p.process_name.toLowerCase()} ·{" "}
            <Link to="/app/process" className="text-accent-500 hover:underline">
              see how this process is controlled
            </Link>
          </span>
        }
        actions={<StatusPill state={p.state} />}
      />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile label="Reactors" value={p.reactors} sub={`${p.watch} on watch`} />
        <StatTile
          label="Open alarms"
          value={p.alarms_open}
          sub={p.alarms_open ? "acknowledge from the reactor page or phone" : "nothing waiting"}
          tone={p.alarms_open ? "var(--color-state-alarm)" : undefined}
        />
        <StatTile label="Power now" value={`${fmtInt(p.power_kw)} kW`} sub="agitation + aeration (assumed efficiencies)" />
        <StatTile
          label="Yield outlook"
          value={p.forecast_vs_typical_pct === null ? "—" : `${Math.round(p.forecast_vs_typical_pct)}%`}
          sub="average forecast vs a typical batch"
        />
      </div>

      {reactors.length === 0 ? (
        <EmptyState title="Waiting for live data" message="The reactors appear as soon as the live stream connects." />
      ) : (
        <>
          <section className="overflow-hidden rounded-card border border-border-subtle">
            <div className="h-[280px] md:h-[340px] xl:h-[360px]">
              <ErrorBoundary title="3D view unavailable">
                <FleetScene reactors={reactors} onSelect={(id) => navigate(`/app/plants/${p.id}/reactors/${id}`)} />
              </ErrorBoundary>
            </div>
          </section>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {reactors.map((r) => (
              <ReactorCard key={r.id} r={r} plantId={p.id} />
            ))}
          </div>
        </>
      )}
    </Page>
  );
}
