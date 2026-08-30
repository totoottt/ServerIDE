import { describe, expect, it } from "vitest";
import { validateServerDraft } from "../lib/server-profile";

describe("server profile validation", () => {
  it("accepts a valid SSH profile", () => {
    expect(validateServerDraft({ name: "Production", host: "server.example.com", port: 22, username: "deploy" })).toBeNull();
  });

  it("rejects invalid ports and whitespace in hosts", () => {
    expect(validateServerDraft({ name: "Server", host: "server example.com", port: 22, username: "deploy" })).toContain("spaces");
    expect(validateServerDraft({ name: "Server", host: "server.example.com", port: 70000, username: "deploy" })).toContain("between");
  });
});
