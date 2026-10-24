import { geoEqualEarth, geoPath } from "d3-geo";
import type { Feature, FeatureCollection, Geometry, MultiPoint } from "geojson";
import { useMemo, useState } from "react";
import { feature } from "topojson-client";
import type { GeometryCollection, Topology } from "topojson-specification";
import world from "world-atlas/countries-110m.json";

import type { PlantRollup } from "@/lib/api/client";
import { stateVar } from "@/lib/format";

const W = 960;
const H = 520;

// Healthy plants get a compact city label; alarmed, watched or hovered ones also show the process.
const isFull = (p: PlantRollup) => p.state !== "normal";
const labelWidth = (p: PlantRollup, full = isFull(p)) => (full ? Math.max(p.city.length, p.process_name.length * 0.82) : p.city.length) * 8.2 + 22;
const labelHeight = (full: boolean) => (full ? 42 : 26);

type Spot = { side: "right" | "left"; dy: number };
// Candidate label positions around a pin, in order of preference.
const SPOTS: Spot[] = [
  { side: "right", dy: 0 },
  { side: "left", dy: 0 },
  { side: "right", dy: 34 },
  { side: "left", dy: 34 },
  { side: "right", dy: -34 },
  { side: "left", dy: -34 },
];

const countries = feature(
  world as unknown as Topology,
  (world as unknown as Topology).objects.countries as GeometryCollection,
) as unknown as FeatureCollection<Geometry>;

/** Bundled world map (no tile server: works offline at the venue), framed on the plants. */
export function PlantMap({ plants, onSelect }: { plants: PlantRollup[]; onSelect: (id: string) => void }) {
  const [hover, setHover] = useState<string | null>(null);
  const { path, project } = useMemo(() => {
    const pts: Feature<MultiPoint> = {
      type: "Feature",
      properties: {},
      geometry: {
        type: "MultiPoint",
        coordinates: plants.map((p) => [p.lon, p.lat]),
      },
    };
    const projection = geoEqualEarth();
    if (plants.length)
      projection.fitExtent(
        [
          [140, 90],
          [W - 140, H - 90],
        ],
        pts,
      );
    return {
      path: geoPath(projection),
      project: (lon: number, lat: number) => projection([lon, lat]) ?? [0, 0],
    };
  }, [plants]);

  // Greedy label placement: alarmed plants first, right side then left; a label
  // that would collide with a pin or a placed label is shown on hover only.
  const labels = useMemo(() => {
    const rank = { alarm: 0, watch: 1, normal: 2 } as const;
    const placed: { x: number; y: number; w: number; h: number }[] = [];
    const pins = plants.map((p) => project(p.lon, p.lat));
    const out: Record<string, Spot | null> = {};
    const hit = (a: { x: number; y: number; w: number; h: number }) =>
      placed.some((b) => a.x < b.x + b.w + 4 && b.x < a.x + a.w + 4 && a.y < b.y + b.h + 4 && b.y < a.y + a.h + 4) ||
      pins.some(([px, py]) => px > a.x - 10 && px < a.x + a.w + 10 && py > a.y - 10 && py < a.y + a.h + 10);
    for (const p of [...plants].sort((a, b) => rank[a.state] - rank[b.state])) {
      const [x, y] = project(p.lon, p.lat);
      const w = labelWidth(p);
      out[p.id] = null;
      const h = labelHeight(isFull(p));
      for (const spot of SPOTS) {
        const box = { x: spot.side === "right" ? x + 14 : x - 14 - w, y: y - 24 + spot.dy, w, h };
        if (box.x >= 0 && box.x + w <= W && box.y >= 0 && box.y + h <= H && !hit(box)) {
          placed.push(box);
          out[p.id] = spot;
          break;
        }
      }
    }
    return out;
  }, [plants, project]);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="h-full w-full" role="img" aria-label="Map of plants">
      <rect width={W} height={H} fill="var(--color-bg-inset)" />
      <g>
        {countries.features.map((f, i) => (
          <path key={i} d={path(f) ?? ""} fill="var(--color-bg-surface)" stroke="var(--color-border-subtle)" strokeWidth={0.6} />
        ))}
      </g>
      {[...plants]
        .sort((a, b) => (a.id === hover ? 1 : b.id === hover ? -1 : 0))
        .map((p) => {
          const [x, y] = project(p.lon, p.lat);
          const active = hover === p.id;
          const full = isFull(p) || active;
          const labelW = labelWidth(p, full);
          const spot = labels[p.id] ?? (active ? { side: x > W / 2 ? "left" : "right", dy: 0 } : null);
          const c = stateVar[p.state];
          return (
            <g
              key={p.id}
              transform={`translate(${x},${y})`}
              className="cursor-pointer"
              onMouseEnter={() => setHover(p.id)}
              onMouseLeave={() => setHover(null)}
              onClick={() => onSelect(p.id)}
              onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && onSelect(p.id)}
              tabIndex={0}
              role="link"
              aria-label={`${p.name}, ${p.state === "normal" ? "healthy" : p.state}`}
            >
              {p.state !== "normal" && (
                <circle r={10} fill={c} opacity={0.35}>
                  <animate attributeName="r" values="10;26;10" dur="2.4s" repeatCount="indefinite" />
                  <animate attributeName="opacity" values="0.35;0;0.35" dur="2.4s" repeatCount="indefinite" />
                </circle>
              )}
              <circle r={active ? 10 : 8} fill={c} stroke="var(--color-bg-base)" strokeWidth={3} />
              {spot && (
                <g
                  transform={`translate(${spot.side === "left" ? -14 - labelW : 14},${spot.dy - 10})`}
                  style={{ pointerEvents: "none" }}
                >
                  <rect
                    x={0}
                    y={-14}
                    rx={8}
                    width={labelW}
                    height={labelHeight(full)}
                    fill="var(--color-bg-elevated)"
                    stroke={active ? c : "var(--color-border-strong)"}
                  />
                  <text x={11} y={3} fontSize="14" fontWeight={600} fill="var(--color-text-primary)">
                    {p.city}
                  </text>
                  {full && (
                    <text x={11} y={20} fontSize="11.5" fill="var(--color-text-secondary)">
                      {p.process_name}
                    </text>
                  )}
                </g>
              )}
            </g>
          );
        })}
    </svg>
  );
}
