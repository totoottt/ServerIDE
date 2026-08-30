# ServerIDE Mobile 1.1

ServerIDE keeps the existing Midnight interface while replacing simulated cards with live server services.

## Live features

- Overview: CPU, memory, storage, latency and connection status.
- Processes: live process list, search and protected SIGTERM action.
- Network: interface counters and live RX/TX samples.
- Terminal: command execution with stdout, stderr and exit status.
- Files: directory browsing, UTF-8 preview, editing, atomic save, folder creation and protected deletion.
- Checks: live SPF, default-selector DKIM, DMARC, domain resolution and explicit unsupported-provider status.
- Credentials: agent token stored in iOS Keychain.

The app talks to the included token-protected server agent over HTTPS. Installation instructions are in `agent/README.md`.

## Codemagic artifacts

The `expo-ios-ad-hoc` workflow validates TypeScript and tests, builds the signed IPA, and emits:

- `ServerIDE.ipa`
- `ServerIDE-ESign-Payload.zip` containing `Payload/ServerIDE.app`
- `ServerIDE-source.zip`

The Bundle ID remains `app.carambola5307.spinach7929`, matching the configured Ad Hoc certificate/profile.
