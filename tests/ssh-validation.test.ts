import { describe, expect, it } from "vitest";
import { sshCredentialsSchema } from "../server/routers";

describe("SSH credential validation", () => {
  it("accepts password credentials with a valid host fingerprint", () => {
    const result = sshCredentialsSchema.safeParse({ host: "server.example.com", port: 22, username: "deploy", password: "secret", hostFingerprint: "SHA256:abcDEF0123+/" });
    expect(result.success).toBe(true);
  });

  it("rejects credentials without password or private key", () => {
    const result = sshCredentialsSchema.safeParse({ host: "server.example.com", port: 22, username: "deploy", hostFingerprint: "SHA256:abcDEF0123+/" });
    expect(result.success).toBe(false);
  });

  it("rejects malformed fingerprints and invalid ports", () => {
    const result = sshCredentialsSchema.safeParse({ host: "server.example.com", port: 70000, username: "deploy", password: "secret", hostFingerprint: "fingerprint" });
    expect(result.success).toBe(false);
  });
});
