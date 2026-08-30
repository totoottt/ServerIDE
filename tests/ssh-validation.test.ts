import { describe, expect, it } from "vitest";
import { sshCredentialsSchema } from "../server/routers";
import { performPortKnock } from "../server/ssh-service";

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

  it("accepts a valid port knock sequence and jump host", () => {
    const result = sshCredentialsSchema.safeParse({ host: "server.example.com", port: 22, username: "deploy", password: "secret", portKnockSequence: "2222:udp,3333:tcp", jumpHost: { host: "bastion.example.com", port: 22, username: "jumper", password: "hop" } });
    expect(result.success).toBe(true);
  });

  it("rejects a malformed port knock sequence", () => {
    const result = sshCredentialsSchema.safeParse({ host: "server.example.com", port: 22, username: "deploy", password: "secret", portKnockSequence: "not-a-sequence" });
    expect(result.success).toBe(false);
  });
});

describe("port knocking", () => {
  it("rejects an out-of-range port in the sequence", async () => {
    await expect(performPortKnock("127.0.0.1", "99999:tcp")).rejects.toThrow(/Invalid port knock entry/);
  });
});
