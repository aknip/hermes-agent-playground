import { describe, expect, it } from "vitest";
import { normalizeBaseUrl } from "./kaneo.js";

describe("normalizeBaseUrl", () => {
  it("keeps a plain base URL unchanged", () => {
    expect(normalizeBaseUrl("https://kaneo.example.com")).toBe(
      "https://kaneo.example.com",
    );
  });

  it("strips trailing slashes", () => {
    expect(normalizeBaseUrl("https://kaneo.example.com/")).toBe(
      "https://kaneo.example.com",
    );
  });

  it("strips a trailing /api path", () => {
    expect(normalizeBaseUrl("https://kaneo.example.com/api")).toBe(
      "https://kaneo.example.com",
    );
    expect(normalizeBaseUrl("https://kaneo.example.com/base/api")).toBe(
      "https://kaneo.example.com/base",
    );
  });

  it("strips an /api path that ends in a slash", () => {
    expect(normalizeBaseUrl("https://kaneo.example.com/api/")).toBe(
      "https://kaneo.example.com",
    );
  });

  it("keeps a path-only suffix that is not an API root", () => {
    expect(normalizeBaseUrl("https://kaneo.example.com/kaneo")).toBe(
      "https://kaneo.example.com/kaneo",
    );
  });
});
