import type { ReactNode } from "react";

/** Consistent page heading: one display title, one supporting line, optional actions. */
export function PageHeader({ title, subtitle, eyebrow, actions }: { title: ReactNode; subtitle?: ReactNode; eyebrow?: ReactNode; actions?: ReactNode }) {
  return (
    <header className="flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {eyebrow && <div className="eyebrow mb-1">{eyebrow}</div>}
        <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">{title}</h1>
        {subtitle && <p className="mt-1 max-w-3xl text-sm text-text-secondary md:text-base">{subtitle}</p>}
      </div>
      {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
    </header>
  );
}

export function SectionTitle({ children, aside }: { children: ReactNode; aside?: ReactNode }) {
  return (
    <div className="mb-3 flex items-baseline justify-between gap-3">
      <h2 className="text-base font-semibold">{children}</h2>
      {aside && <div className="text-xs text-text-muted">{aside}</div>}
    </div>
  );
}

export function StatTile({ label, value, sub, tone }: { label: string; value: ReactNode; sub?: ReactNode; tone?: string }) {
  return (
    <div className="rounded-card border border-border-subtle bg-bg-surface p-4">
      <div className="text-xs font-medium text-text-secondary">{label}</div>
      <div className="display-num mt-1 text-2xl font-semibold" style={{ color: tone }}>
        {value}
      </div>
      {sub && <div className="mt-0.5 text-xs text-text-muted">{sub}</div>}
    </div>
  );
}

export function Page({ children, wide = false }: { children: ReactNode; wide?: boolean }) {
  return (
    <div className="h-full overflow-y-auto">
      <div className={`mx-auto space-y-6 px-4 py-6 md:px-8 md:py-8 ${wide ? "max-w-[1600px]" : "max-w-7xl"}`}>{children}</div>
    </div>
  );
}
