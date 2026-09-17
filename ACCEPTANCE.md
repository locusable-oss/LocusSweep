# LocusSweep acceptance (MVP sorts 1–9)

Unsigned local Debug on macOS 15+ with Xcode.

1. **Naming** — App displays as LocusSweep; bundle `studio.locusable.LocusSweep`.
2. **Skeleton** — `make generate && make build` produces a runnable window app.
3. **Drop / choose .app** — Drag an `.app` onto the drop target (or use Choose…) and see Bundle ID + install path from Info.plist.
4. **Residue rules** — Selecting an app builds candidate `~/Library` residue paths (Preferences, Application Support, Caches, Logs, Saved State, Containers, HTTPStorages, …); Apple/system bundle IDs produce no candidates.
5. **Scan + sizes** — Existing candidates are scanned; recursive byte sizes are measured and aggregated (item count + total volume).
6. **Results list UI** — List shows path / size / category with checkboxes; rows default to checked. All / None controls available.
7. **Safety filter** — Conservative defaults skip `com.apple.*`, `/System`, `/Library` (non-user), and other obvious system paths. Unsafe paths never appear as checked trash targets.
8. **Move to Trash** — Confirm dialog, then `FileManager.trashItem` / `NSWorkspace.recycle` for checked items. **Never** `rm` / `rm -rf`.
9. **Cleanup summary** — After trash, a sheet shows moved item count and freed volume (and any failures).

Core package (rules, scanner, safety filter, sizes) can be exercised with `swift test` where a Swift toolchain is available. Full UI / trash requires macOS + Xcode (`make build`).
