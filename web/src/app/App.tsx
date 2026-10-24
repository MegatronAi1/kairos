import * as Tooltip from "@radix-ui/react-tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Activity, BookOpen, Factory, FlaskConical, LayoutGrid, Monitor, Moon, Sun } from "lucide-react";
import { lazy, Suspense } from "react";
import { BrowserRouter, NavLink, Route, Routes } from "react-router-dom";

import { ErrorBoundary } from "@/components/ErrorBoundary";
import { Skeleton, Tip } from "@/components/primitives";
import { ProcessSelector } from "@/components/ProcessSelector";
import { FleetPage } from "@/features/fleet/FleetPage";
import { useLive } from "@/lib/store/live";
import { setThemePref, useThemePref, useThemeSync, type ThemePref } from "@/lib/theme";
import { useLiveSocket } from "@/lib/ws/socket";

const ReactorPage = lazy(() => import("@/features/reactor/ReactorPage"));
const EvidencePage = lazy(() => import("@/features/evidence/EvidencePage"));
const MethodPage = lazy(() => import("@/features/method/MethodPage"));
const ProcessPage = lazy(() => import("@/features/process/ProcessPage"));

const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: 1 } } });

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

function ThemeToggle() {
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

function Shell() {
  useLiveSocket();
  useThemeSync();
  const link = ({ isActive }: { isActive: boolean }) =>
    `flex items-center gap-2 rounded-control px-3 py-1.5 text-sm ${isActive ? "bg-bg-elevated text-text-primary" : "text-text-secondary hover:text-text-primary"}`;
  return (
    <div className="flex h-full flex-col">
      <header className="flex h-14 shrink-0 items-center gap-6 border-b border-border-subtle px-5">
        <div className="flex items-center gap-2">
          <span className="h-3 w-3 rounded-full border-2 border-accent-500" aria-hidden />
          <span className="font-semibold tracking-wide">Kairos</span>
          <span className="text-sm text-text-muted">Control Room</span>
        </div>
        <nav className="flex items-center gap-1" aria-label="Main">
          <NavLink to="/" end className={link}>
            <LayoutGrid size={15} /> Fleet
          </NavLink>
          <NavLink to="/process" className={link}>
            <Factory size={15} /> Process
          </NavLink>
          <NavLink to="/evidence" className={link}>
            <Activity size={15} /> Evidence
          </NavLink>
          <NavLink to="/method" className={link}>
            <BookOpen size={15} /> Method
          </NavLink>
        </nav>
        <ProcessSelector />
        <div className="ml-auto flex items-center gap-4">
          <Tip content="Live reactors replay IndPenSim, a published industrial penicillin fed-batch simulator (synthetic data).">
            <span tabIndex={0} className="flex items-center gap-1.5 text-xs text-text-muted">
              <FlaskConical size={13} /> Benchmark data: IndPenSim
            </span>
          </Tip>
          <ConnectionIndicator />
          <ThemeToggle />
        </div>
      </header>
      <main className="min-h-0 flex-1">
        <ErrorBoundary>
        <Suspense fallback={<Skeleton className="m-6 h-96" />}>
          <Routes>
            <Route path="/" element={<FleetPage />} />
            <Route path="/reactor/:id" element={<ReactorPage />} />
            <Route path="/evidence" element={<EvidencePage />} />
            <Route path="/method" element={<MethodPage />} />
            <Route path="/process" element={<ProcessPage />} />
          </Routes>
        </Suspense>
        </ErrorBoundary>
      </main>
    </div>
  );
}

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Tooltip.Provider>
        <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
          <Shell />
        </BrowserRouter>
      </Tooltip.Provider>
    </QueryClientProvider>
  );
}
