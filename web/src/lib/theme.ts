import { useEffect, useSyncExternalStore } from "react";

export type ThemePref = "system" | "dark" | "light";
export type Theme = "dark" | "light";

const KEY = "kairos.theme";
const listeners = new Set<() => void>();

function readPref(): ThemePref {
  try {
    const v = localStorage.getItem(KEY);
    return v === "dark" || v === "light" || v === "system" ? v : "dark";
  } catch {
    return "dark"; // storage blocked: dark is the primary theme
  }
}

const media = () => window.matchMedia?.("(prefers-color-scheme: light)");

export function resolve(pref: ThemePref): Theme {
  if (pref !== "system") return pref;
  return media()?.matches ? "light" : "dark";
}

function apply(pref: ThemePref) {
  document.documentElement.dataset.theme = resolve(pref);
  listeners.forEach((l) => l());
}

export function setThemePref(pref: ThemePref) {
  try {
    localStorage.setItem(KEY, pref);
  } catch {
    /* per-viewer convenience only */
  }
  apply(pref);
}

const subscribe = (l: () => void) => {
  listeners.add(l);
  return () => listeners.delete(l);
};

export function useThemePref(): ThemePref {
  return useSyncExternalStore(subscribe, readPref, () => "dark");
}

export function useTheme(): Theme {
  return useSyncExternalStore(
    subscribe,
    () => (document.documentElement.dataset.theme === "light" ? "light" : "dark"),
    () => "dark",
  );
}

/** Follows OS changes while the preference is "system". */
export function useThemeSync() {
  useEffect(() => {
    apply(readPref());
    const m = media();
    const onChange = () => readPref() === "system" && apply("system");
    m?.addEventListener("change", onChange);
    return () => m?.removeEventListener("change", onChange);
  }, []);
}

/** Read a token at runtime (for WebGL materials that cannot use CSS variables). */
export const cssToken = (name: string, fallback: string) =>
  getComputedStyle(document.documentElement).getPropertyValue(name).trim() || fallback;
