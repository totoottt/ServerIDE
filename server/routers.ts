import { COOKIE_NAME } from "../shared/const.js";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { publicProcedure, router } from "./_core/trpc";
import { deleteRemotePath, discoverHostKey, listRemoteDirectory, makeRemoteDirectory, readRemoteChunk, readRemoteFile, runSSHCommand, statRemoteFile, writeRemoteChunk, writeRemoteFile } from "./ssh-service";
import { sshCredentialsSchema, sshHostProbeSchema } from "./ssh-validation";
import { z } from "zod";

export { sshCredentialsSchema };

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
    hostKey: publicProcedure.input(z.object({ credentials: sshHostProbeSchema })).mutation(async ({ input }) => discoverHostKey(input.credentials)),
    exec: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, command: z.string().min(1).max(10000) })).mutation(async ({ input }) => runSSHCommand(input.credentials, input.command)),
    list: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => listRemoteDirectory(input.credentials, input.path)),
    read: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => readRemoteFile(input.credentials, input.path)),
    write: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096), content: z.string().max(2_000_000) })).mutation(async ({ input }) => writeRemoteFile(input.credentials, input.path, input.content)),
    delete: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => deleteRemotePath(input.credentials, input.path)),
    mkdir: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => makeRemoteDirectory(input.credentials, input.path)),
    stat: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096) })).mutation(async ({ input }) => statRemoteFile(input.credentials, input.path)),
    writeChunk: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096), offset: z.number().int().min(0), dataBase64: z.string().min(1).max(900_000) })).mutation(async ({ input }) => writeRemoteChunk(input.credentials, input.path, Buffer.from(input.dataBase64, "base64"), input.offset)),
    readChunk: publicProcedure.input(z.object({ credentials: sshCredentialsSchema, path: z.string().min(1).max(4096), offset: z.number().int().min(0), length: z.number().int().min(1).max(524_288) })).mutation(async ({ input }) => ({ offset: input.offset, dataBase64: (await readRemoteChunk(input.credentials, input.path, input.offset, input.length)).toString("base64") })),
  }),
});

export type AppRouter = typeof appRouter;
