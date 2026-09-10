# iOS TestFlight build

Status: **repository-side release preparation complete — Apple account setup and
the first signed CI run remain.** No `.ipa` has been produced or uploaded yet.
The GitHub Actions workflow builds and uploads from a hosted macOS 26 / Xcode 26
runner, so no local Mac is required, but an Apple Developer Program account and
the credentials below are.

This produces the build for the physical session in
[ALPHA_RC1_DEVICE_TEST.md](ALPHA_RC1_DEVICE_TEST.md). A successful upload is not
acceptance.

## Route A — GitHub Actions (default)

`.github/workflows/ios-testflight.yml`, manual trigger (Actions tab → "iOS
TestFlight" → Run workflow). It:

1. validates that every required repository variable and secret is present,
2. installs Godot `4.7.2-stable` + iOS export templates (cached),
3. injects the bundle id, team id, display name, and a unique
   `<run-number>.<attempt>` iOS build number,
4. runs `ci/validate_ios_release.py`, then exports the Xcode project
   (`application/export_project_only=true`),
5. archives and exports a signed `.ipa` with `xcodebuild` using App Store Connect
   API-key authentication and automatic signing,
6. uploads to TestFlight, waits for processing, attaches the supplied test notes,
   and also saves the `.ipa` as a run artifact.

### One-time Apple setup

1. Enrol in the Apple Developer Program.
2. App Store Connect → Apps → **＋** → create the app. Note the bundle ID you
   register (must be globally unique, e.g. `com.dbahlcorp.indieempire`).
3. App Store Connect → Users and Access → Integrations → **App Store Connect
   API** → generate a team key with the **App Manager** role. Download the `.p8`
   **once**. Record the **Key ID** and the **Issuer ID**.
4. Create an **Apple Distribution** certificate (Xcode, or developer.apple.com →
   Certificates). Export it from Keychain Access as a `.p12` **with a password**,
   including the private key.
5. First upload of a brand-new app sometimes must come from Xcode/Transporter
   before Actions uploads are accepted — if the `upload-testflight-build` step
   fails on the very first run with "no app record", do one manual Transporter
   upload, then re-run.

### Repository configuration

Settings → Secrets and variables → Actions.

**Variable:**

| Name | Value |
| --- | --- |
| `IOS_BUNDLE_ID` | the bundle ID from step 2, e.g. `com.dbahlcorp.indieempire` |

**Secrets:**

| Name | Value |
| --- | --- |
| `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID (UUID) |
| `APPSTORE_KEY_ID` | API Key ID (10 chars) |
| `APPSTORE_PRIVATE_KEY` | full contents of the `AuthKey_XXXXXXXXXX.p8` file |
| `APPSTORE_TEAM_ID` | Apple Developer Team ID (10 chars) |
| `DIST_CERT_P12_BASE64` | `base64 -i dist.p12` (macOS) / `base64 -w0 dist.p12` (Linux) |
| `DIST_CERT_PASSWORD` | the `.p12` export password |

`export_presets.cfg` contains a non-secret fallback bundle ID, while the Team ID
and signing identity remain blank. The workflow replaces the bundle ID and fills
the Team ID per run; it never commits those runtime changes.

### Per-release

- Bump `application/short_version` and `config/version` together when changing
  the marketing version. The workflow uses its monotonically increasing GitHub
  run and attempt numbers for `application/version`, preventing duplicate
  TestFlight build strings without a source edit, including workflow re-runs.
- Confirm `main` is green (see `docs/PA16B_FINAL_REPORT.md` for the reference
  suite run) before triggering.
- Trigger the workflow and enter concise tester notes. The preset declares that
  the game uses no non-exempt encryption, and the upload action sends the same
  answer while waiting for App Store Connect processing. Confirm that declaration
  remains accurate whenever a native SDK or plugin is added, then add internal
  testers.

### If the workflow needs iteration

Untested end to end because Apple credentials are not available in this
workspace. The workflow uses the current `app-store-connect` export method and
auto-detects the generated scheme. The most likely first-run friction is automatic
signing resolving the initial provisioning profile. The `.ipa` is retained as a
run artifact, so it can be inspected or hand-uploaded with Transporter if only
the final upload step needs iteration.

## Route B — local Mac

If you have a Mac with Xcode: install Godot 4.7.2 + iOS export templates, open
the project, Project → Export → iOS, fill Team ID / Bundle Identifier /
provisioning in the dialog, Export Project, then open the generated `.xcodeproj`,
Product → Archive, and Distribute App → App Store Connect → Upload. Same Apple
setup as Route A steps 1–4.

## What is in the repo

- `.github/workflows/ios-testflight.yml` — the pipeline above.
- `ci/ExportOptions.plist` — `xcodebuild -exportArchive` options; `__TEAM_ID__`
  is substituted at run time.
- `ci/validate_ios_release.py` — dependency-free preflight for versions, portrait
  target, arm64, entitlement policy, export declaration, and icon integrity.
- `export_presets.cfg` — `iOS` preset: portrait iPhone target
  (`targeted_device_family=1`), min iOS 14, launch-screen storyboard on the
  splash colour, no unmeasured increased-memory entitlement, no camera / mic /
  photo / tracking, explicit app icons, `export_project_only=true`.
- `project.godot` — `config/version="0.1.0"`,
  `display/window/handheld/orientation="portrait"`, existing
  `audio/general/ios/*` mixing settings.
- `assets/branding/app_icon.png` — 1024×1024, no alpha (App Store compliant).

## Notes

- If analytics or tracking are added later, update `privacy/*` in
  `export_presets.cfg` and the App Store Connect privacy questionnaire.
- If a native dependency adds non-exempt encryption, change both
  `ITSAppUsesNonExemptEncryption` in the preset and
  `uses-non-exempt-encryption` in the workflow after completing Apple's export
  compliance determination.
- `artifacts/balance-2026-09-07/**` emits duplicate-UID import warnings; it is
  excluded from the bundle via the preset `exclude_filter` and does not ship.
- Physical acceptance remains governed by `ALPHA_RC1_DEVICE_TEST.md`. Do not
  start M4.
