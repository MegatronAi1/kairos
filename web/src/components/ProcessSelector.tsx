import * as Menu from "@radix-ui/react-dropdown-menu";
import { Check, ChevronDown, Dna, Sprout } from "lucide-react";
import { useNavigate } from "react-router-dom";

import { FAMILY_LABEL, useProcesses, useProcessStore, useSelectedProcess, type Family } from "@/lib/process";

const ICON: Record<Family, typeof Sprout> = { biomass: Sprout, precision: Dna };

/** Choose which alternative-protein process Kairos is configured for. */
export function ProcessSelector() {
  const q = useProcesses();
  const current = useSelectedProcess();
  const select = useProcessStore((s) => s.select);
  const navigate = useNavigate();
  const list = q.data?.processes ?? [];
  if (!current) return null;
  const Icon = ICON[current.family];

  return (
    <Menu.Root>
      <Menu.Trigger
        className="flex items-center gap-2 rounded-control border border-border-subtle px-3 py-1.5 text-sm hover:border-border-strong"
        aria-label="Choose fermentation process"
      >
        <Icon size={15} style={{ color: "var(--color-accent-500)" }} />
        <span className="text-text-secondary">{FAMILY_LABEL[current.family].replace(" fermentation", "")}</span>
        <span className="font-medium">{current.name}</span>
        <ChevronDown size={14} className="text-text-muted" />
      </Menu.Trigger>
      <Menu.Portal>
        <Menu.Content
          sideOffset={6}
          align="start"
          className="z-50 w-80 rounded-card border border-border-strong bg-bg-elevated p-1.5 shadow-xl"
        >
          {(["biomass", "precision"] as Family[]).map((fam) => {
            const FamIcon = ICON[fam];
            return (
              <Menu.Group key={fam}>
                <Menu.Label className="overline flex items-center gap-1.5 px-2 pb-1 pt-2">
                  <FamIcon size={12} /> {FAMILY_LABEL[fam]}
                </Menu.Label>
                {list
                  .filter((p) => p.family === fam)
                  .map((p) => (
                    <Menu.Item
                      key={p.id}
                      onSelect={() => {
                        select(p.id);
                        navigate("/process");
                      }}
                      className="flex cursor-pointer items-center gap-2 rounded-control px-2 py-1.5 outline-none data-[highlighted]:bg-bg-inset"
                    >
                      <span className="w-4">{p.id === current.id && <Check size={14} style={{ color: "var(--color-accent-500)" }} />}</span>
                      <span className="flex-1">
                        <span className="block text-sm font-medium">{p.name}</span>
                        <span className="block text-xs text-text-muted">
                          {p.example?.company ? `${p.example.company} · ` : ""}
                          {p.organism}
                        </span>
                      </span>
                    </Menu.Item>
                  ))}
              </Menu.Group>
            );
          })}
        </Menu.Content>
      </Menu.Portal>
    </Menu.Root>
  );
}
