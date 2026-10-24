import { Panel } from "@/components/primitives";

const ENGINES = [
  {
    name: "A · Early yield",
    body: "Mechanistic projection (lab penicillin x volume + recent production rate) combined with a LightGBM + ridge ensemble on physical features. Split-conformal intervals per batch-progress band; widened once a fault is flagged.",
  },
  {
    name: "B · Fault detection",
    body: "Multivariate statistical process control (PCA, Hotelling T² and SPE) on sensors normalised to the golden trajectory of normal batches, then EWMA smoothing, a 2-hour persistence rule and hysteresis to keep false alarms rare. Alarms latch until acknowledged.",
  },
  {
    name: "C · Why",
    body: "Exact additive attributions for the yield ensemble (TreeSHAP plus linear contributions) and SHAP interaction values; per-alarm contributions from each variable's deviation from normal batches.",
  },
  {
    name: "D · Energy",
    body: "Rushton power number for agitation, van't Riet kLa for oxygen transfer and an assumed compressor specific energy for aeration. Assumptions are labelled in the UI.",
  },
];

export default function MethodPage() {
  return (
    <div className="mx-auto max-w-4xl space-y-6 overflow-y-auto p-8">
      <h1 className="text-3xl font-semibold">How Kairos works</h1>
      <p className="text-lg text-text-secondary">
        Kairos watches ordinary process sensors, predicts the final yield early, flags drift with few false alarms,
        explains the drivers and recommends settings. Claude (on Amazon Bedrock) turns engine outputs into operator
        advice; it never produces a number itself.
      </p>
      <Panel className="p-5">
        <svg viewBox="0 0 760 150" className="w-full" role="img" aria-label="Architecture: sensors to engines to copilot to operator">
          {[
            ["Sensors", "pH, DO, T, off-gas, feed, aeration", 10],
            ["Engines", "yield · faults · why · energy", 200],
            ["Claude agent", "tools over engines, grounded", 390],
            ["Operator", "Control Room + phone Pager", 580],
          ].map(([t, s, x]) => (
            <g key={t as string}>
              <rect x={x as number} y="35" width="170" height="80" rx="10" fill="var(--color-bg-elevated)" stroke="var(--color-border-strong)" />
              <text x={(x as number) + 85} y="68" textAnchor="middle" fill="var(--color-text-primary)" fontSize="16" fontWeight="500">{t}</text>
              <text x={(x as number) + 85} y="92" textAnchor="middle" fill="var(--color-text-secondary)" fontSize="11">{s}</text>
            </g>
          ))}
          {[180, 370, 560].map((x) => (
            <path key={x} d={`M${x} 75 L${x + 18} 75`} stroke="var(--color-accent-500)" strokeWidth="2" markerEnd="url(#arrow)" />
          ))}
          <defs>
            <marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
              <path d="M0 0 L10 5 L0 10z" fill="var(--color-accent-500)" />
            </marker>
          </defs>
        </svg>
      </Panel>
      <div className="grid grid-cols-2 gap-4">
        {ENGINES.map((e) => (
          <Panel key={e.name} className="p-5">
            <h2 className="text-lg font-medium">{e.name}</h2>
            <p className="mt-2 text-text-secondary">{e.body}</p>
          </Panel>
        ))}
      </div>
      <Panel className="p-5">
        <h2 className="text-lg font-medium">Data and honesty</h2>
        <ul className="mt-2 list-disc space-y-1 pl-5 text-text-secondary">
          <li>Data: IndPenSim, 100 simulated industrial-scale penicillin fed-batch runs (synthetic, published simulator).</li>
          <li>Batch-wise splits: 60 train, 15 validation, 15 test-normal, 10 fault batches. Test batches never touch training or tuning.</li>
          <li>Every number shows a provenance label: Measured, Published, Assumed or Synthetic.</li>
          <li>Limitations are listed in docs/LIMITATIONS.md and on the Evidence page.</li>
        </ul>
      </Panel>
    </div>
  );
}
