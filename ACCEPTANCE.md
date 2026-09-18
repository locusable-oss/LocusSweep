# LocusSweep acceptance (MVP sorts 1–14)

Unsigned local Debug on macOS 15+ with Xcode. This batch does **not** tag or publish a release.

Linux static gate (no AppKit): `make verify` runs `swift test` for rules, scanner, safety filter, permission classification, settings, and the one-at-a-time queue.

Mac UI / Trash: `make generate && make build` (`CODE_SIGN_IDENTITY="-"`).

## Checklist

1. **Naming** — App displays as LocusSweep; bundle `studio.locusable.LocusSweep`.
2. **Skeleton** — `make generate && make build` produces a runnable window app.
3. **Drop / choose .app** — Drag one or more `.app` bundles (or Choose Apps…) and see name, Bundle ID, and path from Info.plist.
4. **Residue rules** — Selecting an app builds candidate `~/Library` residue paths (Preferences, Application Support, Caches, Logs, Saved State, Containers, HTTPStorages, …). Apple/system bundle IDs produce no candidates.
5. **Scan + sizes** — Existing candidates are scanned; recursive byte sizes are measured and aggregated.
6. **Results list** — Path, size, and category with checkboxes. Rows default to checked. All / None available.
7. **Safety filter** — Defaults skip `com.apple.*`, `/System`, `/Library` (non-user), and other obvious system paths. Unsafe paths are never checked trash targets.
8. **Move to Trash** — Confirm, then `FileManager.trashItem` / `NSWorkspace.recycle`. **Never** `rm` / `rm -rf`.
9. **Cleanup summary** — Sheet shows moved count, volume, and failures.
10. **Permission recovery** — Unreadable protected folders (Containers, Mail, and similar) surface as Full Disk Access (or a generic unreadable folder). The banner explains the next step, can open System Settings, and Scan Again retries. Dismiss is not a dead end. Partial results stay visible. Trash failures that are permission errors offer the same recovery.
11. **Multi-app queue** — Multiple drops or Choose Apps… enqueue apps. Only one app is scanning or cleaning at a time. The next starts after the previous finishes. Clean Queue walks ready apps in order, not in parallel.
12. **Settings** — Settings window edits scan scope (library categories + include the `.app`) and safety level. Balanced is the previous default. Strict drops name-only matches. Thorough also keeps files whose names contain the bundle ID. Values persist and apply on the next scan. Apple/system blocks are not a setting.
13. **Visual layout** — Sidebar queue and detail pane do not overlap. Safety level is visible in the header. Empty queue, pending, scanning, and empty-result states are explicit. Paths truncate in the middle and stay selectable. Window minimum size keeps the sidebar and actions on screen.
14. **Unsigned MVP** — Checklist above is the local acceptance. Do not `git tag`. Do not upload a GitHub Release. `make build` stays unsigned.

Core package tests cover rules, sizes, safety, permission errors, settings persistence, thorough discovery, and the queue’s single-busy invariant.
