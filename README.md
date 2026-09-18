# LocusSweep

![LocusSweep](docs/icon.png)

Native macOS uninstall helper. Drop one or more `.app` bundles, scan leftovers under `~/Library`, review sizes, and move checked items to Trash — one app at a time.

GPL-3.0 — Copyright (C) 2026 Locusable Studio.

- **Queue** — several apps scan and clean in order, never in parallel.
- **Permissions** — if Full Disk Access (or another read) fails, a guide opens System Settings. Scan again after granting access. Nothing is deleted on that path.
- **Settings** — scan scope (which `~/Library` folders, and whether to include the `.app`) and safety level (Strict / Balanced / Thorough). Apple and system paths stay blocked.
- **Build** — macOS 15+, unsigned local Debug: `make generate && make build`. Linux static check: `make verify` (`swift test` on LocusSweepCore).

Safety: Trash APIs only. Never `rm` / `rm -rf`.
