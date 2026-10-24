import { create } from "zustand";

import type { AlarmEvent, InsightCard } from "@/lib/api/types";

export interface AlarmToast {
  key: string;
  reactorId: string;
  plantId: string;
  alarm: AlarmEvent;
  card: InsightCard | null;
  at: number;
  loud: boolean; // false for alarms already open when the page loaded
}

const MUTE_KEY = "kairos.alerts.muted";
const readMuted = () => {
  try {
    return localStorage.getItem(MUTE_KEY) === "1";
  } catch {
    return false;
  }
};

interface ToastState {
  toasts: AlarmToast[];
  muted: boolean;
  push: (alarm: AlarmEvent, plantId: string, card?: InsightCard | null, loud?: boolean) => void;
  attachCard: (reactorId: string, card: InsightCard) => void;
  dismiss: (key: string) => void;
  dismissReactor: (reactorId: string) => void;
  setMuted: (m: boolean) => void;
}

/** Alarm toasts shown on every screen until dismissed or acknowledged. */
export const useToasts = create<ToastState>((set) => ({
  toasts: [],
  muted: readMuted(),
  push: (alarm, plantId, card = null, loud = true) =>
    set((s) => ({
      toasts: [
        { key: `${alarm.reactor_id}-${alarm.ts}`, reactorId: alarm.reactor_id, plantId, alarm, card, at: Date.now(), loud },
        ...s.toasts.filter((t) => t.reactorId !== alarm.reactor_id),
      ].slice(0, 4),
    })),
  attachCard: (reactorId, card) =>
    set((s) => ({ toasts: s.toasts.map((t) => (t.reactorId === reactorId ? { ...t, card } : t)) })),
  dismiss: (key) => set((s) => ({ toasts: s.toasts.filter((t) => t.key !== key) })),
  dismissReactor: (reactorId) => set((s) => ({ toasts: s.toasts.filter((t) => t.reactorId !== reactorId) })),
  setMuted: (muted) => {
    try {
      localStorage.setItem(MUTE_KEY, muted ? "1" : "0");
    } catch {
      /* private mode: keep in memory only */
    }
    set({ muted });
  },
}));
