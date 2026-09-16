# LocusSweep acceptance (MVP sorts 1–4)

Unsigned local Debug on macOS 15+ with Xcode.

1. **Naming** — App displays as LocusSweep; bundle `studio.locusable.LocusSweep`.
2. **Skeleton** — `make generate && make build` produces a runnable window app.
3. **Drop / choose .app** — Drag an `.app` onto the drop target (or use Choose…) and see Bundle ID + install path from Info.plist.
4. **Residue rules** — Selecting an app lists candidate `~/Library` residue paths (Preferences, Application Support, Caches, Logs, Saved State, Containers, HTTPStorages, …) from the rules table; Apple/system bundle IDs produce no candidates.

Existence/size scan and trash moves are later work items — not in this commit.
