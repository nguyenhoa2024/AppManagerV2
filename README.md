# AppDataKit

A clean-room, open-source TrollStore utility for **multi-select wipe / backup / restore**
of installed app data containers. Written in Objective-C against UIKit, optimized for iOS 15+
and constrained devices (iPhone 6s and friends).

> **Status:** unverified — see "Build & verify" below. The source is complete but the project
> has not been compiled or run by the author. The first build on the GitHub Actions runner
> (or on a macOS workstation) is the real smoke test.

## Features

- Single-shot app scan on launch (cached for the rest of the session)
- Searchable, grouped, native iOS list — `UITableViewStyleInsetGrouped`
- Multi-select with persistent selection across launches
- Batch **Wipe** and batch **Backup**
- Per-app **Restore** from any previous backup
- Pull-to-refresh
- NSCache-backed icon cache with ImageIO downsampling (no full-bitmap decode)
- Async size measurement via POSIX `lstat`/`opendir` (faster than `NSDirectoryEnumerator`)
- Dark mode, SF Symbols, Dynamic Type
- No SwiftUI, no Core Animation pyrotechnics, no main-thread blocking I/O

## How it works (brief)

| Concern | Implementation |
|---|---|
| App enumeration | Private `LSApplicationWorkspace` via `NSClassFromString` + `performSelector` (loose binding for forward-compat) |
| Read other app data | `NSFileManager` against `dataContainerURL`; works because TrollStore grants `container-manager` + `AppDataContainers` |
| Backup format | `tar -czf` over the data container into `~/Documents/Backups/<bundleID>/<bundleID>_<stamp>.tar.gz` |
| Restore | Wipe container contents → `tar -xzf` over the now-empty container |
| Wipe | Recursively delete every direct child of the data container (the container itself is preserved so the OS doesn't get confused) |
| Spawning `tar` | `posix_spawn` — TrollStore runs us with `platform-application`, so `/usr/bin/tar` is reachable without a helper |

## Project layout

```
AppDataKit/
├── Makefile                       Theos rules + an `after-package` step that wraps the .deb into a .tipa
├── control                        deb metadata
├── Resources/
│   ├── Info.plist                 MinimumOSVersion 15.0, iPhone + iPad
│   ├── Entitlements.plist         TrollStore-grade entitlements
│   └── LaunchScreen.storyboard
├── Sources/
│   ├── main.m
│   ├── ADKAppDelegate.{h,m}
│   ├── UI/
│   │   ├── Cells/ADKAppCell.{h,m}
│   │   ├── Controllers/ADKAppListViewController.{h,m}
│   │   ├── Controllers/ADKBackupListViewController.{h,m}
│   │   ├── Controllers/ADKOperationProgressViewController.{h,m}
│   │   ├── Controllers/ADKSettingsViewController.{h,m}
│   │   └── Views/ADKEmptyStateView.{h,m}
│   ├── Managers/                  Repository, BackupManager, RestoreManager, WipeManager, BatchCoordinator, SelectionState
│   ├── Cache/ADKIconCache.{h,m}
│   ├── Models/ADKApp.{h,m}, ADKBackup.{h,m}
│   └── Helpers/                   FileSystem, ByteFormatter, TarRunner, LSWorkspace
└── .github/workflows/build.yml    GitHub Actions: builds `.deb` and packages a `.tipa` artifact
```

## Build & verify

### Option A: GitHub Actions (zero setup)

1. Push this repo to GitHub (`git init && git add . && git commit -m init && git push`).
2. Open the **Actions** tab. The `Build AppDataKit TIPA` workflow runs on `macos-14`,
   installs Theos + the iOS 16.5 patched SDK, builds, and uploads `AppDataKit.tipa`
   as a workflow artifact.
3. Download the artifact, sideload it via TrollStore on your device.

To cut a release, push a `vX.Y.Z` tag — the workflow attaches the `.tipa` + `.deb` to a GitHub Release.

### Option B: local build (macOS)

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git "$THEOS"
# Get a patched iOS SDK:
curl -L -o /tmp/sdk.tar.xz https://github.com/theos/sdks/releases/download/master/iPhoneOS16.5.sdk.tar.xz
mkdir -p "$THEOS/sdks" && tar -xf /tmp/sdk.tar.xz -C "$THEOS/sdks"
brew install ldid dpkg make

cd AppDataKit
make package FINALPACKAGE=1
# Wrap into a .tipa:
make after-package
ls packages/
```

## Signing

Nothing in this project ships pre-signed. TrollStore re-signs and applies the
entitlements at install time, so what you upload to the device should be an
**unsigned** `.tipa`. If you want to sign manually, use `ldid -SResources/Entitlements.plist Payload/AppDataKit.app/AppDataKit` before zipping.

## Notes / known limitations

- The default `Resources/AppIcon.png` slots are empty — drop your own icon PNGs into
  `Resources/` and reference them in `Info.plist` before shipping a release.
- App enumeration uses private API names. If iOS renames `dataContainerURL` or
  `allApplications` on a future major version, the `NSClassFromString` + `performSelector`
  pattern in `ADKLSWorkspace` will return `nil` instead of crashing — but the app will show
  an empty list until the selectors are updated.
- `tar` over very large data containers can be slow. Operations run on a background
  serial queue with a cancel hook; the user can dismiss the progress sheet at any time
  for an in-flight item.
- The `kcaccess.zip` / `fastPathSign` helpers in the original Apps Manager bundle
  do keychain export + on-device codesigning. AppDataKit does **not** include those
  features — they require additional entitlements and helper binaries that are out of
  scope for a clean-room rewrite.

## License

MIT — add a `LICENSE` file before publishing.
