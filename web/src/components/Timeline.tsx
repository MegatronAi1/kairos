import { Pause, Play, RotateCcw } from "lucide-react";
import { useRef } from "react";

import { Tip } from "@/components/primitives";
import { api } from "@/lib/api/client";
import { fmt, stateVar } from "@/lib/format";
import type { ReactorLive } from "@/lib/store/live";
import { useLive } from "@/lib/store/live";

const SPEEDS = [0.5, 1, 2, 5, 10, 25];

/** Flight recorder: batch progress with alarm markers; play, pause, speed, scrub. */
export function TimelineScrubber({ r }: { r: ReactorLive }) {
  const bar = useRef<HTMLDivElement>(null);
  const patch = useLive((s) => s.patch);
  const t = r.tick?.t_h ?? 0;
  const frac = r.tEndH > 0 ? Math.min(1, t / r.tEndH) : 0;

  const seekTo = (clientX: number) => {
    const rect = bar.current?.getBoundingClientRect();
    if (!rect) return;
    const p = Math.min(1, Math.max(0, (clientX - rect.left) / rect.width));
    void api.control(r.id, "seek", { progress: p });
  };

  const toggle = async () => {
    const res = await api.control(r.id, r.running ? "pause" : "start");
    patch(r.id, { running: res.running });
  };

  return (
    <div className="flex items-center gap-3">
      <button
        onClick={() => void toggle()}
        aria-label={r.running ? "Pause replay" : "Play replay"}
        className="flex h-9 w-9 items-center justify-center rounded-control border border-border-strong hover:bg-bg-elevated"
      >
        {r.running ? <Pause size={16} /> : <Play size={16} />}
      </button>
      <button
        onClick={() => void api.control(r.id, "restart").then((res) => patch(r.id, { running: res.running }))}
        aria-label="Restart batch"
        className="flex h-9 w-9 items-center justify-center rounded-control border border-border-subtle text-text-secondary hover:bg-bg-elevated"
      >
        <RotateCcw size={15} />
      </button>
      <div className="flex-1">
        <div
          ref={bar}
          role="slider"
          tabIndex={0}
          aria-label="Batch timeline"
          aria-valuemin={0}
          aria-valuemax={Math.round(r.tEndH)}
          aria-valuenow={Math.round(t)}
          onClick={(e) => seekTo(e.clientX)}
          onKeyDown={(e) => {
            const step = e.key === "ArrowRight" ? 0.02 : e.key === "ArrowLeft" ? -0.02 : 0;
            if (step) void api.control(r.id, "seek", { progress: Math.min(1, Math.max(0, frac + step)) });
          }}
          className="relative h-6 cursor-pointer"
        >
          <div className="absolute inset-x-0 top-1/2 h-1.5 -translate-y-1/2 rounded-full bg-bg-inset" />
          <div
            className="absolute left-0 top-1/2 h-1.5 -translate-y-1/2 rounded-full bg-accent-600"
            style={{ width: `${frac * 100}%` }}
          />
          {r.alarms
            .filter((a) => a.state !== "normal")
            .map((a) => (
              <Tip key={`${a.ts}-${a.state}`} content={`${a.state === "alarm" ? "Alarm" : "Watch"} at ${fmt(a.t_h)} h`}>
                <span
                  className="absolute top-0 h-6 w-[3px] -translate-x-1/2 rounded-sm"
                  style={{ left: `${(a.t_h / r.tEndH) * 100}%`, background: stateVar[a.state] }}
                />
              </Tip>
            ))}
          <span
            className="absolute top-1/2 h-3.5 w-3.5 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-bg-base bg-accent-500"
            style={{ left: `${frac * 100}%` }}
          />
        </div>
        <div className="num mt-0.5 flex justify-between text-xs text-text-muted">
          <span>0 h</span>
          <span className="text-text-secondary">
            {fmt(t)} h · {Math.round(frac * 100)}%
          </span>
          <span>{fmt(r.tEndH, 0)} h</span>
        </div>
      </div>
      <label className="flex items-center gap-2 text-xs text-text-secondary">
        Speed
        <select
          value={r.speed}
          onChange={(e) => {
            const v = Number(e.target.value);
            patch(r.id, { speed: v });
            void api.control(r.id, "speed", { speed_h_per_s: v });
          }}
          className="num rounded-control border border-border-subtle bg-bg-inset px-2 py-1 text-sm text-text-primary"
        >
          {SPEEDS.map((s) => (
            <option key={s} value={s}>
              {s} h/s
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}
