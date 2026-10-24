import * as Tooltip from "@radix-ui/react-tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { lazy, Suspense } from "react";
import { BrowserRouter, Navigate, Route, Routes, useParams } from "react-router-dom";

import { ErrorBoundary } from "@/components/ErrorBoundary";
import { Skeleton } from "@/components/primitives";

import { AppShell } from "./AppShell";

const LandingPage = lazy(() => import("@/features/landing/LandingPage"));
const LoginPage = lazy(() => import("@/features/auth/LoginPage"));
const OverviewPage = lazy(() => import("@/features/overview/OverviewPage"));
const PlantPage = lazy(() => import("@/features/plant/PlantPage"));
const ReactorPage = lazy(() => import("@/features/reactor/ReactorPage"));
const EvidencePage = lazy(() => import("@/features/evidence/EvidencePage"));
const MethodPage = lazy(() => import("@/features/method/MethodPage"));
const ProcessPage = lazy(() => import("@/features/process/ProcessPage"));

const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: 1 } } });

/** Old links (/reactor/PUN-R2) keep working. */
function LegacyReactor() {
  const { id = "" } = useParams();
  const plant = { PUN: "pune", BLR: "bengaluru", RTM: "rotterdam", SIN: "singapore" }[id.split("-")[0] ?? ""];
  return <Navigate to={plant ? `/app/plants/${plant}/reactors/${id}` : "/app"} replace />;
}

const Loading = () => <Skeleton className="m-6 h-96" />;

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Tooltip.Provider>
        <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
          <ErrorBoundary>
            <Suspense fallback={<Loading />}>
              <Routes>
                <Route path="/" element={<LandingPage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/app" element={<AppShell />}>
                  <Route index element={<OverviewPage />} />
                  <Route path="plants/:plantId" element={<PlantPage />} />
                  <Route path="plants/:plantId/reactors/:id" element={<ReactorPage />} />
                  <Route path="process" element={<ProcessPage />} />
                  <Route path="evidence" element={<EvidencePage />} />
                  <Route path="method" element={<MethodPage />} />
                </Route>
                <Route path="/reactor/:id" element={<LegacyReactor />} />
                <Route path="/evidence" element={<Navigate to="/app/evidence" replace />} />
                <Route path="/process" element={<Navigate to="/app/process" replace />} />
                <Route path="*" element={<Navigate to="/" replace />} />
              </Routes>
            </Suspense>
          </ErrorBoundary>
        </BrowserRouter>
      </Tooltip.Provider>
    </QueryClientProvider>
  );
}
