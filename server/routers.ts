import { COOKIE_NAME } from "../shared/const.js";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { publicProcedure, router } from "./_core/trpc";
import { deleteRemotePath, listRemoteDirectory, makeRemoteDirectory, readRemoteFile, runSSHCommand, writeRemoteFile } from "./ssh-service";
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

export const appRouter = router({
  system: systemRouter,
  auth: router({
    me: publicProcedure.query((opts) => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return { success: true } as const;
    }),
  }),
  ssh: router({
    exec: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, command: z.string().min(1).max(10000) })).mutation(async ({ input }) => runSSHCommand(input.credentials, input.command)),
    list: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => listRemoteDirectory(input.credentials, input.path)),
    read: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => readRemoteFile(input.credentials, input.path)),
    write: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096), content: z.string().max(2_000_000) })).mutation(async ({ input }) => writeRemoteFile(input.credentials, input.path, input.content)),
    delete: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => deleteRemotePath(input.credentials, input.path)),
    mkdir: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => makeRemoteDirectory(input.credentials, input.path)),
  }),
});

export type AppRouter = typeof appRouter;
