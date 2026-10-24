import { Html } from "@react-three/drei";
import { useFrame } from "@react-three/fiber";
import { useMemo, useRef, useState } from "react";
import * as THREE from "three";

import type { HealthState, TickEvent } from "@/lib/api/types";
import { fmt, valueOf } from "@/lib/format";
import { cssToken, useTheme } from "@/lib/theme";

/*
 * Bioreactor twin. Every visual is bound to data:
 *   impeller speed  <- agitation rpm         bubbles      <- aeration
 *   broth hue       <- pH vs setpoint 6.5    turbidity    <- lab biomass
 *   inner glow      <- production rate       liquid level <- broth volume
 *   DO ring         <- dissolved oxygen      rim light    <- health state (one pulse on alarm)
 */

const TOKENS = {
  accent: new THREE.Color("#2DD4BF"),
  healthy: new THREE.Color("#34D399"),
  watch: new THREE.Color("#F5A524"),
  alarm: new THREE.Color("#F43F5E"),
  steel: new THREE.Color("#9AA6B2"),
  glass: new THREE.Color("#BFE9F2"),
};
const STATE_COLOR: Record<HealthState, THREE.Color> = {
  normal: TOKENS.healthy,
  watch: TOKENS.watch,
  alarm: TOKENS.alarm,
};

const R = 1; // vessel radius
const H = 3.2; // vessel height
const MAX_BUBBLES = 160;
const CRITICAL_DO_PCT = 25; // ml/config/constants.yaml critical_do_fraction (assumed)

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

interface Props {
  tick: TickEvent | null;
  state: HealthState;
  position?: [number, number, number];
  scale?: number;
  interactive?: boolean;
  onSelect?: () => void;
  label?: React.ReactNode;
}

type Part = "impeller" | "do" | "broth" | "sparger" | null;

export function Reactor({ tick, state, position = [0, 0, 0], scale = 1, interactive = true, onSelect, label }: Props) {
  const impeller = useRef<THREE.Group>(null);
  const bubbles = useRef<THREE.InstancedMesh>(null);
  const rim = useRef<THREE.PointLight>(null);
  const glow = useRef<THREE.PointLight>(null);
  const brothMat = useRef<THREE.MeshPhysicalMaterial>(null);
  const brothMesh = useRef<THREE.Mesh>(null);
  const pulse = useRef(0);
  const lastState = useRef<HealthState>(state);
  const [hover, setHover] = useState<Part>(null);
  const theme = useTheme();
  const ringTrack = useMemo(() => cssToken("--color-border-subtle", "#1F2933"), [theme]);

  const rpm = valueOf(tick, "rpm") ?? 100;
  const aeration = valueOf(tick, "aeration") ?? 50;
  const ph = valueOf(tick, "ph") ?? 6.5;
  const doPct = valueOf(tick, "do_pct") ?? 70;
  const volume = valueOf(tick, "volume_l") ?? 75000;
  const biomass = valueOf(tick, "biomass_lab") ?? 0;
  const prodRate = valueOf(tick, "production_rate") ?? 0;
  const agitatorKw = valueOf(tick, "agitator_kw");

  // IndPenSim working volume spans ~56-96 m3; map onto 45-92% of the vessel height.
  const level = (0.45 + clamp((volume - 56000) / 40000, 0, 1) * 0.47) * H;
  const turbidity = clamp(biomass / 30, 0, 1);
  const bubbleCount = Math.round(clamp(aeration / 80, 0.1, 1) * MAX_BUBBLES);

  // Broth hue: teal at pH 6.5, warmer as pH drops, bluer as it rises (narrow range).
  const brothColor = useMemo(() => {
    const dev = clamp((ph - 6.5) / 0.4, -1, 1);
    const c = new THREE.Color("#1FA89A");
    c.offsetHSL(dev * 0.06, 0, -turbidity * 0.12);
    return c;
  }, [ph, turbidity]);

  // Per-bubble seeds (stable).
  const seeds = useMemo(
    () =>
      Array.from({ length: MAX_BUBBLES }, (_, i) => ({
        a: (i * 2.399) % (Math.PI * 2),
        r: 0.15 + ((i * 7919) % 100) / 100 * 0.7,
        phase: ((i * 104729) % 1000) / 1000,
        size: 0.018 + ((i * 31) % 10) / 10 * 0.02,
      })),
    [],
  );
  const tmp = useMemo(() => new THREE.Object3D(), []);

  useFrame((_, dt) => {
    const t = performance.now() / 1000;
    if (impeller.current) impeller.current.rotation.y += (rpm / 60) * Math.PI * 2 * dt * 0.35;
    if (bubbles.current) {
      const speed = 0.35 + aeration / 120;
      for (let i = 0; i < MAX_BUBBLES; i++) {
        const s = seeds[i]!;
        if (i >= bubbleCount) {
          tmp.scale.setScalar(0);
        } else {
          const y = ((t * speed * 0.25 + s.phase) % 1) * level;
          const wobble = Math.sin(t * 3 + s.a * 5) * 0.03;
          tmp.position.set(Math.cos(s.a + y) * s.r * R * 0.85 + wobble, 0.15 + y, Math.sin(s.a + y) * s.r * R * 0.85);
          tmp.scale.setScalar(s.size * (1 + y / H));
        }
        tmp.updateMatrix();
        bubbles.current.setMatrixAt(i, tmp.matrix);
      }
      bubbles.current.instanceMatrix.needsUpdate = true;
    }
    if (lastState.current !== state) {
      if (state === "alarm") pulse.current = 1; // one pulse on alarm entry, then calm
      lastState.current = state;
    }
    pulse.current = Math.max(0, pulse.current - dt * 0.8);
    if (rim.current) {
      rim.current.color.lerp(STATE_COLOR[state], 0.08);
      const base = state === "normal" ? 1.2 : 3.2;
      rim.current.intensity = base + pulse.current * 14;
    }
    if (glow.current) glow.current.intensity = 0.4 + clamp(prodRate / 0.25, 0, 1) * 2.6;
    if (brothMat.current) brothMat.current.color.lerp(brothColor, 0.05);
    if (brothMesh.current) {
      brothMesh.current.scale.y += (level - brothMesh.current.scale.y) * 0.05;
      brothMesh.current.position.y = 0.08 + brothMesh.current.scale.y / 2;
    }
  });

  const hoverProps = (part: Part) =>
    interactive
      ? {
          onPointerOver: (e: { stopPropagation: () => void }) => {
            e.stopPropagation();
            setHover(part);
            document.body.style.cursor = onSelect ? "pointer" : "default";
          },
          onPointerOut: () => {
            setHover(null);
            document.body.style.cursor = "default";
          },
        }
      : {};

  const doColor = doPct < CRITICAL_DO_PCT ? TOKENS.alarm : doPct < CRITICAL_DO_PCT * 1.6 ? TOKENS.watch : TOKENS.accent;
  const doArc = clamp(doPct / 100, 0.02, 1) * Math.PI * 2;

  const hoverText: Record<Exclude<Part, null>, string> = {
    impeller: `${fmt(rpm, 0)} rpm${agitatorKw !== null ? ` · ${fmt(agitatorKw, 0)} kW` : ""}`,
    do: `DO ${fmt(doPct, 1)}% sat`,
    broth: `pH ${fmt(ph, 2)} · ${fmt(volume / 1000, 1)} m³ · biomass ${fmt(biomass, 1)} g/L (lab)`,
    sparger: `Aeration ${fmt(aeration, 0)} m³/min`,
  };

  return (
    <group position={position} scale={scale} onClick={onSelect}>
      {/* Base and head (stainless) */}
      <mesh position={[0, 0, 0]}>
        <cylinderGeometry args={[R * 1.04, R * 1.08, 0.16, 48]} />
        <meshStandardMaterial color={TOKENS.steel} metalness={0.55} roughness={0.35} />
      </mesh>
      <mesh position={[0, H, 0]}>
        <sphereGeometry args={[R * 1.04, 48, 16, 0, Math.PI * 2, 0, Math.PI / 2]} />
        <meshStandardMaterial color={TOKENS.steel} metalness={0.55} roughness={0.35} />
      </mesh>
      {/* Motor */}
      <mesh position={[0, H + R * 1.04 + 0.12, 0]}>
        <cylinderGeometry args={[0.18, 0.18, 0.36, 24]} />
        <meshStandardMaterial color="#2E3A47" metalness={0.6} roughness={0.4} />
      </mesh>

      {/* Glass shell */}
      <mesh position={[0, H / 2, 0]} renderOrder={2}>
        <cylinderGeometry args={[R, R, H, 64, 1, true]} />
        <meshPhysicalMaterial
          color={TOKENS.glass}
          transparent
          opacity={0.12}
          roughness={0.05}
          metalness={0}
          clearcoat={1}
          side={THREE.DoubleSide}
          depthWrite={false}
        />
      </mesh>

      {/* Broth */}
      <mesh ref={brothMesh} position={[0, 0.08 + level / 2, 0]} scale={[1, level, 1]} {...hoverProps("broth")}>
        <cylinderGeometry args={[R * 0.97, R * 0.97, 1, 48]} />
        <meshPhysicalMaterial
          ref={brothMat}
          color={brothColor}
          transparent
          opacity={0.38 + turbidity * 0.4}
          roughness={0.4}
          depthWrite={false}
          emissive={TOKENS.accent}
          emissiveIntensity={0.05 + clamp(prodRate / 0.25, 0, 1) * 0.25}
        />
      </mesh>

      {/* Baffles */}
      {[0, 1, 2, 3].map((i) => (
        <mesh key={i} position={[Math.cos((i * Math.PI) / 2) * R * 0.9, H / 2, Math.sin((i * Math.PI) / 2) * R * 0.9]} rotation={[0, -(i * Math.PI) / 2, 0]}>
          <boxGeometry args={[0.03, H * 0.9, 0.1]} />
          <meshStandardMaterial color={TOKENS.steel} metalness={0.8} roughness={0.35} transparent opacity={0.7} />
        </mesh>
      ))}

      {/* Shaft + Rushton impellers */}
      <mesh position={[0, H * 0.55, 0]}>
        <cylinderGeometry args={[0.035, 0.035, H * 1.05, 12]} />
        <meshStandardMaterial color={TOKENS.steel} metalness={0.9} roughness={0.25} />
      </mesh>
      <group ref={impeller} {...hoverProps("impeller")}>
        {[0.55, 1.6].map((y) => (
          <group key={y} position={[0, y, 0]}>
            <mesh>
              <cylinderGeometry args={[0.24, 0.24, 0.025, 24]} />
              <meshStandardMaterial color={TOKENS.steel} metalness={0.9} roughness={0.25} />
            </mesh>
            {[0, 1, 2, 3, 4, 5].map((k) => (
              <mesh key={k} position={[Math.cos((k * Math.PI) / 3) * 0.3, 0, Math.sin((k * Math.PI) / 3) * 0.3]} rotation={[0, -(k * Math.PI) / 3, 0]}>
                <boxGeometry args={[0.14, 0.11, 0.015]} />
                <meshStandardMaterial
                  color={hover === "impeller" ? TOKENS.accent : TOKENS.steel}
                  metalness={0.8}
                  roughness={0.3}
                />
              </mesh>
            ))}
          </group>
        ))}
      </group>

      {/* Sparger ring */}
      <mesh position={[0, 0.2, 0]} rotation={[Math.PI / 2, 0, 0]} {...hoverProps("sparger")}>
        <torusGeometry args={[R * 0.55, 0.025, 8, 48]} />
        <meshStandardMaterial color={hover === "sparger" ? TOKENS.accent : TOKENS.steel} metalness={0.8} roughness={0.3} />
      </mesh>

      {/* Bubbles */}
      <instancedMesh ref={bubbles} args={[undefined, undefined, MAX_BUBBLES]}>
        <sphereGeometry args={[1, 8, 8]} />
        <meshStandardMaterial color="#E6EDF3" transparent opacity={0.55} roughness={0.1} />
      </instancedMesh>

      {/* DO ring gauge at mid-height: track + filled arc */}
      <group position={[0, H * 0.5, 0]} rotation={[Math.PI / 2, 0, 0]} {...hoverProps("do")}>
        <mesh>
          <torusGeometry args={[R * 1.12, 0.018, 8, 96]} />
          <meshBasicMaterial color={ringTrack} />
        </mesh>
        <mesh rotation={[0, 0, Math.PI / 2]}>
          <torusGeometry args={[R * 1.12, 0.032, 8, 96, doArc]} />
          <meshBasicMaterial color={doColor} toneMapped={false} />
        </mesh>
      </group>

      {/* Lights: production glow inside, health rim light behind */}
      <pointLight ref={glow} position={[0, H * 0.35, 0]} color={TOKENS.accent} distance={3} intensity={1} />
      <pointLight ref={rim} position={[0, H * 0.6, -1.8]} color={STATE_COLOR[state]} distance={6} intensity={1.5} />

      {hover && interactive && (
        <Html position={[0, H + 0.4, 0]} center distanceFactor={8} zIndexRange={[20, 0]}>
          <div className="num whitespace-nowrap rounded-control border border-border-strong bg-bg-elevated px-3 py-1.5 text-sm text-text-primary">
            {hoverText[hover]}
          </div>
        </Html>
      )}
      {label}
    </group>
  );
}
