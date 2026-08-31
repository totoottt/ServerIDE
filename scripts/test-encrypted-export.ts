import { decryptServerExport, encryptServerExport } from "../lib/encrypted-server-export";

const source = { servers: [{ profile: { name: "test", host: "example.com" }, secret: { password: "hidden" } }] };
const serialized = encryptServerExport(source, "correct horse battery staple");
const restored = decryptServerExport(serialized, "correct horse battery staple");
if (JSON.stringify(restored) !== JSON.stringify(source)) throw new Error("Encrypted export round-trip failed");
let rejected = false;
try { decryptServerExport(serialized, "wrong password"); } catch { rejected = true; }
if (!rejected) throw new Error("Wrong password was accepted");
console.log("encrypted export round-trip passed");
