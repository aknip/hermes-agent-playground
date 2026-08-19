import { Command as CommandIcon } from "lucide-react";
import type * as React from "react";
import { useTranslation } from "react-i18next";
import { COMMAND_PALETTE_TOGGLE_EVENT } from "@/components/command-palette";
import { NavMain } from "@/components/nav-main";
import { NavProjects } from "@/components/nav-projects";
import { ThemeToggleDropdown } from "@/components/theme-toggle-dropdown";
import { TrialCard } from "@/components/trial-card";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarHeader,
  useSidebar,
} from "@/components/ui/sidebar";
import { VersionDisplay } from "@/components/version-display";
import { WorkspaceSwitcher } from "@/components/workspace-switcher";
import { shortcuts } from "@/constants/shortcuts";
import { useRegisterShortcuts } from "@/hooks/use-keyboard-shortcuts";
import Search from "./search";

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const { toggleSidebar } = useSidebar();
  const { t } = useTranslation();

  useRegisterShortcuts({
    modifierShortcuts: {
      [shortcuts.sidebar.prefix]: {
        [shortcuts.sidebar.toggle]: toggleSidebar,
      },
    },
  });

  return (
    <Sidebar
      collapsible="offcanvas"
      variant="inset"
      className="border-none pt-1.5"
      {...props}
    >
      <SidebarHeader className="pt-1 pb-1.5">
        <WorkspaceSwitcher />
      </SidebarHeader>
      <SidebarContent className="overflow-hidden gap-1 py-1">
        <Search />
        {/* Lücke C — sichtbarer Einstieg zur Command-Palette (nicht nur ⌘K). */}
        <SidebarGroup className="pb-1">
          <button
            type="button"
            className="inline-flex h-8 w-full cursor-pointer items-center rounded-md border border-input bg-background px-2 py-1.5 text-foreground text-sm shadow-xs outline-none transition-[color,box-shadow] placeholder:text-muted-foreground/70 focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
            onClick={() =>
              window.dispatchEvent(
                new CustomEvent(COMMAND_PALETTE_TOGGLE_EVENT),
              )
            }
          >
            <span className="flex grow items-center">
              <CommandIcon
                aria-hidden="true"
                className="-ms-1 me-3 text-muted-foreground/80"
                size={16}
              />
              <span className="font-normal text-muted-foreground/70">
                {t("navigation:sidebar.commandPalette")}
              </span>
            </span>
            <kbd className="-me-0.5 ms-6 inline-flex h-4 max-h-full items-center rounded border border-border/70 bg-background px-1 font-[inherit] font-medium text-[0.625rem] text-muted-foreground/60">
              {shortcuts.palette.prefix}
              {shortcuts.palette.open}
            </kbd>
          </button>
        </SidebarGroup>
        <NavMain />
        <NavProjects />
      </SidebarContent>
      <SidebarFooter>
        <TrialCard />
        <div className="flex items-center justify-between">
          <VersionDisplay />
          <ThemeToggleDropdown />
        </div>
      </SidebarFooter>
    </Sidebar>
  );
}
