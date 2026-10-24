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
      geometry: { type: "MultiPoint", coordinates: plants.map((p) => [p.lon, p.lat]) },
    };
    const projection = geoEqualEarth();
    if (plants.length) projection.fitExtent([[140, 90], [W - 140, H - 90]], pts);
    return { path: geoPath(projection), project: (lon: number, lat: number) => projection([lon, lat]) ?? [0, 0] };
  }, [plants]);

  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="h-full w-full" role="img" aria-label="Map of plants">
      <rect width={W} height={H} fill="var(--color-bg-inset)" />
      <g>
        {countries.features.map((f, i) => (
          <path key={i} d={path(f) ?? ""} fill="var(--color-bg-surface)" stroke="var(--color-border-subtle)" strokeWidth={0.6} />
        ))}
      </g>
      {plants.map((p, i) => {
        const [x, y] = project(p.lon, p.lat);
        const labelW = Math.max(p.city.length, p.process_name.length * 0.82) * 8.2 + 22;
        // Flip the label to the left when an earlier pin sits close by (avoids overlap).
        const crowded = plants.slice(0, i).some((q) => {
          const [qx, qy] = project(q.lon, q.lat);
          return Math.abs(qx - x) < labelW + 30 && Math.abs(qy - y) < 46;
        });
        const c = stateVar[p.state];
        const active = hover === p.id;
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
            <g transform={crowded ? `translate(${-14 - labelW},-10)` : "translate(14,-10)"}>
              <rect
                x={0}
                y={-14}
                rx={8}
                width={labelW}
                height={42}
                fill="var(--color-bg-elevated)"
                stroke={active ? c : "var(--color-border-strong)"}
              />
              <text x={11} y={3} fontSize="14" fontWeight={600} fill="var(--color-text-primary)">
                {p.city}
              </text>
              <text x={11} y={20} fontSize="11.5" fill="var(--color-text-secondary)">
                {p.process_name}
              </text>
            </g>
          </g>
        );
      })}
    </svg>
  );
}
