# iOS TestFlight build runbook

Status: **Export preset scaffolded — not yet buildable.** A signed TestFlight
build requires a Mac, an Apple Developer Program account, and values that are not
in this repo (see "What you must supply"). Nothing in this file has been run.

This is the bridge between a green `main` and the physical device session in
[ALPHA_RC1_DEVICE_TEST.md](ALPHA_RC1_DEVICE_TEST.md). Do that session on the
build this runbook produces.

## What is already in the repo

- `export_presets.cfg` — an `iOS` preset (`preset.0`). Portrait phone target
  (`targeted_device_family=1`), min iOS 14.0, launch-screen storyboard on the
  splash background colour, `increased_memory_limit` entitlement on, no camera /
  mic / photo / tracking usage, `build/ios/` (git-ignored) as the output path.
- `project.godot` — `config/version="0.1.0"`, `display/window/handheld/orientation="portrait"`,
  and the existing `audio/general/ios/*` mixing settings.
- `assets/branding/app_icon.png` — 1024×1024, no alpha (App Store compliant).
- `assets/branding/splash.png` — used for the boot splash and launch storyboard.

## What you must supply

These are per-developer / per-account and are intentionally blank in
`export_presets.cfg`. Fill them in the Godot export dialog (Project → Export →
iOS) on the Mac, or edit the cfg directly:

| Field | Where to get it |
| --- | --- |
| `application/bundle_identifier` | App Store Connect → your registered App ID. Placeholder is `com.dbahlcorp.indieempire` — change it to match your real App ID. |
| `application/app_store_team_id` | Apple Developer → Membership details → Team ID (10 chars). |
| `application/provisioning_profile_uuid_release` | A distribution provisioning profile for the bundle ID (or leave blank and let Xcode automatic-signing handle it). |
| `application/code_sign_identity_release` | `Apple Distribution` for automatic signing. |
| `application/short_version` / `application/version` | Marketing version and build number. Bump `version` on every TestFlight upload. |

Register the App ID and create the app record in App Store Connect first; the
bundle identifier must match exactly.

## One-time machine setup (macOS)

1. Install Xcode from the App Store and run `xcodebuild -runFirstLaunch`.
2. Install Godot **4.7.2** (must match `project.godot` / the engine used for
   testing) and its **iOS export templates**: Editor → Manage Export Templates →
   Download, or drop `ios.zip` into
   `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`.
3. Sign in to Xcode with the Apple ID on the developer team (Xcode → Settings →
   Accounts).

## Build and upload

1. Clone/pull `main` on the Mac and open the project once in Godot so it imports.
2. Project → Export → iOS. Fill the fields from "What you must supply". The
   dialog should show no remaining configuration errors.
3. Export Project. Choose an output folder — Godot writes an **Xcode project**
   (not a finished `.ipa`).
4. Open the generated `.xcodeproj` in Xcode. Set the team under Signing &
   Capabilities if it is not already inferred.
5. Select "Any iOS Device (arm64)". Product → Archive.
6. In the Organizer: Distribute App → App Store Connect → Upload. Let Xcode
   manage signing.
7. In App Store Connect → your app → TestFlight, wait for processing, complete
   the export-compliance question (this build uses no non-exempt encryption),
   then add internal testers.

CLI alternative to steps 4–6: `xcodebuild -project <name>.xcodeproj -scheme <name>
-configuration Release -archivePath build/app.xcarchive archive` then
`xcodebuild -exportArchive -archivePath build/app.xcarchive -exportPath build/ipa
-exportOptionsPlist ExportOptions.plist`, then upload with
`xcrun altool`/`notarytool` or Transporter.

## Pre-upload checks

- `main` is green: run the root test suites (see `docs/PA16B_FINAL_REPORT.md` for
  the reference 72/72 / 13,522-check run).
- Boot the configured main scene once with a renderer (not `--headless`) and
  confirm a clean exit.
- Confirm the app launches portrait and stays portrait on device.
- Bump `application/version` since the last upload.

## Known gaps to close before/while on device

- No `NSUserTrackingUsageDescription` etc. are set because the app collects no
  such data; if analytics are added later, update `privacy/*` in the preset and
  the App Store Connect privacy questionnaire.
- Physical acceptance is still governed by `ALPHA_RC1_DEVICE_TEST.md`; a
  successful upload is not acceptance.
- The historical-artifact CSVs under `artifacts/balance-2026-09-07/` emit
  duplicate-UID import warnings. They are excluded from the export via
  `exclude_filter` and do not reach the bundle, but they are noisy on import.
