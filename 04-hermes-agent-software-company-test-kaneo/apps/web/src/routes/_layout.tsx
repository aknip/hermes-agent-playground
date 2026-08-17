import { createFileRoute, Outlet } from "@tanstack/react-router";
import { useCallback, useState } from "react";
import CommandPalette from "@/components/command-palette";
import SearchCommandMenu from "@/components/search-command-menu";
import { SearchDialogProvider } from "@/components/search-dialog-context";

// layout for the main app
export const Route = createFileRoute("/_layout")({
  component: RouteComponent,
});

function RouteComponent() {
  const [searchOpen, setSearchOpen] = useState(false);
  const openSearch = useCallback(() => setSearchOpen(true), []);
  return (
    <SearchDialogProvider openSearch={openSearch}>
      <Outlet />
      <CommandPalette />
      <SearchCommandMenu open={searchOpen} setOpen={setSearchOpen} />
    </SearchDialogProvider>
  );
}
