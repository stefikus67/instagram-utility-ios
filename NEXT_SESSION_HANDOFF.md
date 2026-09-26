# Handoff 2026-09-27

## State
- Repo local only, `main`, no remote. gh CLI installed at `C:\Program Files\GitHub CLI\gh.exe` (not on PATH), NOT logged in.
- `swift test` PASSES locally: 16 tests, 0 failures (Swift 6.0.3 on Linux via WSL Ubuntu, toolchain in `~/swift`,
  needs `LD_LIBRARY_PATH=$HOME/swiftlibs` shim for libxml2.so.2). Linux Foundation URL parsing may differ slightly from Apple's;
  the CI run on macOS is the real confirmation.
- App code (`Sources/App`) has never been compiled (needs macOS runner).

## Morning steps (human)
1. `"C:\Program Files\GitHub CLI\gh.exe" auth login --web -s repo,workflow` and enter the code shown at github.com/login/device.
2. Tell Claude "gh is logged in" → Claude runs:
   `gh repo create instagram-utility-ios --public --source . --push`, then watches `gh run watch` and fixes compile errors.

## Then
Follow `docs/IPHONE_INSTALL.md`.
