import { ContactShadows, Environment, Lightformer, OrbitControls } from "@react-three/drei";
import { Canvas } from "@react-three/fiber";
import { Suspense, useMemo, type ReactNode } from "react";

import { StatusPill } from "@/components/primitives";
import type { HealthState, TickEvent } from "@/lib/api/types";
import { fmt, stateVar, valueOf } from "@/lib/format";
import type { ReactorLive } from "@/lib/store/live";
import { cssToken, useTheme } from "@/lib/theme";

import { Reactor } from "./Reactor";

function hasWebGL(): boolean {
  try {
    const c = document.createElement("canvas");
    return !!(c.getContext("webgl2") ?? c.getContext("webgl"));
  } catch {
    return false;
  }
}

/** Dark control-room stage. Environment built from local light formers (no network fetch). */
export function Stage({
  children,
  camera,
  orbit,
  fallback,
}: {
  children: ReactNode;
  camera: [number, number, number];
  orbit: { autoRotate?: boolean; target: [number, number, number]; minDistance: number; maxDistance: number };
  fallback: ReactNode;
}) {
  const webgl = useMemo(hasWebGL, []);
  const theme = useTheme();
  const bg = useMemo(() => cssToken("--color-bg-base", "#0A0E13"), [theme]);
  if (!webgl) return <>{fallback}</>;
  return (
    <Canvas
      dpr={[1, 2]}
      camera={{ position: camera, fov: 38 }}
      gl={{ antialias: true, powerPreference: "high-performance" }}
      frameloop="always"
      style={{ background: "transparent" }}
    >
      <color attach="background" args={[bg]} />
      <fog attach="fog" args={[bg, 14, 30]} />
      <ambientLight intensity={theme === "light" ? 0.7 : 0.25} />
      <directionalLight position={[4, 8, 6]} intensity={0.9} />
      <Suspense fallback={null}>
        <Environment resolution={64}>
          <Lightformer form="rect" intensity={2} position={[0, 5, -6]} scale={[10, 3, 1]} color="#CFE9F0" />
          <Lightformer form="rect" intensity={0.8} position={[-6, 2, 2]} scale={[3, 6, 1]} color="#2DD4BF" />
          <Lightformer form="rect" intensity={0.6} position={[6, 2, 2]} scale={[3, 6, 1]} color="#60A5FA" />
        </Environment>
        {children}
        <ContactShadows position={[0, -0.08, 0]} opacity={0.5} scale={24} blur={2.4} far={4} />
      </Suspense>
      <OrbitControls
        makeDefault
        enablePan={false}
        autoRotate={orbit.autoRotate}
        autoRotateSpeed={0.35}
        target={orbit.target}
        minDistance={orbit.minDistance}
        maxDistance={orbit.maxDistance}
        minPolarAngle={0.5}
        maxPolarAngle={Math.PI / 2.05}
      />
    </Canvas>
  );
}

export function FleetScene({ reactors, onSelect }: { reactors: ReactorLive[]; onSelect: (id: string) => void }) {
  const gap = 3.4;
  const offset = ((reactors.length - 1) * gap) / 2;
  return (
    <Stage
      camera={[0, 3.4, 10.2]}
      orbit={{ autoRotate: false, target: [0, 1.9, 0], minDistance: 8, maxDistance: 20 }}
      fallback={<FleetFallback reactors={reactors} onSelect={onSelect} />}
    >
      {reactors.map((r, i) => (
        <Reactor
          key={r.id}
          tick={r.tick}
          state={r.state}
          position={[i * gap - offset, 0, 0]}
          onSelect={() => onSelect(r.id)}
        />
      ))}
    </Stage>
  );
}

export function ReactorScene({ tick, state }: { tick: TickEvent | null; state: HealthState }) {
  return (
    <Stage
      camera={[3.6, 2.7, 7.0]}
      orbit={{ autoRotate: true, target: [0, 1.95, 0], minDistance: 4.2, maxDistance: 12 }}
      fallback={<VesselSvg tick={tick} state={state} />}
    >
      <Reactor tick={tick} state={state} />
    </Stage>
  );
}

/* --- WebGL-unavailable fallback: 2D cutaway with the same bindings --------- */

function FleetFallback({ reactors, onSelect }: { reactors: ReactorLive[]; onSelect: (id: string) => void }) {
  return (
    <div className="flex h-full items-center justify-center gap-8">
      {reactors.map((r) => (
        <button key={r.id} onClick={() => onSelect(r.id)} className="flex flex-col items-center gap-2">
          <VesselSvg tick={r.tick} state={r.state} small />
          <span className="num text-lg">{r.id}</span>
          <StatusPill state={r.state} compact />
        </button>
      ))}
    </div>
  );
}

export function VesselSvg({ tick, state, small = false }: { tick: TickEvent | null; state: HealthState; small?: boolean }) {
  const doPct = valueOf(tick, "do_pct") ?? 70;
  const volume = valueOf(tick, "volume_l") ?? 75000;
  const level = Math.min(0.95, Math.max(0.15, (volume - 50000) / 50000));
  const w = small ? 90 : 200;
  const h = small ? 150 : 330;
  return (
    <svg width={w} height={h} viewBox="0 0 100 165" role="img" aria-label={`Vessel cutaway, DO ${fmt(doPct, 0)}%`}>
      <rect x="15" y="15" width="70" height="140" rx="12" fill="none" stroke={stateVar[state]} strokeWidth="1.5" />
      <rect x="17" y={155 - 136 * level} width="66" height={136 * level - 2} rx="10" fill="var(--color-accent-600)" opacity="0.35" />
      <line x1="50" y1="5" x2="50" y2="125" stroke="var(--color-text-secondary)" strokeWidth="1.5" />
      <rect x="36" y="118" width="28" height="5" fill="var(--color-text-secondary)" />
      <circle cx="50" cy="85" r="44" fill="none" stroke="var(--color-border-subtle)" strokeWidth="2" />
      <circle
        cx="50"
        cy="85"
        r="44"
        fill="none"
        stroke="var(--color-accent-500)"
        strokeWidth="3"
        strokeDasharray={`${(doPct / 100) * 276} 276`}
        transform="rotate(-90 50 85)"
      />
    </svg>
  );
}
