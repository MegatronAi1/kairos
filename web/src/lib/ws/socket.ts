import { useEffect } from "react";

import { api, wsUrl } from "@/lib/api/client";
import type { KEvent, SnapshotMessage } from "@/lib/api/types";
import { useLive } from "@/lib/store/live";
import { useToasts } from "@/lib/store/toasts";

/** One app-wide WebSocket with exponential-backoff reconnect. */
export function useLiveSocket(): void {
  useEffect(() => {
    let ws: WebSocket | null = null;
    let attempt = 0;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let ping: ReturnType<typeof setInterval> | undefined;
    let closed = false;
    const { setStatus, applySnapshot, applyEvent } = useLive.getState();

    const connect = () => {
      if (closed) return;
      setStatus("connecting");
      ws = new WebSocket(wsUrl());
      ws.onopen = () => {
        attempt = 0;
        setStatus("live");
        ws?.send(JSON.stringify({ type: "subscribe", reactors: [] }));
        ping = setInterval(() => ws?.send(JSON.stringify({ type: "ping" })), 20_000);
      };
      ws.onmessage = (msg) => {
        const data = JSON.parse(msg.data as string) as KEvent | SnapshotMessage | { type: "pong" };
        if (data.type === "snapshot") {
          applySnapshot(data.reactors);
          // Seed alarm history so timeline markers survive a page load or reconnect.
          for (const r of data.reactors) {
            void api
              .events(r.id)
              .then((alarms) => useLive.getState().patch(r.id, { alarms }))
              .catch(() => undefined);
          }
        }
        else if (data.type !== "pong") {
          const prev = data.type === "tick" ? useLive.getState().reactors[data.reactor_id]?.tick : null;
          applyEvent(data);
          const toasts = useToasts.getState();
          // A new batch (loop, restart, simulated fault) clears that reactor's old toast.
          if (data.type === "tick" && prev && (data.t_h < prev.t_h || data.batch_id !== prev.batch_id))
            toasts.dismissReactor(data.reactor_id);
          if (data.type === "alarm" && data.state === "alarm")
            toasts.push(data, useLive.getState().reactors[data.reactor_id]?.plantId ?? "");
          else if (data.type === "alarm" && data.state === "normal") toasts.dismissReactor(data.reactor_id);
          else if (data.type === "insight") toasts.attachCard(data.reactor_id, data.card);
          else if (data.type === "ack") toasts.dismissReactor(data.reactor_id);
        }
      };
      ws.onclose = () => {
        clearInterval(ping);
        if (closed) return;
        setStatus("offline");
        const delay = Math.min(10_000, 500 * 2 ** Math.min(attempt, 5));
        attempt += 1;
        timer = setTimeout(connect, delay);
      };
      ws.onerror = () => ws?.close();
    };

    connect();
    return () => {
      closed = true;
      clearTimeout(timer);
      clearInterval(ping);
      ws?.close();
    };
  }, []);
}
