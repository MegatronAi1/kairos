import * as Menu from "@radix-ui/react-dropdown-menu";
import { Droplets, Thermometer, Wind, Zap } from "lucide-react";
import { useState } from "react";
import { useLocation } from "react-router-dom";

import { api, type FaultKind } from "@/lib/api/client";

const KINDS: { kind: FaultKind; label: string; detail: string; icon: typeof Wind }[] = [
  { kind: "oxygen", label: "Oxygen transfer drop", detail: "Aeration fault (batch 100)", icon: Wind },
  { kind: "feed", label: "Feed drop", detail: "Substrate feed fault (batch 97)", icon: Droplets },
  { kind: "temperature", label: "Temperature drift", detail: "Cooling fault (batch 96)", icon: Thermometer },
];

/** Demo: replay a real fault batch on a reactor so the detector raises a live alarm
 * (web toast, phone notification, copilot card) within seconds. */
export function SimulateAlarm() {
  const loc = useLocation();
  const current = loc.pathname.match(/\/reactors\/([^/]+)/)?.[1];
  const reactorId = current ? decodeURIComponent(current) : "PUN-R1";
  const [note, setNote] = useState<string | null>(null);

  const fire = async (kind: FaultKind) => {
    try {
      const res = await api.triggerFault(reactorId, kind);
      setNote(`${reactorId}: alarm in about ${Math.round(res.expected_alarm_in_s)} s`);
    } catch {
      setNote("Could not start the simulation");
    }
    setTimeout(() => setNote(null), 6000);
  };

  return (
    <Menu.Root>
      <Menu.Trigger asChild>
        <button
          className="flex items-center gap-1.5 rounded-control border border-border-subtle px-2.5 py-1.5 text-xs font-medium text-text-secondary hover:border-border-strong hover:text-text-primary"
          title="Demo: trigger a real fault replay"
        >
          <Zap size={13} style={{ color: "var(--color-state-watch)" }} />
          <span className="hidden sm:inline">{note ?? "Simulate alarm"}</span>
        </button>
      </Menu.Trigger>
      <Menu.Portal>
        <Menu.Content sideOffset={6} align="end" className="z-50 w-72 rounded-card border border-border-strong bg-bg-elevated p-1.5 shadow-xl">
          <div className="px-2.5 pb-1.5 pt-1 text-[11px] text-text-muted">
            Replays a real IndPenSim fault batch on <span className="num font-semibold text-text-secondary">{reactorId}</span> from 2 h
            before the fault. The detector, copilot and phone react as they would live.
          </div>
          {KINDS.map(({ kind, label, detail, icon: Icon }) => (
            <Menu.Item
              key={kind}
              onSelect={() => void fire(kind)}
              className="flex cursor-pointer items-center gap-3 rounded-control px-2.5 py-2 outline-none data-[highlighted]:bg-bg-surface"
            >
              <Icon size={16} className="text-text-muted" />
              <span>
                <span className="block text-sm">{label}</span>
                <span className="block text-[11px] text-text-muted">{detail}</span>
              </span>
            </Menu.Item>
          ))}
        </Menu.Content>
      </Menu.Portal>
    </Menu.Root>
  );
}
