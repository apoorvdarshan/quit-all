# Store release automation

GitHub Actions builds, signs and uploads the Quit All iOS app, keeps the App
Store listing in this repo, and creates the GitHub Release for each version tag.

**Nothing reaches the App Store unless its switch is on.** A `vX.Y.Z` tag runs
[`ios-release.yml`](../.github/workflows/ios-release.yml). With every switch off
(the default) a tag runs the tests and creates the GitHub Release, and nothing
else.

**Xcode Cloud:** Quit All no longer uses Xcode Cloud, which used to build every
`v*` tag: its workflow and product were removed in App Store Connect on
2026-10-14. Xcode Cloud workflows live in App Store Connect, not in this repo,
so no GitHub switch could stop one. Never re-create it: a tag must start exactly
one pipeline, or both would upload a build for the same tag.

## Release flow (`vX.Y.Z` tag)

```
vX.Y.Z tag ─► store-script unit tests + release notes check (one non-empty section)
           ─► resolve switches (tag must equal MARKETING_VERSION; bad values fail)
           ─► offline checks of the listing files the enabled switches upload
           ─► read-only App Store Connect preflight (when a listing, What's New,
              screenshot or review switch is on): the version exists in a usable
              state, every locale is there, needed changes are possible
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
       IOS_UPLOAD_LISTING / IOS_UPLOAD_WHATS_NEW / IOS_UPLOAD_SCREENSHOTS
                         ─► read the live metadata, write only what differs
       IOS_SUBMIT_REVIEW ─► select this run's build, read it back, set release type
                         ─► attach Ready-to-Submit products to the draft submission
                         ─► recheck build + selection ─► one submit: version + products
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
uploaded before this run (or has no readable upload time, so that cannot be
ruled out), or is not the build selected on the version. An older build is
never substituted.

Waiting for the build is its own job (`wait-for-build`), which hands the
processed build's id to the store job. When a later store step fails (for
example App Store Connect changed in between), **Re-run failed jobs** reuses
that result instead of waiting again against the original upload deadline,
which would always time out; the store step still re-verifies the build before
selecting it. Use **Re-run failed jobs**, not **Re-run all jobs**: the latter
builds and uploads a new build.

The store step reads the live listing, What's New and screenshots first and
writes only what differs, so a rerun is safe even after the review submission
was started or completed:

| Version state on rerun | Text (listing, What's New) | Screenshots | Review |
|------------------------|----------------------------|-------------|--------|
| Prepare for Submission or rejected | updated where it differs | replaced where a set differs | submitted |
| `READY_FOR_REVIEW` (in an unsubmitted draft, e.g. the submit failed) | updated where it differs | must already match | submitted |
| `WAITING_FOR_REVIEW` (the submit went through) | must already match | must already match | not resubmitted; the run checks that review holds this run's build and sends any late Ready-to-Submit catalog product on its own |

When a change is needed that the state cannot take, the step fails before
writing anything; take the version out of review in App Store Connect, then
rerun. Any other state (in review, approved, live) fails with a metadata or
review switch on.

Tag runs share one concurrency group with `queue: max`: releases run one at a
time, and a newer tag waits in the queue instead of cancelling a pending one.
Manual validation runs each get their own group and never cancel a release.

If the build job fails, its logs are kept as the `ios-release-logs-<run id>-<attempt>`
artifact for 7 days. Artifacts are not masked like the console, so
[`redact_logs.py`](../scripts/store/redact_logs.py) first replaces the App Store
Connect key ID and issuer ID with `<ASC_KEY_ID>` and `<ASC_ISSUER_ID>` in every
file, binary ones included, then removes every file that is not plain UTF-8 text
(binary plists, UTF-16 logs), because an ID could hide there in another
encoding. If redaction fails, no logs are kept.

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
| `IOS_UPLOAD_SCREENSHOTS` | Replaces the iPhone 6.7"/6.9" (`APP_IPHONE_67`) and 6.5" (`APP_IPHONE_65`) screenshots with the files listed in `store/metadata/ios/<locale>/screenshots.json`, in that order. A set whose live files already match (by checksum, in order) is left alone |
| `IOS_SUBMIT_REVIEW` | Select this run's build and submit the version **and** the Ready-to-Submit products in `store/catalog/products.json` for review. Requires `IOS_UPLOAD_BUILD` |
| `IOS_PUBLIC_RELEASE` | Release automatically after approval. Off = manual release. Requires `IOS_SUBMIT_REVIEW` |
| `IOS_BUILD_POLL_SECONDS` | Poll interval, default 30 (10–600) |
| `IOS_BUILD_WAIT_MINUTES` | Total wait from upload start, default 120 (10–300) |

Copy the names from [`gates.env.example`](gates.env.example). Quit All ships
only on iOS, so there are no Android or shared `STORE_*` switches.

Listing, What's New, screenshots and review submission need the version (for
example `1.2.2`) to exist in App Store Connect in an editable state; create it
there before tagging. The automation never creates a version. With any of these
switches on, a tag run checks this read-only before anything is built (the
preflight in the `prepare` job), so a missing or locked version, a missing
locale, or a needed change the version's state cannot take fails the run before
the upload instead of after it. Validation runs never run the preflight.

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
screenshot are checked before any App Store Connect call. A release run checks
only the files its enabled switches upload, so an unused listing or screenshot
file never blocks a build-only release; the **Store automation (offline)**
workflow checks all of them on every pull request and push to `main` that
touches them. `APPSTORE.md` is a human-readable copy; edit `store/metadata` for
anything automation uploads.

**Screenshots** come from the App Store-ready marketing images already in the
repo: `marketing/1260x2736/` (`APP_IPHONE_67`, the 6.7"/6.9" slot) and
`marketing/1242x2688/` (`APP_IPHONE_65`, 6.5"), 10 each. They are byte-identical to the live listing
(checked by checksum), and `screenshots.json` keeps the live order
(3, 2, 1, 4, 6, 5, 7, 8, 9, 10). With the switch on, each set that differs is
replaced by exactly the listed files (a set whose live files already match by
checksum, in order, is left alone; uploads record the checksum); an unknown
display type, a wrong size, a missing file or more than 10 files fails the run
with a clear message, and so does turning the switch on without any
`screenshots.json`.

## Release procedure

1. Bump `MARKETING_VERSION` (app and widget) to the new version, for example
   `1.2.2`.
2. Optionally add one `## v1.2.2` section to
   [`RELEASE_NOTES.md`](../RELEASE_NOTES.md) for the GitHub Release (without
   one, GitHub generates the notes; an empty or duplicated section fails the
   run before anything is built).
3. If `IOS_UPLOAD_WHATS_NEW` is on, update `whats_new.txt` in every locale and
   set `whats_new_version.txt` to `1.2.2`.
4. If any of `IOS_UPLOAD_LISTING`, `IOS_UPLOAD_WHATS_NEW`,
   `IOS_UPLOAD_SCREENSHOTS` or `IOS_SUBMIT_REVIEW` is on, **create the 1.2.2 App
   Store version in App Store Connect first** (it stays in Prepare for
   Submission). The automation never creates one; the preflight stops the run
   before the build if it is missing.
5. Optionally run **iOS Release → Run workflow** with `marketing_version`
   `1.2.2` (validation only; nothing is uploaded).
6. Merge, then push the `v1.2.2` tag only when you intend that release.

## In-app purchases

[`catalog/products.json`](catalog/products.json) lists the products App Store
Connect has for Quit All: the Weekly and Yearly subscriptions (group
`premium`) and the Lifetime Premium one-time purchase, with the RevenueCat
entitlements that unlock them. All three were approved on 2026-10-14, so a
submission today attaches nothing extra. With `IOS_SUBMIT_REVIEW` on, a
listed product that is Ready to Submit (or a subscription left in Developer
Rejected) goes to review with the version, as App Review requires for a
first-time subscription; products not in the catalog are never submitted.
Each product's current version is attached to the same draft review
submission as the app version (`subscriptionVersion` for subscriptions,
`inAppPurchaseVersion` for the lifetime purchase), and nothing reaches App
Review until the one submit after the final build recheck, so a failed recheck
sends nothing. The deprecated `inAppPurchaseSubmissions` endpoint, which sent a
purchase to review on its own and immediately, is not used. If a required
product cannot be attached, the version is not submitted. The offline tests
check that the catalog, `SubscriptionProduct` in `PaywallManager.swift` and
`Products.storekit` list the same product ids.

## Scripts

| Script | Role |
|--------|------|
| [`scripts/store/ios_release.py`](../scripts/store/ios_release.py) | Switches, tag/version check, build number, wait for this run's build |
| [`scripts/store/asc_release.py`](../scripts/store/asc_release.py) | Read-only preflight (`--preflight`), listing, What's New, screenshots, build selection, product + version submission |
| [`scripts/store/verify_ios_bundles.sh`](../scripts/store/verify_ios_bundles.sh) | App and widget identity, version, signature, profile and app group checks |
| [`scripts/store/redact_logs.py`](../scripts/store/redact_logs.py) | Removes the App Store Connect key and issuer IDs (and any non-text file) from failure logs before they are kept |
| [`scripts/store/test_ios_release.py`](../scripts/store/test_ios_release.py) | Offline tests: disabled/invalid switches, tag mismatch, validation mode, build wait timeout/failure/ambiguity/mismatch/old build/missing upload time, exact app lookup, selection read-back, preflight, metadata reruns, product submission, log redaction, token refresh, listing/screenshot/catalog inputs, release notes |
| [`scripts/store/print_gates.py`](../scripts/store/print_gates.py) | Prints the switches (never contacts a store); a value the gates would reject shows as `INVALID` |
| [`scripts/release_notes.py`](../scripts/release_notes.py) | GitHub Release notes from `RELEASE_NOTES.md` (one section per tag) |

`requirements-store.txt` (PyJWT and cryptography) is hash-pinned and installed
with `--require-hashes` into the Python 3.13 that `actions/setup-python` sets up
(never the runner image's system Python); store scripts run unbuffered
(`python3 -u`) so long waits log as they go. Regenerate it from
`requirements-store.in` with the command in that file; Dependabot proposes
monthly updates for it and for the pinned actions
([`dependabot.yml`](../.github/dependabot.yml)). The **Store automation
(offline)** workflow runs the offline tests and a dry run of every App Store
Connect operation on pull requests that touch these files.

## How to enable

The Xcode Cloud workflow and product were removed on 2026-10-14, so a tag
starts only this pipeline.

1. Run **iOS Release → Run workflow** with the next `marketing_version`
   (validation only; nothing is uploaded) and check it passes.
2. Set only the variables you want, plus `IOS_RELEASE_AUTOMATION=true`.
   Start with `IOS_UPLOAD_BUILD`; leave `IOS_SUBMIT_REVIEW` and
   `IOS_PUBLIC_RELEASE` off until you intend that release.
3. Follow the [release procedure](#release-procedure) and push the `vX.Y.Z`
   tag.

## Local dry run

```bash
python3 -m unittest scripts/store/test_ios_release.py   # CHECK_ONLY_ENABLED_STORE_INPUTS=true: as a release run
python3 scripts/store/print_gates.py
UPLOAD_LISTING=true UPLOAD_WHATS_NEW=true UPLOAD_SCREENSHOTS=true \
  python3 scripts/store/asc_release.py --dry-run --version "$(cat store/metadata/ios/whats_new_version.txt)"
python3 scripts/release_notes.py v1.2.1
```
