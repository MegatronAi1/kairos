import type { ReactNode } from "react";

import type { ProcessDetail, Range, ReactorKind } from "@/lib/process";

/*
 * Schematic fermenters for the four reactor families. Every probe badge shows the
 * catalog's setpoint range; flows animate to show what moves where. Pure SVG,
 * themed by tokens. Viewbox 760 x 470.
 */

type Probe = "do" | "ph" | "temp" | "offgas" | "feed" | "gas" | "light" | "level";

const KEYS: Record<Probe, string[]> = {
  do: ["do_pct", "dissolved_oxygen_pct"],
  ph: ["ph"],
  temp: ["temp_c", "temperature_c"],
  offgas: ["co2_pct", "offgas_co2_pct"],
  feed: ["methanol_g_l", "glucose_g_l", "dilution_rate_per_h", "feed_rate"],
  gas: ["h2_o2_ratio", "pressure_bar", "gas_flow_vvm"],
  light: ["light_umol_m2_s"],
  level: ["level_pct"],
};

const LABEL: Record<Probe, string> = {
  do: "DO",
  ph: "pH",
  temp: "Temp",
  offgas: "Off-gas",
  feed: "Feed",
  gas: "Gas",
  light: "Light",
  level: "Level",
};

const fmtRange = (r?: Range): string | null => {
  if (!r) return null;
  if (r.value !== undefined) return `${r.value}${r.unit ? ` ${r.unit}` : ""}`;
  if (r.min !== undefined && r.max !== undefined) return r.min === r.max ? `${r.min}` : `${r.min}–${r.max}`;
  return null;
};

function rangeFor(p: ProcessDetail, probe: Probe): string | null {
  for (const k of KEYS[probe]) {
    const v = fmtRange(p.setpoints?.[k]);
    if (v) {
      const unit = k.endsWith("_pct") ? "%" : k === "temp_c" ? " °C" : "";
      return `${v}${unit}`;
    }
  }
  return null;
}

function Badge({ x, y, probe, value, anchor = "start" }: { x: number; y: number; probe: Probe; value: string | null; anchor?: "start" | "end" }) {
  const w = 58 + (value ? Math.min(value.length, 12) * 6.4 : 0);
  const bx = anchor === "end" ? x - w : x;
  return (
    <g>
      <rect x={bx} y={y - 13} width={w} height={26} rx={13} fill="var(--color-bg-elevated)" stroke="var(--color-accent-500)" strokeWidth={1.2} />
      <circle cx={bx + 13} cy={y} r={4} fill="var(--color-accent-500)">
        <animate attributeName="opacity" values="1;0.35;1" dur="2.4s" repeatCount="indefinite" />
      </circle>
      <text x={bx + 23} y={y + 4} fontSize="12" fontWeight={600} fill="var(--color-text-primary)">
        {LABEL[probe]}
      </text>
      {value && (
        <text x={bx + 23 + LABEL[probe].length * 7.6 + 6} y={y + 4} fontSize="11.5" fill="var(--color-text-secondary)" className="num">
          {value}
        </text>
      )}
    </g>
  );
}

const Flow = ({ d, color = "var(--color-accent-500)", width = 2.5, reverse = false }: { d: string; color?: string; width?: number; reverse?: boolean }) => (
  <path d={d} fill="none" stroke={color} strokeWidth={width} strokeDasharray="7 7" strokeLinecap="round" className={reverse ? "kflow-rev" : "kflow"} />
);

const Pipe = ({ d }: { d: string }) => <path d={d} fill="none" stroke="var(--color-border-strong)" strokeWidth={6} strokeLinecap="round" strokeLinejoin="round" />;

function Box({ x, y, w, h, title, sub }: { x: number; y: number; w: number; h: number; title: string; sub?: string }) {
  return (
    <g>
      <rect x={x} y={y} width={w} height={h} rx={10} fill="var(--color-bg-surface)" stroke="var(--color-border-strong)" />
      <text x={x + w / 2} y={y + (sub ? h / 2 - 3 : h / 2 + 4)} textAnchor="middle" fontSize="12.5" fontWeight={600} fill="var(--color-text-primary)">
        {title}
      </text>
      {sub && (
        <text x={x + w / 2} y={y + h / 2 + 13} textAnchor="middle" fontSize="10.5" fill="var(--color-text-muted)">
          {sub}
        </text>
      )}
    </g>
  );
}

function Bubbles({ x0, x1, y0, y1, n = 14 }: { x0: number; x1: number; y0: number; y1: number; n?: number }) {
  return (
    <g>
      {Array.from({ length: n }, (_, i) => {
        const x = x0 + ((i * 37) % 100) / 100 * (x1 - x0);
        const dur = 2.2 + ((i * 13) % 10) / 6;
        return (
          <circle key={i} cx={x} cy={y0} r={2.5 + (i % 3)} fill="var(--color-text-primary)" opacity={0.35}>
            <animate attributeName="cy" values={`${y0};${y1}`} dur={`${dur}s`} begin={`${(i * 0.31) % dur}s`} repeatCount="indefinite" />
          </circle>
        );
      })}
    </g>
  );
}

const Broth = ({ d }: { d: string }) => <path d={d} fill="var(--color-accent-500)" opacity={0.16} />;

function Controller({ x, y }: { x: number; y: number }) {
  return (
    <g>
      <rect x={x} y={y} width={150} height={54} rx={12} fill="var(--color-accent-glow)" stroke="var(--color-accent-500)" />
      <text x={x + 75} y={y + 23} textAnchor="middle" fontSize="13" fontWeight={700} fill="var(--color-text-primary)" className="display">
        Kairos + PLC
      </text>
      <text x={x + 75} y={y + 40} textAnchor="middle" fontSize="10.5" fill="var(--color-text-secondary)">
        reads probes · advises setpoints
      </text>
    </g>
  );
}

/* --- reactor families ------------------------------------------------------ */

function StirredTank({ p }: { p: ProcessDetail }) {
  return (
    <>
      <Box x={20} y={40} w={120} h={58} title="Feed tank" sub={p.carbon_source?.slice(0, 22) ?? "carbon source"} />
      <Box x={20} y={150} w={120} h={58} title="Acid / base" sub="pH control" />
      <Box x={20} y={372} w={120} h={58} title="Air compressor" sub={(p.gases ?? ["air"]).join(" + ")} />
      <Box x={600} y={40} w={140} h={58} title="Off-gas analyser" sub="O₂ / CO₂ out" />
      <Box x={600} y={300} w={140} h={58} title="Cooling water" sub="jacket in / out" />
      <Pipe d="M140 69 H250 V96" />
      <Flow d="M140 69 H250 V96" />
      <Pipe d="M140 179 H230 V140 H262" />
      <Flow d="M140 179 H230 V140 H262" color="var(--color-chart-series2)" />
      <Pipe d="M140 401 H380 V392" />
      <Flow d="M140 401 H380 V392" color="var(--color-text-secondary)" />
      <Pipe d="M380 96 V60 H600" />
      <Flow d="M380 96 V60 H600" color="var(--color-text-muted)" />
      <Pipe d="M600 329 H520 V320" />
      <Flow d="M600 340 H530" color="var(--color-chart-series2)" reverse />
      {/* vessel */}
      <rect x={250} y={96} width={260} height={296} rx={34} fill="var(--color-bg-inset)" stroke="var(--color-text-secondary)" strokeWidth={2} />
      <rect x={240} y={150} width={280} height={200} rx={20} fill="none" stroke="var(--color-chart-series2)" strokeWidth={1.5} strokeDasharray="4 5" opacity={0.7} />
      <Broth d="M252 170 H508 V358 Q508 390 476 390 H284 Q252 390 252 358 Z" />
      <Bubbles x0={300} x1={460} y0={380} y1={180} n={18} />
      <line x1={380} y1={70} x2={380} y2={340} stroke="var(--color-text-secondary)" strokeWidth={3} />
      {[230, 320].map((y) => (
        <g key={y}>
          <rect x={348} y={y - 3} width={64} height={6} rx={2} fill="var(--color-text-secondary)">
            <animateTransform attributeName="transform" type="scale" values="1 1;0.25 1;1 1" dur="0.9s" repeatCount="indefinite" additive="sum" />
          </rect>
        </g>
      ))}
      <path d="M330 372 H430" stroke="var(--color-text-secondary)" strokeWidth={3} />
      <rect x={366} y={44} width={28} height={26} rx={4} fill="var(--color-border-strong)" />
      <text x={380} y={36} textAnchor="middle" fontSize="10.5" fill="var(--color-text-muted)">motor</text>
      <Badge x={520} y={160} probe="do" value={rangeFor(p, "do")} />
      <Badge x={520} y={200} probe="ph" value={rangeFor(p, "ph")} />
      <Badge x={520} y={240} probe="temp" value={rangeFor(p, "temp")} />
      <Badge x={240} y={120} probe="feed" value={rangeFor(p, "feed")} anchor="end" />
      <Controller x={305} y={410} />
    </>
  );
}

function Airlift({ p }: { p: ProcessDetail }) {
  return (
    <>
      <Box x={20} y={300} w={130} h={58} title="Nutrient feed" sub={p.carbon_source?.slice(0, 22) ?? "glucose + N"} />
      <Box x={20} y={392} w={130} h={58} title="Air / O₂ supply" sub="compressor" />
      <Box x={600} y={300} w={140} h={58} title="Continuous harvest" sub={p.product_location === "biomass" ? "to heat treatment" : "to recovery"} />
      <Box x={600} y={30} w={140} h={50} title="Off-gas" sub="CO₂ / O₂ analyser" />
      {/* loop: riser (left) and downcomer (right) */}
      <rect x={250} y={70} width={70} height={360} rx={28} fill="var(--color-bg-inset)" stroke="var(--color-text-secondary)" strokeWidth={2} />
      <rect x={410} y={70} width={70} height={360} rx={28} fill="var(--color-bg-inset)" stroke="var(--color-text-secondary)" strokeWidth={2} />
      <path d="M262 70 Q365 -10 468 70" fill="var(--color-bg-inset)" stroke="var(--color-text-secondary)" strokeWidth={2} />
      <path d="M262 430 Q365 500 468 430" fill="none" stroke="var(--color-text-secondary)" strokeWidth={2} />
      <Broth d="M252 110 H318 V428 H252 Z" />
      <Broth d="M412 110 H478 V428 H412 Z" />
      <Bubbles x0={262} x1={308} y0={420} y1={110} n={16} />
      <Flow d="M285 420 V100" width={2} />
      <Flow d="M330 52 Q365 30 400 52" width={2} />
      <Flow d="M445 100 V420" width={2} />
      <Flow d="M400 452 Q365 470 330 452" width={2} />
      <text x={285} y={448} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)">riser</text>
      <text x={445} y={448} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)">downcomer</text>
      <Pipe d="M150 421 H285 V430" />
      <Flow d="M150 421 H270" color="var(--color-text-secondary)" />
      <Pipe d="M150 329 H252" />
      <Flow d="M150 329 H252" />
      <Pipe d="M478 329 H600" />
      <Flow d="M478 329 H600" color="var(--color-chart-series3)" />
      <Pipe d="M365 30 V20 H600 V40" />
      <Flow d="M365 30 V20 H600" color="var(--color-text-muted)" />
      <Badge x={490} y={130} probe="do" value={rangeFor(p, "do")} />
      <Badge x={490} y={170} probe="ph" value={rangeFor(p, "ph")} />
      <Badge x={490} y={210} probe="temp" value={rangeFor(p, "temp")} />
      <Badge x={240} y={270} probe="feed" value={rangeFor(p, "feed")} anchor="end" />
      <Controller x={540} y={392} />
    </>
  );
}

function Photobioreactor({ p }: { p: ProcessDetail }) {
  const tubes = [120, 160, 200, 240, 280, 320];
  return (
    <>
      {/* light panel */}
      <rect x={210} y={86} width={300} height={260} rx={14} fill="var(--color-state-watch)" opacity={0.08} />
      {Array.from({ length: 8 }, (_, i) => (
        <line key={i} x1={222 + i * 40} y1={70} x2={222 + i * 40} y2={84} stroke="var(--color-state-watch)" strokeWidth={3} strokeLinecap="round">
          <animate attributeName="opacity" values="1;0.4;1" dur={`${1.6 + i * 0.1}s`} repeatCount="indefinite" />
        </line>
      ))}
      <text x={360} y={60} textAnchor="middle" fontSize="11" fill="var(--color-text-muted)">
        {p.light ? "light (LED or sun)" : "dark, heterotrophic"}
      </text>
      {/* serpentine tubes */}
      {tubes.map((y, i) => (
        <g key={y}>
          <rect x={220} y={y - 12} width={280} height={24} rx={12} fill="var(--color-accent-500)" opacity={0.18} stroke="var(--color-text-secondary)" />
          {i < tubes.length - 1 && (
            <path d={i % 2 === 0 ? `M500 ${y} Q520 ${y + 20} 500 ${y + 40}` : `M220 ${y} Q200 ${y + 20} 220 ${y + 40}`} fill="none" stroke="var(--color-text-secondary)" strokeWidth={2} />
          )}
        </g>
      ))}
      <Flow d={`M225 120 H495 M495 160 H225 M225 200 H495 M495 240 H225 M225 280 H495 M495 320 H225`} width={2} />
      <Box x={20} y={86} w={130} h={58} title="Degasser" sub="O₂ out" />
      <Box x={20} y={250} w={130} h={58} title="CO₂ injection" sub="carbon + pH" />
      <Box x={20} y={380} w={130} h={58} title="Nutrients" sub={p.carbon_source?.slice(0, 22) ?? "N, P, trace"} />
      <Box x={600} y={250} w={140} h={58} title="Heat exchanger" sub="temperature" />
      <Box x={600} y={380} w={140} h={58} title="Harvest" sub="centrifuge" />
      <Pipe d="M150 279 H200 V320 H220" />
      <Flow d="M150 279 H200 V320 H220" color="var(--color-text-secondary)" />
      <Pipe d="M220 120 H180 V115 H150" />
      <Flow d="M220 120 H180 V115 H150" color="var(--color-text-muted)" />
      <Pipe d="M150 409 H360 V346" />
      <Flow d="M150 409 H360 V346" />
      <Pipe d="M500 279 H600" />
      <Pipe d="M500 320 H560 V409 H600" />
      <Flow d="M500 320 H560 V409 H600" color="var(--color-chart-series3)" />
      <Badge x={600} y={120} probe="light" value={rangeFor(p, "light")} />
      <Badge x={600} y={160} probe="ph" value={rangeFor(p, "ph")} />
      <Badge x={600} y={200} probe="temp" value={rangeFor(p, "temp")} />
      <Badge x={210} y={370} probe="do" value={rangeFor(p, "do")} anchor="end" />
      <Controller x={305} y={400} />
    </>
  );
}

function GasFermenter({ p }: { p: ProcessDetail }) {
  return (
    <>
      <Box x={20} y={40} w={130} h={56} title="Electrolyser" sub="H₂ (+ O₂) from power" />
      <Box x={20} y={150} w={130} h={56} title="CO₂ supply" sub="carbon source" />
      <Box x={20} y={260} w={130} h={56} title="Mineral medium" sub={p.nitrogen_source?.slice(0, 22) ?? "N, P, trace"} />
      <Box x={600} y={40} w={140} h={56} title="Gas recycle" sub="compressor loop" />
      <Box x={600} y={300} w={140} h={56} title="Continuous harvest" sub="dry protein powder" />
      {/* column */}
      <rect x={290} y={60} width={150} height={360} rx={40} fill="var(--color-bg-inset)" stroke="var(--color-text-secondary)" strokeWidth={2} />
      <Broth d="M292 120 H438 V380 Q438 418 400 418 H330 Q292 418 292 380 Z" />
      <Bubbles x0={305} x1={425} y0={410} y1={125} n={22} />
      <Pipe d="M150 68 H230 V430 H330 V418" />
      <Flow d="M150 68 H230 V420" color="var(--color-chart-series2)" />
      <Pipe d="M150 178 H220 V440 H365 V418" />
      <Flow d="M150 178 H215" color="var(--color-text-secondary)" />
      <Pipe d="M150 289 H290" />
      <Flow d="M150 289 H290" />
      <Pipe d="M365 60 V40 H600" />
      <Flow d="M365 60 V40 H600" color="var(--color-text-muted)" />
      <Pipe d="M740 68 H760 V460 H400 V418" />
      <Flow d="M745 80 V455 H405" color="var(--color-text-muted)" />
      <Pipe d="M440 329 H600" />
      <Flow d="M440 329 H600" color="var(--color-chart-series3)" />
      {/* safety */}
      <rect x={455} y={100} width={120} height={40} rx={8} fill="color-mix(in srgb, var(--color-state-alarm) 12%, transparent)" stroke="var(--color-state-alarm)" />
      <text x={515} y={117} textAnchor="middle" fontSize="11.5" fontWeight={600} fill="var(--color-state-alarm)">H₂ / O₂ safety</text>
      <text x={515} y={131} textAnchor="middle" fontSize="10" fill="var(--color-text-secondary)">stay outside flammable mix</text>
      <Badge x={455} y={170} probe="gas" value={rangeFor(p, "gas")} />
      <Badge x={455} y={210} probe="do" value={rangeFor(p, "do")} />
      <Badge x={455} y={250} probe="ph" value={rangeFor(p, "ph")} />
      <Badge x={280} y={250} probe="temp" value={rangeFor(p, "temp")} anchor="end" />
      <Controller x={560} y={392} />
    </>
  );
}

const DIAGRAMS: Record<ReactorKind, (props: { p: ProcessDetail }) => ReactNode> = {
  stirred_tank: StirredTank,
  airlift: Airlift,
  photobioreactor: Photobioreactor,
  gas_fermenter: GasFermenter,
};

export const REACTOR_LABEL: Record<ReactorKind, string> = {
  stirred_tank: "Stirred-tank fermenter",
  airlift: "Airlift loop fermenter",
  photobioreactor: "Photobioreactor",
  gas_fermenter: "Gas fermenter",
};

export function FermenterDiagram({ process }: { process: ProcessDetail }) {
  const Diagram = DIAGRAMS[process.reactor] ?? StirredTank;
  return (
    <svg viewBox="0 0 760 470" className="w-full" role="img" aria-label={`${REACTOR_LABEL[process.reactor] ?? "Fermenter"} schematic for ${process.name}`}>
      <Diagram p={process} />
    </svg>
  );
}
