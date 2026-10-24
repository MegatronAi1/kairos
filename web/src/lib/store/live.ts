import { create } from "zustand";

import type {
  AlarmEvent,
  HealthState,
  InsightEvent,
  KEvent,
  ReactorSummary,
  TickEvent,
} from "@/lib/api/types";

export type ConnectionStatus = "connecting" | "live" | "offline";

export interface ReactorLive {
  id: string;
  batchId: number;
  strategy: string;
  isFault: boolean;
  running: boolean;
  speed: number;
  tEndH: number;
  state: HealthState;
  acknowledged: boolean;
  tick: TickEvent | null;
  insight: InsightEvent | null;
  alarms: AlarmEvent[];
  history: TickEvent[]; // recent ticks for sparklines (bounded)
}

const HISTORY = 240;

interface LiveState {
  status: ConnectionStatus;
  reactors: Record<string, ReactorLive>;
  setStatus: (s: ConnectionStatus) => void;
  applySnapshot: (list: ReactorSummary[]) => void;
  applyEvent: (e: KEvent) => void;
  patch: (id: string, p: Partial<ReactorLive>) => void;
}

const fromSummary = (s: ReactorSummary): ReactorLive => ({
  id: s.id,
  batchId: s.batch_id,
  strategy: s.strategy,
  isFault: s.is_fault_batch,
  running: s.running,
  speed: s.speed_h_per_s,
  tEndH: s.t_end_h,
  state: s.state,
  acknowledged: s.acknowledged,
  tick: s.last_tick,
  insight: s.last_insight,
  alarms: [],
  history: s.last_tick ? [s.last_tick] : [],
});

export const useLive = create<LiveState>((set) => ({
  status: "connecting",
  reactors: {},
  setStatus: (status) => set({ status }),
  applySnapshot: (list) =>
    set({ reactors: Object.fromEntries(list.map((s) => [s.id, fromSummary(s)])) }),
  patch: (id, p) =>
    set((st) => (st.reactors[id] ? { reactors: { ...st.reactors, [id]: { ...st.reactors[id]!, ...p } } } : st)),
  applyEvent: (e) =>
    set((st) => {
      const r = st.reactors[e.reactor_id];
      if (!r) return st;
      let next: ReactorLive = r;
      switch (e.type) {
        case "tick": {
          // A backwards jump means seek/swap/restart: drop stale history.
          const rewound = r.tick !== null && (e.t_h < r.tick.t_h || e.batch_id !== r.batchId);
          const history = rewound ? [e] : [...r.history.slice(-(HISTORY - 1)), e];
          next = {
            ...r,
            tick: e,
            batchId: e.batch_id,
            history,
            ...(rewound ? { alarms: [], insight: null, state: "normal" as HealthState, acknowledged: false } : {}),
          };
          break;
        }
        case "alarm":
          next = {
            ...r,
            state: e.state,
            alarms: [...r.alarms, e],
            acknowledged: e.state === "alarm" ? false : r.acknowledged,
          };
          break;
        case "insight":
          next = { ...r, insight: e };
          break;
        case "ack":
          next = { ...r, acknowledged: true };
          break;
      }
      return { reactors: { ...st.reactors, [e.reactor_id]: next } };
    }),
}));

export const sortedReactors = (rs: Record<string, ReactorLive>) =>
  Object.values(rs).sort((a, b) => a.id.localeCompare(b.id));
