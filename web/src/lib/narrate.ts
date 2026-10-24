import type { ReactorLive } from "@/lib/store/live";

import { fmtInt, sensorLabel } from "./format";

/** One plain-language sentence about a reactor, for people rather than parsers. */
export function statusSentence(r: ReactorLive): { headline: string; detail: string } {
  const f = r.tick?.forecast;
  const pct = f ? Math.round(f.vs_golden_pct) : null;
  const outlook = f
    ? `on track for about ${fmtInt(f.p50)} ${f.unit} (${pct}% of a typical batch)`
    : "building up enough history for a forecast";
  const lead = r.tick?.health?.top_contributors[0];

  if (r.state === "alarm") {
    return {
      headline: r.insight?.card.title ?? "Needs attention now",
      detail: r.acknowledged
        ? `Acknowledged. Forecast is now ${outlook}.`
        : r.insight?.card.action ?? "Open the copilot for the diagnosis and the fix.",
    };
  }
  if (r.state === "watch") {
    return {
      headline: lead ? `Drifting: ${sensorLabel(lead.var).toLowerCase()} running ${lead.dir}` : "Drifting from normal",
      detail: `Kairos is watching closely. Still ${outlook}.`,
    };
  }
  if (!r.running && r.tick && r.tick.progress > 0.95) {
    return { headline: "Batch complete", detail: f ? `Finished near ${fmtInt(f.p50)} ${f.unit}.` : "Replay finished." };
  }
  return { headline: "Running smoothly", detail: `All signals within normal bands, ${outlook}.` };
}
