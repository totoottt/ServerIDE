# ServerIDE 0.7.0 — Files, editor, terminal and diagnostics

Read RELEASE_0.7.0.md for the full current changes, tests and unfinished items. Signing remains BOOS Ad Hoc. Files integration now uses an explicit plist and final-bundle validation; editor saves are chunked, backed up and conflict-checked. Added persistent Terminal navigation, actual tab counts, folder/file sections, wrapping fixes, app icon, local Documents commands, GitHub account/repository access and live metric charts. No IPA or iOS runtime verification was produced locally.

Fixes the supplied Xcode 26.4 build failure at SFTPViewModel.swift:123 (`makeIterator is unavailable from asynchronous contexts`). Folder enumeration now completes synchronously using `nextObject()` before SSH transfers start; no enumerator crosses an await. Enumeration errors abort preflight. Added four XCTest regression cases (async call site, nested/hidden files, symlinks, size and entry limits). These new XCTest cases require Codemagic/Xcode and have NOT been executed locally.

Ad Hoc signing and Bundle ID are unchanged from 0.6.1. Keep the signed workflow `ServerIDE Ad Hoc IPA`; tests remain enabled. This archive contains source, not a built IPA.

The Xcode project and Codemagic signed workflow now match the BOOS Ad Hoc provisioning profile: `app.carambola5307.spinach7929`.

This source update follows the three-page BOOS requirements PDF. It preserves existing profile IDs, Keychain service names and the original Citadel command connection approach.

## Implemented in this update

| Request | Implementation |
| --- | --- |
| Long press server | Context menus on Dashboard and Servers |
| SSH / files | Open a new command tab or the remote file browser |
| Edit | Profile name, host, port, user, group, notes, preview URL; optional password replacement |
| Clone | New profile UUID and copied Keychain entries; visible label says credentials are copied |
| Notes / Favorite | Saved profile notes and favorites; Dashboard puts favorites first |
| Recent | Last-opened date displayed on Dashboard |
| Copy | Host, username, password or combined text; password copy requires device authentication and expires after 60 seconds |
| Delete | Confirmation, profile and Keychain removal; no server files deleted |
| Recordings | Explicit encrypted text snapshots, not continuous video/session replay; per-server and all-recordings access |
| Multiple windows | Independent command tabs with separate model/output/history, retained in memory while navigating |
| Font / wrapping | Terminal font controls and line wrapping; file font/filename wrapping; editor font controls; preferences saved |
| Remote file menu | Create file/folder, upload file/folder, favorite folders, hidden-file toggle, jump-to-path |
| File rows | Size, modification date, permissions, search, rename, copy path, download and confirmed delete |
| Tools | Ping, traceroute and bounded TCP port checks execute FROM the selected SSH server |
| Apple Files | Downloads appear in On My iPhone / ServerIDE / Downloads |

## Important boundaries — not claimed as completed

- Tabs are separate command consoles. The SSH engine still does not retain a persistent interactive PTY, shell working directory or nano/vim session.
- Remote browsing inside Apple Files as a live server location is NOT implemented. That requires a File Provider extension and signing/entitlement integration. The local Downloads folder is not a substitute for a remote provider.
- The remote file browser uses Python 3 over SSH, not native SFTP. It targets Ubuntu/Linux. No packages are installed automatically.
- Host-key verification still accepts any key, inherited from the supplied project. Known-host verification remains a public-release blocker.
- Private-key login is not wired in the existing SSH manager.
- SSH session keepalive, live replay recording, background persistence, AI and the other full-product roadmap items remain outside this update.

## File operation safety and limits

- Each uploaded file is staged, size-checked and published without overwriting an existing destination.
- Renaming uses Linux renameat2(RENAME_NOREPLACE), preventing accidental replacement, including directories.
- Deletion only removes a file/symlink or an EMPTY directory. It is not a trash operation.
- File upload/download limit: 5 MiB per file. Folder limit: 200 entries and 20 MiB. Folder imports include hidden files and reject symlinks.
- Upload chunks share one SSH connection. Folder uploads are sequential and may leave already-completed items if interrupted.
- If the connection is lost, a hidden .serveride-upload-* staging file may remain; it is never presented as a successful upload.
- Downloads use unique subfolders, so existing local downloads are not overwritten.
- Credentials never appear in ordinary notes or profile JSON. Password copies are explicitly authenticated.
- Transcript snapshots use AES-GCM and a Keychain key. They are excluded from backups and kept out of the public Documents folder. Existing transcripts are not overwritten if the encryption key is unavailable.
- Notes and favorites remain unencrypted app preferences. Do not put secrets in notes.
- Closing a profile or leaving a screen does not terminate a running remote process. Running command tabs cannot be explicitly closed.

## Verification actually completed

- 30 Python tests executed successfully, covering the exact bundled remote helper plus the shipped-bundle validator using test fixtures.
- Covered Arabic/quoted/newline filenames, hidden entries, binary multichunk round-trip, file and directory creation, no-overwrite rename/upload, nonempty directory protection, symlink safety, size limits and the shell/JSON transport.
- 50 Swift source/test files passed syntax parsing only; this does not type-check against the Apple SDK.
- YAML and CI shell syntax validated; version identifiers checked as 0.7.0. Explicit plist booleans and the opaque 1024px icon checked locally.
- Additional XCTest cases authored for old profile decoding, profile persistence/favorites/recent access, independent tabs and remote metadata decoding.
- Xcode compilation, Swift type checking, iPhone UI behavior, LocalAuthentication/Keychain runtime behavior and live SSH integration were NOT executed in this Linux environment. The XCTest suite is wired to the existing Codemagic compile workflow.

Run Linux helper tests locally:
    python3 tests/test_remote_files.py

The supplied project.yml includes the Python helper as an app resource. Keep that file and the whole project structure together when building.

## References consulted
- Apple File Provider: https://developer.apple.com/documentation/fileprovider
- Apple UIFileSharingEnabled: https://developer.apple.com/documentation/bundleresources/information-property-list/uifilesharingenabled
- Apple opening documents in place: https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsopeningdocumentsinplace
- Apple Button: https://developer.apple.com/documentation/swiftui/button
- Apple Menu: https://developer.apple.com/documentation/swiftui/menu
