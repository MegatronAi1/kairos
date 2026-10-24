import { useQuery } from "@tanstack/react-query";
import { ArrowRight, Dna, Sprout } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";

import { Page, PageHeader, SectionTitle, StatTile } from "@/components/layout";
import { ErrorState, Panel, Skeleton, StatusPill } from "@/components/primitives";
import { api, type PlantRollup } from "@/lib/api/client";
import { fmt, fmtInt, stateVar } from "@/lib/format";
import { useSession } from "@/lib/session";

import { PlantMap } from "./PlantMap";

const greeting = () => {
  const h = new Date().getHours();
  return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
};

function PlantRow({ p }: { p: PlantRollup }) {
  const Icon = p.process_family === "precision" ? Dna : Sprout;
  return (
    <Link
      to={`/app/plants/${p.id}`}
      className="group block rounded-card border bg-bg-surface p-4 transition-colors hover:border-border-strong"
      style={{ borderColor: p.state === "normal" ? "var(--color-border-subtle)" : stateVar[p.state] }}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="truncate font-semibold">{p.name}</span>
          </div>
          <div className="mt-0.5 flex items-center gap-1.5 text-xs text-text-secondary">
            <Icon size={12} style={{ color: "var(--color-accent-500)" }} />
            {p.process_name} · {p.city}, {p.country}
          </div>
        </div>
        <StatusPill state={p.state} compact />
      </div>
      <dl className="mt-3 grid grid-cols-3 gap-2 text-xs">
        <div>
          <dt className="text-text-muted">Reactors</dt>
          <dd className="display-num text-base font-semibold">
            {p.reactors}
            {p.alarms_open > 0 && <span style={{ color: "var(--color-state-alarm)" }}> · {p.alarms_open} alarm</span>}
          </dd>
        </div>
        <div>
          <dt className="text-text-muted">Power now</dt>
          <dd className="display-num text-base font-semibold">{fmtInt(p.power_kw)} kW</dd>
        </div>
        <div>
          <dt className="text-text-muted">Yield outlook</dt>
          <dd className="display-num text-base font-semibold">{p.forecast_vs_typical_pct === null ? "—" : `${Math.round(p.forecast_vs_typical_pct)}%`}</dd>
        </div>
      </dl>
      <div className="mt-3 flex items-center gap-1 text-xs font-medium text-text-secondary group-hover:text-text-primary">
        Open plant <ArrowRight size={13} />
      </div>
    </Link>
  );
}

export default function OverviewPage() {
  const navigate = useNavigate();
  const session = useSession((s) => s.session)!;
  const plants = useQuery({ queryKey: ["plants"], queryFn: api.plants, refetchInterval: 5_000 });
  const rank = { alarm: 2, watch: 1, normal: 0 } as const;
  const list = [...(plants.data ?? [])].sort((a, b) => rank[b.state] - rank[a.state] || b.alarms_open - a.alarms_open);
  const alarms = list.reduce((n, p) => n + p.alarms_open, 0);
  const reactors = list.reduce((n, p) => n + p.reactors, 0);
  const power = list.reduce((n, p) => n + p.power_kw, 0);
  const needs = list.filter((p) => p.state !== "normal").length;

  return (
    <Page wide>
      <PageHeader
        eyebrow={session.tenant.name}
        title={`${greeting()}, ${session.user.name.split(" ")[0]}`}
        subtitle={
          plants.isLoading
            ? "Checking in on your plants…"
            : needs === 0
              ? `All ${list.length} plants are running smoothly.`
              : `${needs} of ${list.length} plants ${needs === 1 ? "needs" : "need"} your attention. Click a plant on the map to go straight to its reactors.`
        }
      />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <StatTile label="Plants online" value={plants.isLoading ? "—" : list.length} sub={`across ${new Set(list.map((p) => p.country)).size} countries`} />
        <StatTile label="Reactors monitored" value={plants.isLoading ? "—" : reactors} sub="every signal vs healthy batches" />
        <StatTile
          label="Open alarms"
          value={plants.isLoading ? "—" : alarms}
          sub={alarms ? "waiting for acknowledgement" : "nothing waiting"}
          tone={alarms ? "var(--color-state-alarm)" : undefined}
        />
        <StatTile label="Agitation + aeration power" value={plants.isLoading ? "—" : `${fmt(power / 1000, 2)} MW`} sub="live, all reactors (assumed efficiencies)" />
      </div>

      {plants.isError ? (
        <ErrorState title="Could not load your plants" onRetry={() => void plants.refetch()} />
      ) : (
        <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_400px]">
          <Panel className="self-start overflow-hidden">
            <div className="flex items-baseline justify-between px-5 pt-4">
              <h2 className="text-base font-semibold">Plants</h2>
              <span className="text-xs text-text-muted">Pins show the most serious reactor state at each site</span>
            </div>
            <div className="aspect-[960/520] w-full">
              {plants.isLoading ? <Skeleton className="h-full w-full" /> : <PlantMap plants={list} onSelect={(id) => navigate(`/app/plants/${id}`)} />}
            </div>
          </Panel>
          <div>
            <SectionTitle aside="sorted by urgency">Sites</SectionTitle>
            <div className="space-y-3">
              {plants.isLoading
                ? [0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-36" />)
                : list.map((p) => <PlantRow key={p.id} p={p} />)}
            </div>
          </div>
        </div>
      )}
      <p className="text-xs text-text-muted">
        {session.tenant.name} is a fictional demo company. Each reactor replays a held-out batch of the IndPenSim industrial
        fermentation benchmark, so every forecast and alarm is a real model output on unseen data.
      </p>
    </Page>
  );
}
