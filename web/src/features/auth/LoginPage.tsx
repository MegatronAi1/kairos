import { useQuery } from "@tanstack/react-query";
import { ArrowRight, Loader2 } from "lucide-react";
import { useEffect, useState } from "react";
import { Link, Navigate, useNavigate, useSearchParams } from "react-router-dom";

import { Brand, ThemeToggle } from "@/app/AppShell";
import { api, ApiError } from "@/lib/api/client";
import { useSession } from "@/lib/session";
import { useThemeSync } from "@/lib/theme";

export default function LoginPage() {
  useThemeSync();
  const navigate = useNavigate();
  const session = useSession((s) => s.session);
  const signIn = useSession((s) => s.signIn);
  const accounts = useQuery({ queryKey: ["demo-accounts"], queryFn: api.demoAccounts, retry: 1 });
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [params] = useSearchParams();
  const next = params.get("next")?.startsWith("/app") ? params.get("next")! : "/app";
  const auto = params.get("demo") === "1" ? accounts.data?.[0] : undefined;

  useEffect(() => {
    // /login?demo=1 signs in with the first public demo account (deck captures, kiosks).
    if (auto && !session) void submit(undefined, auto);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [auto]);

  if (session) return <Navigate to={next} replace />;

  async function submit(e?: React.FormEvent, creds?: { email: string; password: string }) {
    e?.preventDefault();
    const c = creds ?? { email, password };
    setBusy(true);
    setError(null);
    try {
      const res = await api.login(c.email, c.password);
      signIn(res);
      navigate(next);
    } catch (err) {
      setError(err instanceof ApiError && err.status === 401 ? "That email and password don't match a demo account." : "Can't reach the Kairos server.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="grid h-full lg:grid-cols-2">
      <div className="relative hidden overflow-hidden border-r border-border-subtle bg-bg-surface lg:block">
        <div className="absolute inset-0 opacity-70" style={{ background: "radial-gradient(60% 50% at 30% 30%, var(--color-accent-glow), transparent)" }} aria-hidden />
        <div className="relative flex h-full flex-col justify-between p-12">
          <Link to="/">
            <Brand />
          </Link>
          <div>
            <p className="display text-3xl font-semibold leading-snug tracking-tight">
              From the first sign of drift to the fix, on the operator's phone before the batch is lost.
            </p>
            <ul className="mt-6 space-y-2 text-sm text-text-secondary">
              <li>Final yield forecast from the first fifth of the batch</li>
              <li>Alarms with a plain-language cause and one clear action</li>
              <li>Agitation and aeration tuned for less energy at safe oxygen</li>
            </ul>
          </div>
          <p className="text-xs text-text-muted">Demo environment · fictional company · benchmark data from IndPenSim</p>
        </div>
      </div>

      <div className="flex h-full flex-col overflow-y-auto">
        <div className="flex items-center justify-between p-4 md:p-6">
          <Link to="/" className="lg:invisible">
            <Brand />
          </Link>
          <ThemeToggle />
        </div>
        <div className="flex flex-1 items-center justify-center px-4 pb-12">
          <div className="w-full max-w-sm">
            <h1 className="display text-3xl font-semibold tracking-tight">Sign in</h1>
            <p className="mt-1 text-sm text-text-secondary">to the Kairos operations console</p>
            <form onSubmit={(e) => void submit(e)} className="mt-8 space-y-4">
              <label className="block">
                <span className="text-sm font-medium">Work email</span>
                <input
                  type="email"
                  autoComplete="username"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="mt-1.5 w-full rounded-control border border-border-subtle bg-bg-inset px-3 py-2.5 outline-none focus:border-accent-500"
                  placeholder="you@company.com"
                />
              </label>
              <label className="block">
                <span className="text-sm font-medium">Password</span>
                <input
                  type="password"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="mt-1.5 w-full rounded-control border border-border-subtle bg-bg-inset px-3 py-2.5 outline-none focus:border-accent-500"
                />
              </label>
              {error && (
                <p role="alert" className="text-sm" style={{ color: "var(--color-state-alarm)" }}>
                  {error}
                </p>
              )}
              <button
                type="submit"
                disabled={busy}
                className="flex w-full items-center justify-center gap-2 rounded-control bg-accent-500 py-2.5 font-semibold text-bg-base hover:bg-accent-600 disabled:opacity-60"
              >
                {busy ? <Loader2 size={17} className="animate-spin" /> : <>Sign in <ArrowRight size={16} /></>}
              </button>
            </form>

            <div className="mt-8 rounded-card border border-border-subtle bg-bg-surface p-4">
              <div className="text-sm font-medium">Demo accounts</div>
              <p className="mt-0.5 text-xs text-text-muted">For judges and reviewers. Click to sign in.</p>
              <ul className="mt-3 space-y-2">
                {(accounts.data ?? []).map((a) => (
                  <li key={a.email}>
                    <button
                      onClick={() => void submit(undefined, a)}
                      disabled={busy}
                      className="flex w-full items-center justify-between gap-3 rounded-control border border-border-subtle px-3 py-2 text-left hover:border-border-strong"
                    >
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-medium">
                          {a.name} · {a.role}
                        </span>
                        <span className="num block truncate text-xs text-text-muted">
                          {a.email} / {a.password}
                        </span>
                      </span>
                      <ArrowRight size={15} className="shrink-0 text-text-muted" />
                    </button>
                  </li>
                ))}
                {accounts.isError && <li className="text-xs text-text-muted">Start the backend to load demo accounts.</li>}
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
