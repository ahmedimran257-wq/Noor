"use client";

import { usePathname, useRouter } from "next/navigation";
import { createContext, useContext, useEffect, useMemo, useRef, useState, useTransition } from "react";

type NavigationState = {
  open: boolean;
  setOpen: (open: boolean) => void;
  refreshing: boolean;
  refresh: () => void;
};

const NavigationContext = createContext<NavigationState | null>(null);

// Data is re-read on demand: the refresh button, after a decision (server
// actions revalidate), or when the tab comes back after being away long
// enough for queues to have moved. No background polling.
const staleAfterMs = 5 * 60 * 1000;

function isEditing() {
  const element = document.activeElement;
  if (!element) return false;
  const tag = element.tagName.toLowerCase();
  if (tag === "textarea" || tag === "select") return true;
  if (tag === "input") return (element as HTMLInputElement).type !== "checkbox";
  return element.getAttribute("contenteditable") === "true";
}

export function NavigationProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [refreshing, startTransition] = useTransition();
  const renderedAt = useRef(0);

  useEffect(() => {
    renderedAt.current = Date.now();
  }, [pathname]);

  useEffect(() => {
    if (renderedAt.current === 0) renderedAt.current = Date.now();
    const onVisible = () => {
      if (document.hidden || isEditing()) return;
      if (Date.now() - renderedAt.current < staleAfterMs) return;
      renderedAt.current = Date.now();
      startTransition(() => router.refresh());
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [router]);

  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  const value = useMemo<NavigationState>(() => ({
    open,
    setOpen,
    refreshing,
    refresh: () => {
      renderedAt.current = Date.now();
      startTransition(() => router.refresh());
    },
  }), [open, refreshing, router]);

  return <NavigationContext.Provider value={value}>{children}</NavigationContext.Provider>;
}

export function useNavigation() {
  const value = useContext(NavigationContext);
  if (!value) throw new Error("useNavigation must be used inside NavigationProvider");
  return value;
}
