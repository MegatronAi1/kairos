import { useQuery } from "@tanstack/react-query";
import { Activity, BookOpen, ChevronRight, Factory, FlaskConical, LogOut, Map, Menu, Monitor, Moon, Sun, X } from "lucide-react";
import { useState, type ReactNode } from "react";
import { Link, NavLink, Navigate, Outlet, useLocation, useMatch } from "react-router-dom";

import { ProcessSelector } from "@/components/ProcessSelector";
import { Tip } from "@/components/primitives";
import { api } from "@/lib/api/client";
import { stateVar } from "@/lib/format";
import { useSession } from "@/lib/session";
import { useLive } from "@/lib/store/live";
import { setThemePref, useThemePref, useThemeSync, type ThemePref } from "@/lib/theme";
import { useLiveSocket } from "@/lib/ws/socket";

export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <span className="flex items-center gap-2">
      <svg width="22" height="22" viewBox="0 0 32 32" aria-hidden>
        <circle cx="16" cy="16" r="12" fill="none" stroke="var(--color-accent-500)" strokeWidth="3" />
        <circle cx="16" cy="16" r="4.5" fill="var(--color-accent-500)" />
      </svg>
      {!compact && <span className="display text-lg font-semibold tracking-tight">Kairos</span>}
    </span>
  );
}

export function ThemeToggle() {
  const pref = useThemePref();
  const options: { value: ThemePref; label: string; icon: typeof Sun }[] = [
    { value: "system", label: "Match system theme", icon: Monitor },
    { value: "dark", label: "Dark theme", icon: Moon },
    { value: "light", label: "Light theme", icon: Sun },
  ];
  return (
    <div className="flex rounded-control border border-border-subtle p-0.5" role="radiogroup" aria-label="Theme">
      {options.map(({ value, label, icon: Icon }) => (
        <button
          key={value}
          role="radio"
          aria-checked={pref === value}
          aria-label={label}
          title={label}
          onClick={() => setThemePref(value)}
          className={`rounded px-1.5 py-1 ${pref === value ? "bg-bg-elevated text-text-primary" : "text-text-muted hover:text-text-primary"}`}
        >
          <Icon size={14} />
        </button>
      ))}
    </div>
  );
}

function ConnectionIndicator() {
  const status = useLive((s) => s.status);
  const [color, label] = {
    live: ["var(--color-state-healthy)", "Live"],
    connecting: ["var(--color-state-watch)", "Connecting"],
    offline: ["var(--color-state-alarm)", "Offline, retrying"],
  }[status];
  return (
    <span className="flex items-center gap-2 text-xs text-text-secondary" role="status" aria-live="polite">
      <span className="h-2 w-2 rounded-full" style={{ background: color }} />
      {label}
    </span>
  );
}

function NavItem({ to, icon, children, end }: { to: string; icon: ReactNode; children: ReactNode; end?: boolean }) {
  return (
    <NavLink
      to={to}
      end={end}
      className={({ isActive }) =>
        `flex items-center gap-2.5 rounded-control px-3 py-2 text-sm ${isActive ? "bg-bg-elevated font-medium text-text-primary" : "text-text-secondary hover:bg-bg-elevated hover:text-text-primary"}`
      }
    >
      {icon}
      {children}
    </NavLink>
  );
}

function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  const session = useSession((s) => s.session)!;
  const signOut = useSession((s) => s.signOut);
  const plants = useQuery({ queryKey: ["plants"], queryFn: api.plants, refetchInterval: 10_000 });
  return (
    <div className="flex h-full flex-col" onClick={onNavigate}>
      <div className="flex h-14 items-center px-4">
        <Link to="/app" aria-label="Kairos home">
          <Brand />
        </Link>
      </div>
      <div className="mx-3 mb-3 rounded-control border border-border-subtle px-3 py-2">
        <div className="text-[11px] text-text-muted">Organisation</div>
        <div className="truncate text-sm font-medium">{session.tenant.name}</div>
      </div>
      <nav className="flex-1 space-y-0.5 overflow-y-auto px-3" aria-label="Main">
        <NavItem to="/app" end icon={<Map size={16} />}>
          Operations map
        </NavItem>
        <div className="px-3 pb-1 pt-4 text-[11px] font-medium text-text-muted">Plants</div>
        {(plants.data ?? []).map((p) => (
          <NavItem key={p.id} to={`/app/plants/${p.id}`} icon={<span className="ml-1 h-2 w-2 rounded-full" style={{ background: stateVar[p.state] }} />}>
            <span className="min-w-0 flex-1 truncate">{p.city}</span>
            {p.alarms_open > 0 && (
              <span className="rounded-full px-1.5 text-[11px] font-semibold text-white" style={{ background: "var(--color-state-alarm)" }}>
                {p.alarms_open}
              </span>
            )}
          </NavItem>
        ))}
        <div className="px-3 pb-1 pt-4 text-[11px] font-medium text-text-muted">Knowledge</div>
        <NavItem to="/app/process" icon={<Factory size={16} />}>
          Process library
        </NavItem>
        <NavItem to="/app/evidence" icon={<Activity size={16} />}>
          Model evidence
        </NavItem>
        <NavItem to="/app/method" icon={<BookOpen size={16} />}>
          How it works
        </NavItem>
      </nav>
      <div className="border-t border-border-subtle p-3">
        <div className="flex items-center gap-3">
          <span
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-sm font-semibold"
            style={{ background: "var(--color-accent-glow)", color: "var(--color-accent-500)" }}
          >
            {session.user.name
              .split(" ")
              .map((w) => w[0])
              .join("")
              .slice(0, 2)}
          </span>
          <div className="min-w-0 flex-1">
            <div className="truncate text-sm font-medium">{session.user.name}</div>
            <div className="truncate text-xs text-text-muted">{session.user.role}</div>
          </div>
          <Tip content="Sign out">
            <button onClick={signOut} aria-label="Sign out" className="rounded-control p-1.5 text-text-muted hover:bg-bg-elevated hover:text-text-primary">
              <LogOut size={16} />
            </button>
          </Tip>
        </div>
      </div>
    </div>
  );
}

function Breadcrumbs() {
  const loc = useLocation();
  const plantMatch = useMatch("/app/plants/:plantId/*");
  const plants = useQuery({ queryKey: ["plants"], queryFn: api.plants, enabled: !!plantMatch });
  const plant = plants.data?.find((p) => p.id === plantMatch?.params.plantId);
  const reactor = loc.pathname.match(/\/reactors\/([^/]+)/)?.[1];
  const crumbs: { label: string; to?: string }[] = [{ label: "Operations", to: "/app" }];
  if (plantMatch) crumbs.push({ label: plant?.name ?? "Plant", to: reactor ? `/app/plants/${plantMatch.params.plantId}` : undefined });
  if (reactor) crumbs.push({ label: decodeURIComponent(reactor) });
  const section = { process: "Process library", evidence: "Model evidence", method: "How it works" }[loc.pathname.split("/")[2] ?? ""];
  if (section) crumbs.push({ label: section });
  return (
    <nav aria-label="Breadcrumb" className="flex min-w-0 items-center gap-1 text-sm">
      {crumbs.map((c, i) => (
        <span key={c.label} className="flex min-w-0 items-center gap-1">
          {i > 0 && <ChevronRight size={14} className="shrink-0 text-text-muted" />}
          {c.to && i < crumbs.length - 1 ? (
            <Link to={c.to} className="truncate text-text-secondary hover:text-text-primary">
              {c.label}
            </Link>
          ) : (
            <span className="truncate font-medium">{c.label}</span>
          )}
        </span>
      ))}
    </nav>
  );
}

/** Signed-in application frame: sidebar, top bar, live socket. */
export function AppShell() {
  const session = useSession((s) => s.session);
  const [open, setOpen] = useState(false);
  useLiveSocket();
  useThemeSync();
  if (!session) return <Navigate to="/login" replace />;
  return (
    <div className="flex h-full">
      <aside className="hidden w-64 shrink-0 border-r border-border-subtle bg-bg-surface lg:block">
        <Sidebar />
      </aside>
      {open && (
        <div className="fixed inset-0 z-40 flex lg:hidden">
          <div className="w-72 border-r border-border-subtle bg-bg-surface shadow-xl">
            <Sidebar onNavigate={() => setOpen(false)} />
          </div>
          <button aria-label="Close menu" className="flex-1 bg-black/40" onClick={() => setOpen(false)} />
        </div>
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-14 shrink-0 items-center gap-3 border-b border-border-subtle px-4 md:px-6">
          <button className="rounded-control p-1.5 lg:hidden" aria-label="Open menu" onClick={() => setOpen(true)}>
            {open ? <X size={18} /> : <Menu size={18} />}
          </button>
          <Breadcrumbs />
          <div className="ml-auto flex items-center gap-3">
            <div className="hidden md:block">
              <ProcessSelector />
            </div>
            <Tip content="Live reactors replay held-out batches of IndPenSim, a published industrial fed-batch simulator (synthetic data).">
              <span tabIndex={0} className="hidden items-center gap-1.5 text-xs text-text-muted xl:flex">
                <FlaskConical size={13} /> Benchmark data
              </span>
            </Tip>
            <ConnectionIndicator />
            <ThemeToggle />
          </div>
        </header>
        <main className="min-h-0 flex-1">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
