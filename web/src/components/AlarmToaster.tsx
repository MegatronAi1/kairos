import { useQuery } from "@tanstack/react-query";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import { BellOff, BellRing, Check, ChevronRight, Siren, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";

import { api } from "@/lib/api/client";
import { fmtHours, sensorLabel } from "@/lib/format";
import { useLive } from "@/lib/store/live";
import { useToasts, type AlarmToast } from "@/lib/store/toasts";

/** Two short rising tones, synthesised (no audio file to load). */
function chime(): void {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    [0, 0.22, 0.44].forEach((start, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "triangle";
      osc.frequency.value = i === 1 ? 1175 : 880;
      gain.gain.setValueAtTime(0.0001, ctx.currentTime + start);
      gain.gain.exponentialRampToValueAtTime(0.25, ctx.currentTime + start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + start + 0.18);
      osc.connect(gain).connect(ctx.destination);
      osc.start(ctx.currentTime + start);
      osc.stop(ctx.currentTime + start + 0.2);
    });
    setTimeout(() => void ctx.close(), 1200);
  } catch {
    /* audio blocked until the first user gesture: the visual toast still shows */
  }
}

function ToastCard({ t }: { t: AlarmToast }) {
  const navigate = useNavigate();
  const dismiss = useToasts((s) => s.dismiss);
  const reduce = useReducedMotion();
  const tick = useLive((s) => s.reactors[t.reactorId]?.tick);
  const plants = useQuery({ queryKey: ["plants"], queryFn: api.plants, staleTime: 60_000 });
  const plant = plants.data?.find((p) => p.id === t.plantId);
  const [acking, setAcking] = useState(false);
  const top = t.alarm.contributors[0]?.var;
  const title = t.card?.title ?? (top ? `${sensorLabel(top)} out of pattern` : "Process alarm");
  const ponr = t.alarm.ponr_hours;
  const left = ponr !== null && tick ? Math.max(0, ponr - (tick.t_h - t.alarm.t_h)) : null;
  const open = () => {
    navigate(`/app/plants/${t.plantId}/reactors/${t.reactorId}`);
    dismiss(t.key);
  };
  const ack = async () => {
    setAcking(true);
    try {
      await api.ack(t.reactorId);
      dismiss(t.key);
    } finally {
      setAcking(false);
    }
  };

  return (
    <motion.div
      layout
      role="alert"
      initial={reduce ? { opacity: 0 } : { opacity: 0, x: 80, scale: 0.96 }}
      animate={reduce ? { opacity: 1 } : { opacity: 1, x: [80, -10, 6, -4, 0], scale: 1 }}
      exit={reduce ? { opacity: 0 } : { opacity: 0, x: 60, transition: { duration: 0.18 } }}
      transition={{ duration: 0.55 }}
      className="pointer-events-auto relative w-[min(380px,calc(100vw-32px))] overflow-hidden rounded-card border bg-bg-elevated shadow-2xl"
      style={{ borderColor: "var(--color-state-alarm)" }}
    >
      <span className="absolute inset-y-0 left-0 w-1" style={{ background: "var(--color-state-alarm)" }} />
      <div className="flex items-start gap-3 py-3 pl-4 pr-3">
        <span
          className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-white"
          style={{ background: "var(--color-state-alarm)" }}
        >
          <Siren size={18} className={reduce ? "" : "animate-pulse"} />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2 text-xs text-text-muted">
            <span className="num font-semibold" style={{ color: "var(--color-state-alarm)" }}>
              {t.reactorId}
            </span>
            {plant && <span className="truncate">{plant.city}</span>}
          </div>
          <div className="mt-0.5 text-sm font-semibold leading-snug">{title}</div>
          {t.card?.action && <div className="mt-1 line-clamp-2 text-xs text-text-secondary">{t.card.action}</div>}
          {left !== null && (
            <div className="mt-1.5 text-xs text-text-secondary">
              {left > 0 ? (
                <>
                  Point of no return in <span className="num font-semibold text-text-primary">{fmtHours(left)}</span> (process time)
                </>
              ) : (
                "Point of no return passed: act to limit the loss"
              )}
            </div>
          )}
          <div className="mt-2.5 flex gap-2">
            <button onClick={open} className="flex items-center gap-1 rounded-control bg-accent-500 px-2.5 py-1.5 text-xs font-medium text-bg-base hover:opacity-90">
              Open reactor <ChevronRight size={13} />
            </button>
            <button
              onClick={() => void ack()}
              disabled={acking}
              className="flex items-center gap-1 rounded-control border border-border-strong px-2.5 py-1.5 text-xs font-medium hover:bg-bg-surface disabled:opacity-50"
            >
              <Check size={13} /> Acknowledge
            </button>
          </div>
        </div>
        <button onClick={() => dismiss(t.key)} aria-label="Dismiss alert" className="rounded-control p-1 text-text-muted hover:bg-bg-surface hover:text-text-primary">
          <X size={15} />
        </button>
      </div>
    </motion.div>
  );
}

/** Top-right alarm stack, mounted once in the app shell so it shows on every screen. */
export function AlarmToaster() {
  const toasts = useToasts((s) => s.toasts);
  const muted = useToasts((s) => s.muted);
  const setMuted = useToasts((s) => s.setMuted);
  const seen = useRef(new Set<string>());

  useEffect(() => {
    const fresh = toasts.filter((t) => !seen.current.has(t.key));
    fresh.forEach((t) => seen.current.add(t.key));
    if (!fresh.some((t) => t.loud)) return;
    navigator.vibrate?.([180, 80, 180]);
    if (!muted) chime();
    const prev = document.title;
    document.title = `Alarm: ${fresh[0]!.reactorId} | Kairos`;
    const restore = setTimeout(() => (document.title = prev), 8000);
    return () => {
      clearTimeout(restore);
      document.title = prev;
    };
  }, [toasts, muted]);

  return (
    <div className="pointer-events-none fixed right-4 top-16 z-50 flex flex-col items-end gap-2" aria-live="assertive">
      {toasts.length > 0 && (
        <button
          onClick={() => setMuted(!muted)}
          className="pointer-events-auto flex items-center gap-1.5 rounded-full border border-border-subtle bg-bg-elevated px-2.5 py-1 text-[11px] text-text-secondary shadow hover:text-text-primary"
        >
          {muted ? <BellOff size={12} /> : <BellRing size={12} />}
          {muted ? "Alert sound off" : "Alert sound on"}
        </button>
      )}
      <AnimatePresence initial={false}>
        {toasts.map((t) => (
          <ToastCard key={t.key} t={t} />
        ))}
      </AnimatePresence>
    </div>
  );
}
