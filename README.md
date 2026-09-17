# LocusSweep

Native macOS uninstall helper: drop an `.app`, scan leftover files under `~/Library`, review sizes, and move checked items to Trash.

GPL-3.0 — Copyright (C) 2026 Locusable Studio.

Build: see `ACCEPTANCE.md` (`make generate && make build` on a Mac with Xcode). Requires macOS 15+.

Safety: skips Apple/system paths by default; moves use Trash APIs only (never `rm -rf`).
