import { useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import { ArrowRight, Bell, BrainCircuit, Database, Dna, LineChart, ShieldCheck, Sprout, TrendingUp, Zap } from "lucide-react";
import type { ReactNode } from "react";
import { Link } from "react-router-dom";

import { Brand, ThemeToggle } from "@/app/AppShell";
import { HealthRing } from "@/components/viz";
import { api } from "@/lib/api/client";
import { fmt, fmtInt } from "@/lib/format";
import { useSession } from "@/lib/session";
import { useThemeSync } from "@/lib/theme";

// Content never waits on scroll animations (they can fail to fire); a gentle mount fade only.
const fade = { initial: { opacity: 0.001 }, animate: { opacity: 1 }, transition: { duration: 0.3 } };

function Outcome({ icon, kpi, title, body, metric }: { icon: ReactNode; kpi: string; title: string; body: string; metric?: string }) {
  return (
    <motion.div {...fade} className="rounded-card border border-border-subtle bg-bg-surface p-6">
      <span className="flex h-10 w-10 items-center justify-center rounded-control" style={{ background: "var(--color-accent-glow)", color: "var(--color-accent-500)" }}>
        {icon}
      </span>
      <div className="mt-4 text-xs font-medium text-text-muted">{kpi}</div>
      <h3 className="display mt-1 text-xl font-semibold">{title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-text-secondary">{body}</p>
      {metric && (
        <p className="mt-4 border-t border-border-subtle pt-3 text-sm">
          <span className="display-num font-semibold" style={{ color: "var(--color-accent-500)" }}>
            {metric}
          </span>
        </p>
      )}
    </motion.div>
  );
}

/** Illustrative product preview for the hero (static values, labelled as such). */
function HeroPreview() {
  return (
    <div className="relative">
      <div className="absolute -inset-6 rounded-[32px] opacity-60 blur-2xl" style={{ background: "var(--color-accent-glow)" }} aria-hidden />
      <div className="relative rounded-[20px] border border-border-strong bg-bg-surface p-5 shadow-2xl">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs text-text-muted">Pune Mycoprotein Works · R2</div>
            <div className="display text-lg font-semibold" style={{ color: "var(--color-state-alarm)" }}>
              Oxygen transfer dropping
            </div>
          </div>
          <HealthRing score={39} state="alarm" size={52} />
        </div>
        <svg viewBox="0 0 320 110" className="mt-4 w-full" aria-hidden>
          <path d="M0 30 C60 28 90 26 120 34 C160 46 200 66 240 72 C270 76 300 76 320 76 L320 96 C290 98 260 96 240 94 C200 90 160 70 120 50 C90 40 60 40 0 42 Z" fill="var(--color-accent-glow)" />
          <path d="M0 36 C60 34 90 32 120 42 C160 56 200 78 240 83 C270 86 300 86 320 86" fill="none" stroke="var(--color-accent-500)" strokeWidth="2.5" />
          <line x1="0" x2="320" y1="34" y2="34" stroke="var(--color-chart-reference)" strokeDasharray="5 4" />
          <line x1="118" x2="118" y1="0" y2="110" stroke="var(--color-state-alarm)" strokeWidth="1.5" />
          <text x="124" y="12" fontSize="10" fill="var(--color-text-secondary)">fault caught here</text>
        </svg>
        <div className="mt-3 rounded-control p-3" style={{ background: "var(--color-accent-glow)" }}>
          <div className="text-xs font-medium" style={{ color: "var(--color-accent-500)" }}>
            Do this
          </div>
          <div className="text-sm font-medium">Restore aeration to recipe and raise agitation one step. Verify before applying.</div>
        </div>
        <div className="mt-3 flex items-center justify-between text-[11px] text-text-muted">
          <span>Illustrative preview</span>
          <span className="flex items-center gap-1">
            <Bell size={11} /> Paged to the operator's phone
          </span>
        </div>
      </div>
    </div>
  );
}

export default function LandingPage() {
  useThemeSync();
  const signedIn = !!useSession((s) => s.session);
  const metrics = useQuery({ queryKey: ["metrics"], queryFn: api.metrics, staleTime: 60_000, retry: 0 });
  const m = metrics.data;
  const c30 = m?.yield?.checkpoints.find((c) => c.progress === 0.3);
  const k = m?.faults?.summary;
  const cta = signedIn ? "/app" : "/login";

  return (
    <div className="h-full overflow-y-auto">
      <header className="sticky top-0 z-20 border-b border-border-subtle backdrop-blur" style={{ background: "color-mix(in srgb, var(--color-bg-base) 85%, transparent)" }}>
        <div className="mx-auto flex h-16 max-w-7xl items-center gap-8 px-4 md:px-8">
          <Brand />
          <nav className="hidden items-center gap-6 text-sm text-text-secondary md:flex">
            <a href="#outcomes" className="hover:text-text-primary">Outcomes</a>
            <a href="#processes" className="hover:text-text-primary">Processes</a>
            <a href="#how" className="hover:text-text-primary">How it works</a>
          </nav>
          <div className="ml-auto flex items-center gap-3">
            <ThemeToggle />
            <Link to={cta} className="rounded-control bg-accent-500 px-4 py-2 text-sm font-semibold text-bg-base hover:bg-accent-600">
              {signedIn ? "Open console" : "Sign in"}
            </Link>
          </div>
        </div>
      </header>

      <section className="mx-auto grid max-w-7xl items-center gap-12 px-4 py-16 md:px-8 lg:grid-cols-[1.1fr_0.9fr] lg:py-24">
        <motion.div initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.4 }}>
          <div className="inline-flex items-center gap-2 rounded-full border border-border-subtle px-3 py-1 text-xs text-text-secondary">
            <span className="h-1.5 w-1.5 rounded-full" style={{ background: "var(--color-accent-500)" }} />
            AI co-pilot for alternative-protein fermentation
          </div>
          <h1 className="display mt-5 text-4xl font-semibold leading-[1.08] tracking-tight md:text-6xl">
            Every batch has a decisive moment. <span style={{ color: "var(--color-accent-500)" }}>Kairos finds it.</span>
          </h1>
          <p className="mt-5 max-w-xl text-lg leading-relaxed text-text-secondary">
            Kairos watches the sensors you already have, forecasts final yield hours ahead, catches drift with almost no false
            alarms, and tells operators exactly what to change, while cutting the energy spent on agitation and aeration.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <Link to={cta} className="flex items-center gap-2 rounded-control bg-accent-500 px-5 py-3 font-semibold text-bg-base hover:bg-accent-600">
              {signedIn ? "Open console" : "Sign in to the demo"} <ArrowRight size={17} />
            </Link>
            <a href="#how" className="rounded-control border border-border-strong px-5 py-3 font-medium hover:bg-bg-elevated">
              See how it works
            </a>
          </div>
          <p className="mt-4 text-xs text-text-muted">Demo accounts are listed on the sign-in page. The demo company is fictional.</p>
        </motion.div>
        <HeroPreview />
      </section>

      <section id="outcomes" className="border-t border-border-subtle bg-bg-surface/0 py-16">
        <div className="mx-auto max-w-7xl px-4 md:px-8">
          <h2 className="display text-3xl font-semibold tracking-tight">Four outcomes, measured on batches the models never saw</h2>
          <p className="mt-2 max-w-3xl text-text-secondary">Every figure below is regenerated from the evaluation scripts in the repository.</p>
          <div className="mt-8 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <Outcome
              icon={<TrendingUp size={20} />}
              kpi="Yield prediction accuracy"
              title="Know the outcome early"
              body="A physics-informed forecast of final yield with an honest range, from the first fifth of the batch."
              metric={c30 ? `${fmtInt(c30.models.kairos!.mae)} kg error at 30% vs ${fmtInt(c30.models.naive_mean!.mae)} naive` : undefined}
            />
            <Outcome
              icon={<ShieldCheck size={20} />}
              kpi="Fault detection"
              title="Catch drift and contamination"
              body="Every signal is compared with how healthy batches looked at the same hour, so problems surface early."
              metric={k ? `${k.kairos.detected}/${k.kairos.n_fault_batches} faults caught, median ${fmt(k.kairos.median_delay_h)} h` : undefined}
            />
            <Outcome
              icon={<Bell size={20} />}
              kpi="False alarms"
              title="Alarms people trust"
              body="Smoothing, persistence and latching mean an alarm is worth getting up for, and stays until someone acts."
              metric={k ? `${fmt(k.kairos.false_alarms_per_batch, 1)} per batch vs ${fmt(k.mspc_baseline.false_alarms_per_batch, 1)} classic` : undefined}
            />
            <Outcome
              icon={<Zap size={20} />}
              kpi="Oxygen transfer vs energy"
              title="Less energy, same yield"
              body="The cheapest agitation and aeration that keep the culture safely supplied with oxygen, one cautious step at a time."
              metric={m?.energy ? `${fmt(m.energy.mean_saving_pct, 0)}% less agitation + aeration energy` : undefined}
            />
          </div>
        </div>
      </section>

      <section id="processes" className="border-t border-border-subtle py-16">
        <div className="mx-auto grid max-w-7xl gap-6 px-4 md:grid-cols-2 md:px-8">
          {[
            {
              icon: <Sprout size={20} />,
              title: "Biomass fermentation",
              body: "The organism is the protein. Kairos keeps long continuous or fed-batch runs productive and clean.",
              items: ["Mycoprotein", "Yeast protein", "Microalgae protein", "Gas-fermented protein"],
            },
            {
              icon: <Dna size={20} />,
              title: "Precision fermentation",
              body: "Microbes secrete one target protein. Kairos protects titre through induction and the production phase.",
              items: ["Whey protein", "Lactoferrin", "Animal-free collagen", "Egg-white protein"],
            },
          ].map((f) => (
            <motion.div key={f.title} {...fade} className="rounded-card border border-border-subtle bg-bg-surface p-7">
              <span className="flex h-10 w-10 items-center justify-center rounded-control" style={{ background: "var(--color-accent-glow)", color: "var(--color-accent-500)" }}>
                {f.icon}
              </span>
              <h3 className="display mt-4 text-2xl font-semibold">{f.title}</h3>
              <p className="mt-2 text-text-secondary">{f.body}</p>
              <div className="mt-5 flex flex-wrap gap-2">
                {f.items.map((i) => (
                  <span key={i} className="rounded-full border border-border-subtle px-3 py-1 text-sm text-text-secondary">
                    {i}
                  </span>
                ))}
              </div>
            </motion.div>
          ))}
        </div>
      </section>

      <section id="how" className="border-t border-border-subtle py-16">
        <div className="mx-auto max-w-7xl px-4 md:px-8">
          <h2 className="display text-3xl font-semibold tracking-tight">How Kairos works</h2>
          <div className="mt-8 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            {[
              { icon: <Database size={18} />, t: "Connect", b: "Read-only link to the plant historian. Only the sensors you already have: pH, DO, temperature, off-gas, feed." },
              { icon: <LineChart size={18} />, t: "Learn the golden batch", b: "Healthy batches define what normal looks like at every hour of the run." },
              { icon: <BrainCircuit size={18} />, t: "Predict and explain", b: "Hybrid physics + machine learning forecasts yield, flags drift and shows which signals drive it." },
              { icon: <Bell size={18} />, t: "Advise and save", b: "A grounded Claude copilot turns results into one clear action, on the console and the operator's phone." },
            ].map((s, i) => (
              <motion.div key={s.t} {...fade} className="rounded-card border border-border-subtle p-6">
                <div className="flex items-center gap-3">
                  <span className="display-num flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold" style={{ background: "var(--color-accent-glow)", color: "var(--color-accent-500)" }}>
                    {i + 1}
                  </span>
                  <span className="text-text-muted">{s.icon}</span>
                </div>
                <h3 className="display mt-4 text-lg font-semibold">{s.t}</h3>
                <p className="mt-1.5 text-sm leading-relaxed text-text-secondary">{s.b}</p>
              </motion.div>
            ))}
          </div>
          <div className="mt-12 flex flex-wrap items-center justify-between gap-4 rounded-card border border-border-subtle bg-bg-surface p-6">
            <div>
              <h3 className="display text-xl font-semibold">See it on a live plant</h3>
              <p className="text-sm text-text-secondary">Sign in with a demo account and follow an alarm from the map to the fix.</p>
            </div>
            <Link to={cta} className="flex items-center gap-2 rounded-control bg-accent-500 px-5 py-3 font-semibold text-bg-base hover:bg-accent-600">
              {signedIn ? "Open console" : "Sign in"} <ArrowRight size={17} />
            </Link>
          </div>
        </div>
      </section>

      <footer className="border-t border-border-subtle py-8">
        <div className="mx-auto flex max-w-7xl flex-wrap justify-between gap-3 px-4 text-xs text-text-muted md:px-8">
          <span>Kairos · built at Hack the Fork 2026, NIFTEM-K</span>
          <span>Data: IndPenSim industrial fermentation benchmark (synthetic). Demo company is fictional.</span>
        </div>
      </footer>
    </div>
  );
}
