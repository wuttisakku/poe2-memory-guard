# Changelog

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
