import { describe, expect, it } from "vitest";
import { parseCsv, validateCsv } from "./csv.js";

describe("parseCsv", () => {
  it("parses headers and data rows", () => {
    const raw = parseCsv("title,column,priority\na,b,high\nc,d,low\n");

    expect(raw.headers).toEqual(["title", "column", "priority"]);
    expect(raw.rows).toEqual([
      ["a", "b", "high"],
      ["c", "d", "low"],
    ]);
  });

  it("handles quoted fields with commas and escaped quotes", () => {
    const raw = parseCsv(
      'title,description\na,"hello, world"\nb,"say ""hi"""\n',
    );

    expect(raw.rows[0]).toEqual(["a", "hello, world"]);
    expect(raw.rows[1]).toEqual(["b", 'say "hi"']);
  });

  it("supports CRLF line endings", () => {
    const raw = parseCsv("title,column\r\na,b\r\n");

    expect(raw.headers).toEqual(["title", "column"]);
    expect(raw.rows).toEqual([["a", "b"]]);
  });

  it("ignores blank lines", () => {
    const raw = parseCsv("title,column\n\na,b\n\nc,d\n");

    expect(raw.rows).toEqual([
      ["a", "b"],
      ["c", "d"],
    ]);
  });

  it("does not add a phantom record for a trailing newline", () => {
    const raw = parseCsv("title,column\na,b\n");

    expect(raw.rows).toEqual([["a", "b"]]);
  });

  it("returns empty structures for an empty file", () => {
    const raw = parseCsv("");

    expect(raw.headers).toEqual([]);
    expect(raw.rows).toEqual([]);
  });
});

describe("validateCsv", () => {
  it("accepts a valid CSV", () => {
    expect(() => validateCsv(parseCsv("title,column\na,b\n"))).not.toThrow();
  });

  it("rejects an empty file", () => {
    expect(() => validateCsv(parseCsv(""))).toThrow(/no data rows/i);
  });

  it("rejects a file with only a header and no data", () => {
    expect(() => validateCsv(parseCsv("title,column\n"))).toThrow(
      /no data rows/i,
    );
  });

  it("rejects an unknown column with a clear message", () => {
    const error = validateError("title,banana\na,x\n");

    expect(error).toContain("banana");
  });

  it("rejects a missing title column", () => {
    const error = validateError("description\na\n");

    expect(error).toContain("title");
  });

  it("rejects a row without a title", () => {
    const error = validateError("title,column\n,b\n");

    expect(error).toContain("Row 2 has no title");
  });

  it("tolerates extra whitespace around header names", () => {
    expect(() =>
      validateCsv(parseCsv(" title , column \na,b\n")),
    ).not.toThrow();
  });
});

function validateError(csv: string): string {
  try {
    validateCsv(parseCsv(csv));
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
  throw new Error("expected validation to fail");
}
