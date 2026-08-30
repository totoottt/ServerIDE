import { describe, expect, it } from "vitest";
import { isActionable, statusLabel } from "../lib/status";

describe("service status semantics", () => {
  it("labels operational states consistently", () => {
    expect(statusLabel.success).toBe("Success");
    expect(statusLabel.error).toBe("Error");
  });

  it("flags warning and error states as actionable", () => {
    expect(isActionable("warning")).toBe(true);
    expect(isActionable("error")).toBe(true);
    expect(isActionable("success")).toBe(false);
  });
});
