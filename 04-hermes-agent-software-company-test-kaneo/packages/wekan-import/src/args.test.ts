import { describe, expect, it } from "vitest";
import { DEFAULT_KANEO_URL, parseArgs } from "./args.js";

describe("parseArgs", () => {
  it("returns defaults for an empty argv", () => {
    const parsed = parseArgs([]);

    expect(parsed.file).toBeUndefined();
    expect(parsed.projectName).toBeUndefined();
    expect(parsed.dryRun).toBe(false);
    expect(parsed.help).toBe(false);
    expect(parsed.version).toBe(false);
  });

  it("parses space-separated values", () => {
    const parsed = parseArgs([
      "--file",
      "export.json",
      "--project-name",
      "Marketing",
    ]);

    expect(parsed.file).toBe("export.json");
    expect(parsed.projectName).toBe("Marketing");
  });

  it("parses inline --flag=value form", () => {
    const parsed = parseArgs(["--kaneo-api-key=kaneo_abc"]);

    expect(parsed.kaneoApiKey).toBe("kaneo_abc");
  });

  it("parses boolean flags and their short forms", () => {
    const parsed = parseArgs(["--dry-run", "-h"]);

    expect(parsed.dryRun).toBe(true);
    expect(parsed.help).toBe(true);
  });

  it("parses help and version flags", () => {
    expect(parseArgs(["--help"]).help).toBe(true);
    expect(parseArgs(["-v"]).version).toBe(true);
  });

  it("rejects unknown options", () => {
    expect(() => parseArgs(["--nope"])).toThrow("Unknown option: --nope");
  });

  it("rejects a flag that is missing its value", () => {
    expect(() => parseArgs(["--file"])).toThrow("--file requires a value");
  });
});

describe("DEFAULT_KANEO_URL", () => {
  it("points at Kaneo Cloud and is echoed in the help text", async () => {
    const { HELP_TEXT } = await import("./args.js");

    expect(DEFAULT_KANEO_URL).toBe("https://cloud.kaneo.app");
    expect(HELP_TEXT).toContain(DEFAULT_KANEO_URL);
  });
});
