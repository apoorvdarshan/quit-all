# Store releases

Quit All's App Store releases run on
[apoorvdarshan/store-release](https://github.com/apoorvdarshan/store-release), a
shared set of reusable workflows and Python tooling that carries this repository's
former release scripts (`scripts/store/` at `34b8198`) unchanged as its `quit-all`
flow. Two thin caller workflows pin it by commit SHA, with the version in a
`# vX.Y.Z` comment (v0.3.0 today):

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| [`ios-release.yml`](../.github/workflows/ios-release.yml) | `vX.Y.Z` tag | release run; the tag must equal `MARKETING_VERSION` |
| | **Run workflow** | validation only: archive, cloud-signed export and App Store Connect validation of the IPA, plus a read-only store plan. Never uploads |
| [`store-checks.yml`](../.github/workflows/store-checks.yml) | pull requests and `main` pushes that touch store files, **Run workflow** | checks the store data, [`store-release.toml`](store-release.toml) and the callers against the pinned version. Never uploads |

**Nothing reaches the App Store unless its switch is on**, and merging never
releases: only a tag push does. The callers are rendered by store-release
(`run.py callers render`); Store checks fails when one is edited by hand or pins
anything but a store-release release. Dependabot moves both pins to a new
store-release release in one PR of its own, seven days after it is published.

How the pipeline behaves is documented in store-release (v0.3.0):
[switches](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/switches.md),
[secrets](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/secrets.md),
[jobs and checks](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/workflows.md),
[Quit All's flow](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/flows.md#quit-all-iosflow--quit-all),
[store plan](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/plan.md),
[re-runs](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/rerun.md),
[the config file](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/config.md)
and [how a new release reaches this repository](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/release-process.md#how-apps-receive-a-release).
This file keeps only Quit All's own facts.

**Xcode Cloud** no longer builds Quit All: its tag-triggered workflow and product
were removed in App Store Connect on 2026-10-14. Xcode Cloud workflows live in App
Store Connect, not in this repository, so no GitHub switch could stop one. Never
re-create it: a tag must start exactly one pipeline, or both would upload a build for
the same tag.

## What this repository keeps

- [`store-release.toml`](store-release.toml): where the store files are and Quit All's
  fixed identities: bundle id `com.apoorvdarshan.Quit-All` and its widget
  `com.apoorvdarshan.Quit-All.Widget` (both in app group
  `group.com.apoorvdarshan.quitall`), App Store Connect app `6760978934`, team
  `23RV7FYH36`, and the Xcode to build with.
- The switches (repository variables) and credentials (repository secrets) below.
- The store files: the listing, What's New and screenshots under
  [`metadata/ios/`](metadata/ios), the header and search results images under
  [`creative/ios/`](creative/ios), the product catalog in
  [`catalog/products.json`](catalog/products.json), and
  [`RELEASE_NOTES.md`](../RELEASE_NOTES.md) (GitHub Release bodies).
  [`APPSTORE.md`](../APPSTORE.md) is a human-readable copy; edit `store/metadata` for
  anything automation uploads.
- The gate a tag run must pass: [`ios-tests.yml`](../.github/workflows/ios-tests.yml)
  (iOS unit and UI tests through [`scripts/test-ios.sh`](../scripts/test-ios.sh)). It
  runs on every tag push, after `prepare`; nothing is built when it fails.

## Current switches

Repository **Variables** (Settings → Secrets and variables → Actions → Variables),
as of 2026-10-21. Missing means off; any value other than
`true/false/yes/no/on/off/1/0` fails the run, even when the master switch is off.

| Variable | Value |
|----------|-------|
| `IOS_RELEASE_AUTOMATION` | `true` |
| `IOS_CREATE_VERSION` | `true` |
| `IOS_UPLOAD_BUILD` | `true` |
| `IOS_UPLOAD_LISTING` | not set (off) |
| `IOS_UPLOAD_WHATS_NEW` | `true` |
| `IOS_UPLOAD_SCREENSHOTS` | not set (off) |
| `IOS_UPLOAD_CREATIVE_ASSETS` | not set (off) |
| `IOS_SUBMIT_REVIEW` | `true` |
| `IOS_PUBLIC_RELEASE` | `true` |
| `IOS_BUILD_POLL_SECONDS` | not set (30) |
| `IOS_BUILD_WAIT_MINUTES` | not set (120) |

What each one does:
[switches](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/switches.md#ios).
Quit All ships only on iOS, so there are no Android or shared `STORE_*` switches.
Every validation run's `store-plan` job prints the values a tag run would read.

## Secrets

| Secret | Used for |
|--------|----------|
| `APP_STORE_CONNECT_API_KEY_ID` | Admin-role App Store Connect API key: build numbers, cloud-managed distribution signing, validation, upload, build readiness, listing, review |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer |
| `APP_STORE_CONNECT_API_KEY_P8` | The key's private key (`.p8` body) |
| `IOS_DEV_SIGNING_P12_BASE64` | Shared CI Apple Development identity (base64 `.p12`; certificate "Apple Development: Created via API", ID `NVNGDQGCKK`, expires 2027-10-14) that signs the archive. App Store signing happens at export with Apple's cloud-managed distribution certificate |
| `IOS_DEV_SIGNING_P12_PASSWORD` | Password for that `.p12` |

[`ios-release.yml`](../.github/workflows/ios-release.yml) passes each job exactly the
secrets it needs, by name; nothing else is shared with store-release. Rotating the
development identity:
[the shared CI signing identity](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/provenance.md#facts-that-only-concern-the-six-apps).

## Release procedure

1. Bump `MARKETING_VERSION` (app and widget) to the new version, for example
   `1.2.2`.
2. Optionally add one `## v1.2.2` section to
   [`RELEASE_NOTES.md`](../RELEASE_NOTES.md) for the GitHub Release (without one,
   GitHub generates the notes; an empty or duplicated section fails the run before
   anything is built).
3. If `IOS_UPLOAD_WHATS_NEW` is on, update `whats_new.txt` in every locale and set
   `store/metadata/ios/whats_new_version.txt` to `1.2.2`, so last release's text can
   never ship again.
4. The listing, What's New, screenshot, image and review switches need App Store
   version 1.2.2 to exist. With `IOS_CREATE_VERSION` on, the tag run creates it;
   otherwise create it in App Store Connect first. `prepare` checks it (read-only)
   and stops before the build when it is missing or locked.
5. Run **iOS Release → Run workflow**. It only validates. Apple refuses versions it
   has already approved, so while the project still has the released version, set
   `marketing_version` to the next one (e.g. `1.2.2`); the build is validated as that
   version without changing the project. Read the `store-plan` job's summary: it
   lists the operations the tag run would make with the current switches and every
   check that would stop it. While the version does not exist yet, it still runs the
   checks that need no version (the catalog, the files the enabled switches upload,
   including `whats_new_version.txt`, and the review drafts) and names what it can
   check only once the tag run has created the version.
6. Merge, then push the `v1.2.2` tag only when you intend that release. Tag runs
   queue one at a time; a newer tag never cancels a waiting one.
7. If a later step fails, fix the cause and use **Re-run failed jobs**, not **Re-run
   all jobs** (which would build and upload a new build)
   ([re-runs](https://github.com/apoorvdarshan/store-release/blob/v0.3.0/docs/rerun.md)).

## Export compliance

The app declares its export compliance answer in its build settings
(`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, so every build's `Info.plist`
carries `ITSAppUsesNonExemptEncryption = false`). Without it, App Store Connect asks
about each build by hand, and review submission fails with `usesNonExemptEncryption`
missing (version 1.2.2's first run did).

`NO` is right while the app only uses exempt encryption: HTTPS (Apple's networking
and the RevenueCat SDK), Keychain and Apple's system crypto. If the app ever adds its
own encryption, set it to `YES` and add
`INFOPLIST_KEY_ITSEncryptionExportComplianceCode` with the code App Store Connect
issues for the app's encryption documentation.

Release and validation runs check it twice: `prepare` reads each configuration
(Debug and Release) of the app target before anything is built, and the archived
app's `Info.plist` is checked right after archiving. A missing key, or `YES` without
the code, fails the run.

## Listing and screenshots

The App Store listing was exported read-only from the live App Store version 1.2.1 on
2026-10-14; the only locale App Store Connect has is `en-US`.

```
store/metadata/ios/
  whats_new_version.txt    version the What's New text was written for
  en-US/
    description.txt        uploaded with IOS_UPLOAD_LISTING (max 4000)
    keywords.txt           uploaded with IOS_UPLOAD_LISTING (max 100)
    promotional_text.txt   uploaded with IOS_UPLOAD_LISTING (max 170)
    marketing_url.txt      uploaded with IOS_UPLOAD_LISTING
    support_url.txt        uploaded with IOS_UPLOAD_LISTING
    whats_new.txt          uploaded with IOS_UPLOAD_WHATS_NEW (max 4000)
    screenshots.json       uploaded with IOS_UPLOAD_SCREENSHOTS
    name.txt               reference only (App Information; not uploaded)
    subtitle.txt           reference only (App Information; not uploaded)
    privacy_url.txt        reference only (App Information; not uploaded)
store/creative/ios/        App Store product page creative assets (Asset Library)
  header/                  one product page header PNG, exactly 3840×1646 (none yet)
  search-results/          one search results PNG or JPEG, 3:2, 1920 to 3840 wide (none yet)
```

Every locale directory is uploaded; App Store Connect must already have that locale
on the version. A release run checks only the files its enabled switches upload, so
an unused listing or screenshot file never blocks a build-only release; **Store
checks** checks all of them on every pull request and push to `main` that touches
them.

**Screenshots** live beside the listing, one folder per display type:
`store/metadata/ios/en-US/screenshots/APP_IPHONE_67/` (the 6.7"/6.9" slot) and
`store/metadata/ios/en-US/screenshots/APP_IPHONE_65/` (6.5"), 10 each. They are
byte-identical to the live listing (checked by checksum), and `screenshots.json`
keeps the live order (3, 2, 1, 4, 6, 5, 7, 8, 9, 10). The committed files are RGBA
PNGs, which App Store Connect refuses, so they are uploaded as RGB copies made at
upload time; the files in `store/metadata` are only read. A live set counts as up to
date when its checksums match the RGB copies or the committed files, so the live
sets are left alone. Quit All has no Apple Watch or iPhone Duo screenshots.

## Header and search results images

With `IOS_UPLOAD_CREATIVE_ASSETS` on, the images in `store/creative/ios/` go to the
App Store product page: `header/` takes one PNG of exactly 3840×1646, and
`search-results/` one PNG or JPEG in 3:2, from 1920×1280 to 3840×2560. Neither may
store alpha. A new image is uploaded to the Asset Library once, sent to App Review in
a submission of its own (never the version's draft), and placed on the version's
en-US page once approved, while the version can be edited. Quit All has no images
yet, so both folders hold only a note and the switch has nothing to do.

## In-app purchases

[`catalog/products.json`](catalog/products.json) lists the products App Store Connect
has for Quit All: the Weekly and Yearly subscriptions (group `premium`) and the
Lifetime Premium one-time purchase, with the RevenueCat entitlements that unlock
them. All three were approved on 2026-10-14, so a submission today attaches nothing
extra. With `IOS_SUBMIT_REVIEW` on, a listed product that is Ready to Submit (or a
subscription left in Developer Rejected) goes to review with the version, in the same
draft review submission, as App Review requires for a first-time subscription;
products not in the catalog are never submitted. If a required product cannot be
attached, the version is not submitted. Store checks fails unless the catalog,
`SubscriptionProduct` in `ios/Quit All/Core/PaywallManager.swift` and
`ios/Quit All/Products.storekit` list the same product ids.

## Checking locally

With Python 3.11 or later (CI uses 3.13), from the repository root:

```bash
git clone --branch v0.3.0 https://github.com/apoorvdarshan/store-release ../store-release
python3 -I -u ../store-release/run.py --app-root . config check --files
python3 -I -u ../store-release/run.py --app-root . catalog check
python3 -I -u ../store-release/run.py --app-root . release-notes --check-headings
IOS_SUBMIT_REVIEW=maybe python3 -I -u ../store-release/run.py print-switches --platform ios   # shows INVALID
```

These read only this checkout and call no store API.
