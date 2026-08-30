import { z } from "zod";

export const sshCredentialsSchema = z.object({
  host: z.string().min(1).max(255),
  port: z.number().int().min(1).max(65535),
  username: z.string().min(1).max(128),
  password: z.string().max(4096).optional(),
  privateKey: z.string().max(20000).optional(),
  passphrase: z.string().max(4096).optional(),
  hostFingerprint: z.string().regex(/^SHA256:[A-Za-z0-9+/]+$/).optional(),
}).refine((value) => Boolean(value.password || value.privateKey), { message: "A password or private key is required" });

export type ValidatedSSHCredentials = z.infer<typeof sshCredentialsSchema>;
