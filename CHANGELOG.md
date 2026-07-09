# Changelog

## v1.2.4

- Added `PoE2MemoryGuard.cmd` as the main user-facing launcher.
- Kept `Start-Memory-Guard.cmd` as a legacy alias for compatibility.
- Updated auto-update logic to copy the new launcher name.
- Updated README instructions to use `PoE2MemoryGuard.cmd`.

## v1.2.3

- Removed automatic self-elevation from `Start-Memory-Guard.cmd` to avoid Windows Security or SmartScreen blocking the launcher on some systems.
- Updated quick-start instructions to use normal double-click launch.
- Documented right-click Run as administrator as the fallback for RAMMap mode or permission issues.

## v1.2.2

- Added automatic Administrator permission prompt when launching `Start-Memory-Guard.cmd`.
- Updated quick-start instructions so users can double-click the launcher instead of using right-click Run as administrator.

## v1.2.1

- Added `CHANGELOG.md`.
- Linked the changelog from `README.md`.

## v1.2.0

- Added automatic update checks on launch.
- Added `Update-Memory-Guard.ps1`.
- Added `VERSION` file for local version detection.
- Preserved existing `config.json` values during auto-updates.
- Added `EnableAutoUpdate` config option.
- Removed old public branches, tags, and releases from the cleaned repo state.
- Made `CONTRIBUTING.md` local-only via `.gitignore`.

## v1.1.0

- Changed the default check interval from 60 seconds to 15 seconds.
- Changed the default trim cooldown from 10 minutes to 2 minutes.
- Removed the Thai README section.

## v1.0.0

- Initial public release.
- Added PoE working-set monitoring for `PathOfExile*` processes.
- Added PoE-only working-set trimming through the Windows `EmptyWorkingSet` API.
- Added optional RAMMap standby-list purge mode.
- Added Windows launcher script.
- Added bilingual documentation and screenshot.
