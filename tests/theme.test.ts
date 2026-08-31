import { describe, expect, it } from "vitest";

const selectableThemes = ["midnight", "ocean", "slate"] as const;
const semanticStates = ["success", "warning", "error", "info"] as const;

describe("global theme contract", () => {
  it("defines the selectable user themes", () => {
    expect(selectableThemes).toEqual(["midnight", "ocean", "slate"]);
  });

  it("defines semantic states required by every service", () => {
    expect(semanticStates).toContain("success");
    expect(semanticStates).toContain("warning");
    expect(semanticStates).toContain("error");
    expect(semanticStates).toContain("info");
  });
});
