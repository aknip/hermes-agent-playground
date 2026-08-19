import { describe, expect, it } from "vitest";
import { HELP_TEXT } from "./args.js";
import { type CliIO, runCli } from "./index.js";

function memoryIo(): CliIO & { out: string[]; err: string[] } {
  const out: string[] = [];
  const err: string[] = [];
  return {
    out,
    err,
    stdout: (text) => out.push(text),
    stderr: (text) => err.push(text),
    async readFile() {
      throw new Error("no file configured");
    },
    async writeFile() {},
  };
}

describe("runCli", () => {
  it("--help prints the help text and exits 0", async () => {
    const io = memoryIo();
    const code = await runCli(["--help"], io);

    expect(code).toBe(0);
    expect(io.out.join("")).toContain(HELP_TEXT);
  });

  it("--version prints the package version and exits 0", async () => {
    const io = memoryIo();
    const code = await runCli(["--version"], io);

    expect(code).toBe(0);
    expect(io.out.join("")).toMatch(/\d+\.\d+\.\d+/);
  });

  it("requires --file", async () => {
    const io = memoryIo();
    const code = await runCli(["--project-name", "N"], io);

    expect(code).toBe(2);
    expect(io.err.join("")).toContain("--file is required");
  });

  it("requires --project-name", async () => {
    const io = memoryIo();
    const code = await runCli(["--file", "tasks.csv"], io);

    expect(code).toBe(2);
    expect(io.err.join("")).toContain("--project-name is required");
  });

  it("rejects an invalid CSV before any write", async () => {
    const io = memoryIo();
    io.readFile = async () => "title,banana\na,x\n";
    const code = await runCli(
      ["--file", "tasks.csv", "--project-name", "N", "--dry-run"],
      io,
    );

    expect(code).toBe(2);
    expect(io.err.join("")).toContain("banana");
  });

  it("runs a dry run and reports counts without an API key", async () => {
    const io = memoryIo();
    io.readFile = async () => "title,column\na,To Do\nb,Backlog\n";
    const code = await runCli(
      ["--file", "tasks.csv", "--project-name", "Team Move", "--dry-run"],
      io,
    );

    expect(code).toBe(0);
    expect(io.out.join("")).toContain("2 tasks");
    expect(io.out.join("")).toContain("Nothing was written");
  });

  it("writes a report file when --report is given", async () => {
    let written = "";
    const io = memoryIo();
    io.readFile = async () => "title,column\na,To Do\nb,Backlog\n";
    io.writeFile = async (_path, data) => {
      written = data;
    };
    const code = await runCli(
      [
        "--file",
        "t.csv",
        "--project-name",
        "N",
        "--dry-run",
        "--report",
        "r.json",
      ],
      io,
    );

    expect(code).toBe(0);
    expect(written).toContain('"tasks": 2');
    expect(io.out.join("")).toContain("Report written to r.json");
  });
});
