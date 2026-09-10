# iOS TestFlight build

Status: **CI pipeline scaffolded — needs Apple secrets before it can run.** No
build has been produced. The GitHub Actions workflow builds and uploads from a
hosted macOS runner, so no local Mac is required — but an Apple Developer Program
account and the secrets below are.

This produces the build for the physical session in
[ALPHA_RC1_DEVICE_TEST.md](ALPHA_RC1_DEVICE_TEST.md). A successful upload is not
acceptance.

## Route A — GitHub Actions (default)

`.github/workflows/ios-testflight.yml`, manual trigger (Actions tab → "iOS
TestFlight" → Run workflow). It:

1. installs Godot `4.7.2-stable` + iOS export templates (cached),
2. injects the bundle id and team id into `export_presets.cfg`,
3. exports the Xcode project (`application/export_project_only=true`),
4. archives and exports a signed `.ipa` with `xcodebuild` using App Store Connect
   API-key authentication and automatic signing,
5. uploads to TestFlight and also attaches the `.ipa` as a run artifact.

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

`export_presets.cfg` is committed with those identifier fields **blank on
purpose**; the workflow fills them per run and never commits the result.

### Per-release

- Bump `application/version` (build number) in `export_presets.cfg` — TestFlight
  rejects a duplicate build number. `application/short_version` is the marketing
  version; keep it in step with `config/version` in `project.godot`.
- Confirm `main` is green (see `docs/PA16B_FINAL_REPORT.md` for the reference
  suite run) before triggering.
- Trigger the workflow. Processing on App Store Connect takes a few minutes;
  then complete the export-compliance question (this build uses no non-exempt
  encryption) and add internal testers.

### If the workflow needs iteration

Untested end to end from this repo. Likely first-run friction: the Godot release
asset URL/name for `4.7.2-stable`, the generated Xcode scheme name (the workflow
auto-detects it), `ExportOptions.plist` `method` (`app-store` vs
`app-store-connect` on newer Xcode), and whether automatic signing resolves the
profile on the first archive. The `.ipa` is uploaded as a run artifact so a build
can be inspected or hand-uploaded via Transporter while the upload step is sorted
out.

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
- `export_presets.cfg` — `iOS` preset: portrait iPhone target
  (`targeted_device_family=1`), min iOS 14, launch-screen storyboard on the
  splash colour, `increased_memory_limit` entitlement, no camera / mic / photo /
  tracking, `export_project_only=true`.
- `project.godot` — `config/version="0.1.0"`,
  `display/window/handheld/orientation="portrait"`, existing
  `audio/general/ios/*` mixing settings.
- `assets/branding/app_icon.png` — 1024×1024, no alpha (App Store compliant).

## Notes

- If analytics or tracking are added later, update `privacy/*` in
  `export_presets.cfg` and the App Store Connect privacy questionnaire.
- `artifacts/balance-2026-09-07/**` emits duplicate-UID import warnings; it is
  excluded from the bundle via the preset `exclude_filter` and does not ship.
- Physical acceptance remains governed by `ALPHA_RC1_DEVICE_TEST.md`. Do not
  start M4.
