"use client";

import { SearchIcon } from "lucide-react";
import { useTranslation } from "react-i18next";
import { useSearchDialog } from "@/components/search-dialog-context";
import { shortcuts } from "@/constants/shortcuts";

/**
 * Sichtbarer globaler Sucheinstieg (R1-F1) im persistenten Header, der auf
 * jeder authentifizierten Seite oben liegt — unabhängig vom Zustand der
 * Sidebar. Er öffnet dieselbe Such-Dialog-Instanz wie der Sidebar-Einstieg
 * und der Kurzbefehl "/" (keine Navigation, keine zweite Dialog-Instanz).
 */
export default function HeaderSearch() {
  const { t } = useTranslation();
  const { openSearch } = useSearchDialog();

  return (
    <button
      type="button"
      onClick={openSearch}
      aria-label={t("navigation:search.inputPlaceholder")}
      title={t("navigation:search.inputPlaceholder")}
      className="inline-flex h-8 min-w-0 max-w-56 shrink-0 items-center gap-2 rounded-md border border-input bg-background px-2.5 py-1.5 text-sm text-foreground shadow-xs outline-none transition-[color,box-shadow] placeholder:text-muted-foreground/70 hover:bg-muted/40 focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
    >
      <SearchIcon
        aria-hidden="true"
        className="size-4 shrink-0 text-muted-foreground/80"
      />
      <span className="grow truncate text-left font-normal text-muted-foreground/70">
        {t("navigation:search.inputPlaceholder")}
      </span>
      <kbd className="inline-flex h-4 shrink-0 items-center rounded border border-border/70 bg-background px-1 font-[inherit] font-medium text-[0.625rem] text-muted-foreground/60">
        {shortcuts.search.prefix}
      </kbd>
    </button>
  );
}
