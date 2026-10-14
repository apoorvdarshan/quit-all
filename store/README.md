# Store release automation

GitHub Actions builds, signs and uploads the Quit All iOS app, keeps the App
Store listing in this repo, and creates the GitHub Release for each version tag.

**Nothing reaches the App Store unless its switch is on.** A `vX.Y.Z` tag runs
[`ios-release.yml`](../.github/workflows/ios-release.yml). With every switch off
(the default) a tag runs the tests and creates the GitHub Release, and nothing
else.

**Xcode Cloud:** Quit All is moving off Xcode Cloud, which used to build every
`v*` tag. Its workflow is configured in App Store Connect, not in this repo, so a
GitHub switch cannot stop it. Once it is deleted, never re-create it: a tag must
start exactly one pipeline. Until it is gone, keep `IOS_UPLOAD_BUILD` off, or
both pipelines would upload a build for the same tag.

## Release flow (`vX.Y.Z` tag)

```
vX.Y.Z tag ─► resolve switches (tag must equal MARKETING_VERSION; bad values fail)
           ─► offline store checks + release notes check
           ─► iOS unit and UI tests (ios-tests.yml)
  └─ IOS_RELEASE_AUTOMATION off ─► GitHub Release only
  └─ on:
       IOS_UPLOAD_BUILD ─► next build number from App Store Connect
                        ─► archive Release (CI development identity)
                        ─► verify app + widget: bundle ids, version, build, app group
                        ─► cloud-signed App Store export ─► verify signature, profile,
                           entitlements and app group of the app and the widget
                        ─► upload
                        ─► wait-for-build job: wait until THIS build is VALID
                           (poll 30 s, up to 120 min from upload start)
       IOS_UPLOAD_LISTING / IOS_UPLOAD_WHATS_NEW / IOS_UPLOAD_SCREENSHOTS ─► version metadata
       IOS_SUBMIT_REVIEW ─► select this run's build, read it back, set release type
                         ─► recheck build + selection ─► submit version and products
  └─ GitHub Release (only if every enabled step succeeded)
```

A manual **Run workflow** (`workflow_dispatch`) is a validation run: it archives,
signs, exports and verifies the app and widget, and validates the IPA with App
Store Connect (`altool --validate-app`). It never uploads, edits the listing,
submits or creates a GitHub Release. Apple refuses versions it has already
approved, so fill in the optional **marketing_version** input with the next
version (for example `1.2.2`); the build is validated as that version without
changing the project.

Submission fails instead of continuing when the build times out, fails
processing, is expired, is ambiguous, belongs to another app or version, was
uploaded before this run, or is not the build selected on the version. An
older build is never substituted.

Waiting for the build is its own job (`wait-for-build`), which hands the
processed build's id to the store job. When a later store step fails (for
example App Store Connect changed in between), **Re-run failed jobs** reuses
that result instead of waiting again against the original upload deadline,
which would always time out; the store step still re-verifies the build before
selecting it.

Tag runs share one concurrency group with `queue: max`: releases run one at a
time, and a newer tag waits in the queue instead of cancelling a pending one.
Manual validation runs each get their own group and never cancel a release.

If the build job fails, its logs are kept as the `ios-release-logs-<run id>-<attempt>`
artifact for 7 days, with the App Store Connect key ID and issuer ID replaced by
`<ASC_KEY_ID>` and `<ASC_ISSUER_ID>` (artifacts are not masked like the console).

## Switches

Repository **Variables** (Settings → Secrets and variables → Actions →
Variables). Missing means off. Any value other than
`true/false/yes/no/on/off/1/0` fails the run, even when the master switch is
off, and also fails manual validation runs.

| Variable | When `true` |
|----------|-------------|
| `IOS_RELEASE_AUTOMATION` | Master switch. When off, every iOS store operation below is skipped; the tag still runs the tests and creates the GitHub Release |
| `IOS_UPLOAD_BUILD` | Build, sign and upload the binary to App Store Connect, then wait for processing |
| `IOS_UPLOAD_LISTING` | Description, keywords, promotional text, marketing and support URLs from `store/metadata/ios/<locale>/` |
| `IOS_UPLOAD_WHATS_NEW` | What's New from `store/metadata/ios/<locale>/whats_new.txt`. `store/metadata/ios/whats_new_version.txt` must equal the tag's version, so last release's text can never ship again |
| `IOS_UPLOAD_SCREENSHOTS` | Replaces the iPhone 6.7"/6.9" (`APP_IPHONE_67`) and 6.5" (`APP_IPHONE_65`) screenshots with the files listed in `store/metadata/ios/<locale>/screenshots.json`, in that order |
| `IOS_SUBMIT_REVIEW` | Select this run's build and submit the version **and** the Ready-to-Submit products in `store/catalog/products.json` for review. Requires `IOS_UPLOAD_BUILD` |
| `IOS_PUBLIC_RELEASE` | Release automatically after approval. Off = manual release. Requires `IOS_SUBMIT_REVIEW` |
| `IOS_BUILD_POLL_SECONDS` | Poll interval, default 30 (10–600) |
| `IOS_BUILD_WAIT_MINUTES` | Total wait from upload start, default 120 (10–300) |

Copy the names from [`gates.env.example`](gates.env.example). Quit All ships
only on iOS, so there are no Android or shared `STORE_*` switches.

Listing, What's New, screenshots and review submission need the version (for
example `1.2.2`) to exist in App Store Connect in an editable state; create it
there before tagging. The automation never creates a version.

## Secrets

| Secret | Used for |
|--------|----------|
| `APP_STORE_CONNECT_API_KEY_ID` | Admin-role App Store Connect API key: build numbers, cloud-managed distribution signing, validation, upload, build readiness, listing, review |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer |
| `APP_STORE_CONNECT_API_KEY_P8` | The key's private key (`.p8` body) |
| `IOS_DEV_SIGNING_P12_BASE64` | Shared CI Apple Development identity (base64 `.p12`; certificate "Apple Development: Created via API", ID `NVNGDQGCKK`, expires 2027-10-14) that signs the archive. App Store signing happens at export with Apple's cloud-managed distribution certificate |
| `IOS_DEV_SIGNING_P12_PASSWORD` | Password for that `.p12` |

**CI certificate rotation:** the same development identity is shared by Fud AI,
Verceltics, Abysm, iitjee, Quit All, Scowld and Sesslet, and its private key
exists only in these secrets. Before it expires on 2027-10-14 (or if it is
revoked), create a new Apple Development certificate for CI (App Store Connect
API, `certificateType: DEVELOPMENT`), replace both `IOS_DEV_SIGNING_*` secrets
in every repository that uses it, run each app's validation workflow, then
revoke the old certificate.

## Listing in the repo

The App Store listing is kept here so the repo is the source of truth. It was
exported read-only from the live App Store version 1.2.1 on 2026-10-14; the
only locale App Store Connect has is `en-US`.

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
```

Every locale directory is uploaded; App Store Connect must already have that
locale on the version. Lengths, URLs, the What's New version and every
screenshot are checked before any App Store Connect call. `APPSTORE.md` is a
human-readable copy; edit `store/metadata` for anything automation uploads.

**Screenshots** come from the App Store-ready marketing images already in the
repo: `marketing/1260x2736/` (`APP_IPHONE_67`, the 6.7"/6.9" slot) and
`marketing/1242x2688/` (`APP_IPHONE_65`, 6.5"), 10 each. They are byte-identical to the live listing
(checked by checksum), and `screenshots.json` keeps the live order
(3, 2, 1, 4, 6, 5, 7, 8, 9, 10). With the switch on, each set is replaced by
exactly the listed files; an unknown display type, a wrong size, a missing file
or more than 10 files fails the run with a clear message, and so does turning
the switch on without any `screenshots.json`.

**Before a release:** bump `MARKETING_VERSION` (app and widget), add a
`## vX.Y.Z` section to [`RELEASE_NOTES.md`](../RELEASE_NOTES.md) for the GitHub
Release (without one, GitHub generates the notes), and, if What's New is on,
update `whats_new.txt` and set `whats_new_version.txt` to the new version.

## In-app purchases

[`catalog/products.json`](catalog/products.json) lists the products App Store
Connect has for Quit All: the Weekly and Yearly subscriptions (group
`premium`) and the Lifetime Premium one-time purchase, with the RevenueCat
entitlements that unlock them. All three were approved on 2026-10-14, so a
submission today attaches nothing extra. With `IOS_SUBMIT_REVIEW` on, a
listed product that is Ready to Submit (or a subscription left in Developer
Rejected) goes to review with the version, as App Review requires for a
first-time subscription; products not in the catalog are never submitted. If
a required product cannot be attached, the version is not submitted. The
offline tests check that the catalog, `SubscriptionProduct` in
`PaywallManager.swift` and `Products.storekit` list the same product ids.

## Scripts

| Script | Role |
|--------|------|
| [`scripts/store/ios_release.py`](../scripts/store/ios_release.py) | Switches, tag/version check, build number, wait for this run's build |
| [`scripts/store/asc_release.py`](../scripts/store/asc_release.py) | Listing, What's New, screenshots, build selection, product + version submission |
| [`scripts/store/verify_ios_bundles.sh`](../scripts/store/verify_ios_bundles.sh) | App and widget identity, version, signature, profile and app group checks |
| [`scripts/store/test_ios_release.py`](../scripts/store/test_ios_release.py) | Offline tests: disabled/invalid switches, tag mismatch, validation mode, build wait timeout/failure/ambiguity/mismatch/old build, selection read-back, token refresh, listing/screenshot/catalog inputs |
| [`scripts/store/print_gates.py`](../scripts/store/print_gates.py) | Prints the switches (never contacts a store) |
| [`scripts/release_notes.py`](../scripts/release_notes.py) | GitHub Release notes from `RELEASE_NOTES.md` |

`requirements-store.txt` (PyJWT and cryptography) is hash-pinned and installed
with `--require-hashes`; regenerate it from `requirements-store.in` with the
command in that file. The **Store automation (offline)** workflow runs the
offline tests and a dry run of every App Store Connect operation on pull
requests that touch these files.

## How to enable

1. Delete the Xcode Cloud workflow and product for Quit All in App Store Connect.
2. Run **iOS Release → Run workflow** with the next `marketing_version`
   (validation only; nothing is uploaded) and check it passes.
3. Set only the variables you want, plus `IOS_RELEASE_AUTOMATION=true`.
   Start with `IOS_UPLOAD_BUILD`; leave `IOS_SUBMIT_REVIEW` and
   `IOS_PUBLIC_RELEASE` off until you intend that release.
4. Bump the version, merge, and push the `vX.Y.Z` tag.

## Local dry run

```bash
python3 -m unittest scripts/store/test_ios_release.py
python3 scripts/store/print_gates.py
UPLOAD_LISTING=true UPLOAD_WHATS_NEW=true UPLOAD_SCREENSHOTS=true \
  python3 scripts/store/asc_release.py --dry-run --version "$(cat store/metadata/ios/whats_new_version.txt)"
python3 scripts/release_notes.py v1.2.1
```
