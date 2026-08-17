import { createContext, type ReactNode, useContext } from "react";

type SearchDialogContextValue = {
  openSearch: () => void;
};

const SearchDialogContext = createContext<SearchDialogContextValue | null>(
  null,
);

/**
 * Reicht den Öffnen-Handler der globalen Such-Dialog-Instanz (eine Instanz,
 * siehe routes/_layout.tsx) an den Header-Sucheinstieg weiter, damit genau ein
 * Dialog im DOM liegt — egal ob er vom Header, der Sidebar oder dem
 * Kurzbefehl "/" geöffnet wird.
 */
export function SearchDialogProvider({
  openSearch,
  children,
}: {
  openSearch: () => void;
  children: ReactNode;
}) {
  return (
    <SearchDialogContext.Provider value={{ openSearch }}>
      {children}
    </SearchDialogContext.Provider>
  );
}

export function useSearchDialog(): SearchDialogContextValue {
  const ctx = useContext(SearchDialogContext);
  if (!ctx) {
    throw new Error(
      "useSearchDialog must be used within a SearchDialogProvider",
    );
  }
  return ctx;
}
