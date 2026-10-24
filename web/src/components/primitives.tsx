import * as Tooltip from "@radix-ui/react-tooltip";
import { AlertTriangle, Inbox } from "lucide-react";
import type { ReactNode } from "react";

import type { Confidence, HealthState, Provenance } from "@/lib/api/types";
import { provenanceVar, stateLabel, stateVar } from "@/lib/format";

export function Tip({ content, children }: { content: ReactNode; children: ReactNode }) {
  return (
    <Tooltip.Root delayDuration={250}>
      <Tooltip.Trigger asChild>{children}</Tooltip.Trigger>
      <Tooltip.Portal>
        <Tooltip.Content
          sideOffset={6}
          className="z-50 max-w-xs rounded-control border border-border-strong bg-bg-elevated px-3 py-2 text-sm text-text-secondary shadow-lg"
        >
          {content}
          <Tooltip.Arrow style={{ fill: "var(--color-bg-elevated)" }} />
        </Tooltip.Content>
      </Tooltip.Portal>
    </Tooltip.Root>
  );
}

/** Healthy / Watch / Alarm with a state dot. */
export function StatusPill({ state, compact = false }: { state: HealthState; compact?: boolean }) {
  const c = stateVar[state];
  return (
    <span
      role="status"
      aria-label={`Status ${stateLabel[state]}`}
      className={`inline-flex items-center gap-1.5 rounded-full border font-medium ${compact ? "px-2 py-0.5 text-xs" : "px-3 py-1 text-xs"}`}
      style={{
        color: c,
        borderColor: `color-mix(in srgb, ${c} 40%, transparent)`,
        background: `color-mix(in srgb, ${c} 12%, transparent)`,
      }}
    >
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: c }} />
      {stateLabel[state]}
    </span>
  );
}

const PROV_NAME: Record<Provenance, string> = {
  measured: "Measured",
  published: "Published",
  assumed: "Assumed",
  synthetic: "Synthetic",
  fitted: "Fitted",
};

/** M / P / A / S data-provenance label with a tooltip naming the source. */
export function ProvenanceChip({ provenance, source }: { provenance: Provenance; source?: string }) {
  const c = provenanceVar[provenance];
  return (
    <Tip content={source ? `${PROV_NAME[provenance]}: ${source}` : `${PROV_NAME[provenance]} data`}>
      <span
        tabIndex={0}
        aria-label={`${PROV_NAME[provenance]} data`}
        className="num inline-flex h-[18px] w-[18px] shrink-0 items-center justify-center rounded border text-[10px] font-semibold"
        style={{ color: c, borderColor: `color-mix(in srgb, ${c} 60%, transparent)` }}
      >
        {PROV_NAME[provenance][0]}
      </span>
    </Tip>
  );
}

export function ConfidenceMeter({ confidence }: { confidence: Confidence }) {
  const filled = { low: 1, medium: 2, high: 3 }[confidence];
  return (
    <span className="inline-flex items-center gap-1" aria-label={`Confidence ${confidence}`}>
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="h-1 w-3.5 rounded-sm"
          style={{ background: i < filled ? "var(--color-accent-500)" : "var(--color-border-strong)" }}
        />
      ))}
      <span className="ml-1 text-xs text-text-secondary">{confidence}</span>
    </span>
  );
}

const EVIDENCE: Record<string, string> = {
  fault_detector: "fault detector",
  yield_model: "yield model",
  energy_model: "energy model",
  why_engine: "drivers",
  live_sensors: "live sensors",
  evaluation: "model evidence",
  ponr: "point of no return",
  what_if: "what-if",
  provenance: "provenance",
};

export function EvidenceChip({ source }: { source: string }) {
  return (
    <span className="rounded-full border border-border-subtle bg-bg-inset px-2 py-0.5 text-xs text-text-secondary">
      {EVIDENCE[source] ?? source.replaceAll("_", " ")}
    </span>
  );
}

export function Skeleton({ className = "h-4 w-full" }: { className?: string }) {
  return <div className={`animate-pulse rounded-control bg-bg-elevated ${className}`} aria-hidden />;
}

export function EmptyState({ title, message, action }: { title: string; message?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 p-8 text-center">
      <Inbox size={28} strokeWidth={1.5} className="text-text-muted" aria-hidden />
      <p className="text-lg font-medium">{title}</p>
      {message && <p className="max-w-sm text-text-secondary">{message}</p>}
      {action}
    </div>
  );
}

export function ErrorState({ title, message, onRetry }: { title: string; message?: string; onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 p-8 text-center" role="alert">
      <AlertTriangle size={28} strokeWidth={1.5} style={{ color: "var(--color-state-alarm)" }} aria-hidden />
      <p className="text-lg font-medium">{title}</p>
      {message && <p className="max-w-sm text-text-secondary">{message}</p>}
      {onRetry && (
        <button
          onClick={onRetry}
          className="mt-2 rounded-control border border-border-strong px-4 py-2 text-sm hover:bg-bg-elevated"
        >
          Try again
        </button>
      )}
    </div>
  );
}

export function Panel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`rounded-card border border-border-subtle bg-bg-surface ${className}`}>{children}</section>;
}
