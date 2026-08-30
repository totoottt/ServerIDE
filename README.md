# Server IDE

Mobile server workspace built with Expo and React Native.

## Build an IPA for Esign

In Codemagic, run the workflow **Server IDE — Esign IPA** from the `main` branch.
It produces:

- `ServerIDE-Esign-unsigned.ipa` — upload this file to Esign, then sign and install it.
- `ServerIDE-source.zip` — source archive of the exact build.

The IPA is intentionally unsigned because Esign applies the signing certificate on the device side.
