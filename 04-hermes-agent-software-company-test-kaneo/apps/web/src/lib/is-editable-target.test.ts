import { describe, expect, it } from "vitest";
import { isEditableTarget } from "./is-editable-target";

describe("isEditableTarget", () => {
  it("erkennt INPUT als bearbeitbar", () => {
    const element = document.createElement("input");
    expect(isEditableTarget(element)).toBe(true);
  });

  it("erkennt TEXTAREA als bearbeitbar", () => {
    const element = document.createElement("textarea");
    expect(isEditableTarget(element)).toBe(true);
  });

  it("erkennt ein contentEditable-Element als bearbeitbar", () => {
    const element = document.createElement("div");
    element.contentEditable = "true";
    expect(isEditableTarget(element)).toBe(true);
  });

  it("lehnt normale Elemente ab", () => {
    const div = document.createElement("div");
    expect(isEditableTarget(div)).toBe(false);
    expect(isEditableTarget(document.body)).toBe(false);
  });

  it("lehnt Nicht-Element-Ziele ab (document, null)", () => {
    expect(isEditableTarget(document)).toBe(false);
    expect(isEditableTarget(null)).toBe(false);
  });
});
