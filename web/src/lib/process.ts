import { useQuery } from "@tanstack/react-query";
import { create } from "zustand";

import { apiUrl } from "@/lib/api/client";
import type { Provenance } from "@/lib/api/types";
import { authToken } from "@/lib/session";

export type Family = "biomass" | "precision";
export type ReactorKind = "airlift" | "stirred_tank" | "photobioreactor" | "gas_fermenter";

export interface Range {
  min?: number;
  max?: number;
  value?: number;
  unit?: string;
  provenance: Provenance;
  source: string;
}

export interface ProcessSummary {
  id: string;
  family: Family;
  name: string;
  product: string;
  example: { company: string; product_name?: string; url?: string };
  organism: string;
  reactor: ReactorKind;
  mode: string;
  benchmark_fit: "high" | "medium" | "low" | null;
}

export interface ProcessDetail extends ProcessSummary {
  naming_note?: string | null;
  organism_type: string;
  reactor_note?: string;
  product_location: string;
  carbon_source?: string;
  nitrogen_source?: string;
  gases?: string[];
  light?: boolean;
  setpoints: Record<string, Range>;
  phases: { name: string; duration?: string; goal: string; controls: { param: string; action: string }[] }[];
  control_loops: { measure: string; actuator: string; purpose: string }[];
  critical_risks: string[];
  energy_hotspots: string[];
  kairos: {
    yield_signal: string;
    fault_signatures: string[];
    energy_levers: string[];
    benchmark_fit: "high" | "medium" | "low";
    benchmark_fit_why: string;
  };
  sources: { title: string; url: string }[];
}

const KEY = "kairos.process";
const read = (): string | null => {
  try {
    return localStorage.getItem(KEY);
  } catch {
    return null;
  }
};

interface ProcessState {
  selected: string | null;
  select: (id: string) => void;
}

export const useProcessStore = create<ProcessState>((set) => ({
  selected: read(),
  select: (id) => {
    try {
      localStorage.setItem(KEY, id);
    } catch {
      /* per-viewer convenience */
    }
    set({ selected: id });
  },
}));

async function get<T>(path: string): Promise<T> {
  const token = authToken();
  const res = await fetch(apiUrl(path), { headers: token ? { Authorization: `Bearer ${token}` } : {} });
  if (!res.ok) throw new Error(`${res.status}`);
  return (await res.json()) as T;
}

export const useProcesses = () =>
  useQuery({
    queryKey: ["processes"],
    queryFn: () => get<{ notes: string[]; processes: ProcessSummary[] }>("/processes"),
    staleTime: 5 * 60_000,
  });

export const useProcess = (id: string | null) =>
  useQuery({
    queryKey: ["process", id],
    queryFn: () => get<ProcessDetail>(`/processes/${id}`),
    enabled: !!id,
    staleTime: 5 * 60_000,
  });

/** The selected process, defaulting to the first in the catalog. */
export function useSelectedProcess(): ProcessSummary | null {
  const list = useProcesses().data?.processes ?? [];
  const selected = useProcessStore((s) => s.selected);
  return list.find((p) => p.id === selected) ?? list[0] ?? null;
}

export const FAMILY_LABEL: Record<Family, string> = {
  biomass: "Biomass fermentation",
  precision: "Precision fermentation",
};

export const FIT_LABEL = { high: "Strong match", medium: "Partial match", low: "Weak match" } as const;
