# ServerIDE 0.7.1 (12)

Release marker: `PROJECT-PDF-20260829-C`

This repository-root package contains the requested PDF fixes:

- a permanent fifth `Terminal` tab whose sessions remain available while navigating;
- remembered working directory for commands such as `cd ~/mebot`;
- separate `Folders` and `Files` sections in Remote Files;
- resilient IP lookup that still returns the address if geolocation is unavailable;
- Apple Files sharing flags and visible downloads status;
- an on-screen release badge and dynamic version/build identity.
- complete symbolic-link ancestor validation for local Documents commands.
- SSH terminal output keeps stderr and exit codes instead of hiding them behind `CommandFailed`.
- free native iOS text selection for any output range or symbols.
- public IP fallback across ipify IPv6, ipify IPv4, and Cloudflare trace.
- geolocation fallback across ipapi.co and ipwho.is.
- Network Discovery, Port Scanner, Ping, Traceroute, WHOIS, Certificate Checker, and Domain Audit.
- Cron Generator, Hex Viewer, Baker/Text Lab, HTTP Workbench, and encrypted Secret Share.

Codemagic verifies the exact version, build number, release marker, bundle ID,
Apple Files flags, and app icon inside the built `.app` or `.ipa`. The build fails
instead of publishing an old or mixed binary.
