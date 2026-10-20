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
           ─► offline checks of the listing files the enabled switches upload,
              the screenshots' RGB copies, and the header / search results images
              (size, format, no alpha, well-formed file)
           ─► IOS_CREATE_VERSION: create the tag's App Store version if it is missing
           ─► read-only App Store Connect preflight (when a listing, What's New,
              screenshot, creative asset or review switch is on): the version
              exists in a usable state, every locale is there, needed changes are
              possible, a READY_FOR_REVIEW version's draft (with IOS_SUBMIT_REVIEW)
              and the images' Asset Library state (with IOS_UPLOAD_CREATIVE_ASSETS)
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
       IOS_SUBMIT_REVIEW ─► pick and check the version's draft review submission
                            (read-only, before any write) and reserve it
       IOS_UPLOAD_LISTING / IOS_UPLOAD_WHATS_NEW / IOS_UPLOAD_SCREENSHOTS
                         ─► read the live metadata, write only what differs
                            (screenshots are uploaded as RGB copies)
       IOS_UPLOAD_CREATIVE_ASSETS ─► new images: Asset Library upload, then App Review
                                     in a submission of their own
                                  ─► approved images: placed on the version (en-US)
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
review switch on. Header and search results images already in the Asset
Library are never uploaded again, an image already placed is left alone, and
an interrupted image review is finished in the draft it left (see
[below](#header-and-search-results-images)).

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
| `IOS_CREATE_VERSION` | Create the tag's App Store version (Prepare for Submission) when App Store Connect does not have it, before the preflight. An existing version is left alone. Refuses, before anything is built, when another version is still on its way to the store (anything but Ready for Distribution, replaced or removed) or the tag is not newer than every existing version. Tag runs only |
| `IOS_UPLOAD_BUILD` | Build, sign and upload the binary to App Store Connect, then wait for processing |
| `IOS_UPLOAD_LISTING` | Description, keywords, promotional text, marketing and support URLs from `store/metadata/ios/<locale>/` |
| `IOS_UPLOAD_WHATS_NEW` | What's New from `store/metadata/ios/<locale>/whats_new.txt`. `store/metadata/ios/whats_new_version.txt` must equal the tag's version, so last release's text can never ship again |
| `IOS_UPLOAD_SCREENSHOTS` | Replaces the iPhone 6.7"/6.9" (`APP_IPHONE_67`) and 6.5" (`APP_IPHONE_65`) screenshots, and any iPhone Duo or Apple Watch set listed, with the files listed in `store/metadata/ios/<locale>/screenshots.json`, in that order, uploaded as RGB copies (see below). A set whose live files already match (by checksum, in order) is left alone |
| `IOS_UPLOAD_CREATIVE_ASSETS` | Product page header and search results images from `store/creative/ios/`, checked (size, format, no alpha) before the build. A new image is uploaded to the Asset Library once and sent to App Review in a submission of its own; an approved image is placed on the version's en-US page while the version can be edited (see [below](#header-and-search-results-images)). Without images there is nothing to do. Off: never read |
| `IOS_SUBMIT_REVIEW` | Select this run's build and submit the version **and** the Ready-to-Submit products in `store/catalog/products.json` for review. Requires `IOS_UPLOAD_BUILD` |
| `IOS_PUBLIC_RELEASE` | Release automatically after approval. Off = manual release. Requires `IOS_SUBMIT_REVIEW` |
| `IOS_BUILD_POLL_SECONDS` | Poll interval, default 30 (10–600) |
| `IOS_BUILD_WAIT_MINUTES` | Total wait from upload start, default 120 (10–300) |

Copy the names from [`gates.env.example`](gates.env.example). Quit All ships
only on iOS, so there are no Android or shared `STORE_*` switches.

Listing, What's New, screenshots, creative assets and review submission need
the version (for example `1.2.2`) to exist in App Store Connect in an editable
state. With `IOS_CREATE_VERSION` on, the tag run creates a missing version itself;
otherwise create it there before tagging. With any of these switches on, a tag run checks this read-only before anything is built (the
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
store/creative/ios/        App Store product page creative assets (Asset Library)
  header/                  one product page header PNG, exactly 3840×1646 (none yet)
  search-results/          one search results PNG or JPEG, 3:2, 1920 to 3840 wide (none yet)
```

Every locale directory is uploaded; App Store Connect must already have that
locale on the version. Lengths, URLs, the What's New version and every
screenshot are checked before any App Store Connect call. A release run checks
only the files its enabled switches upload, so an unused listing or screenshot
file never blocks a build-only release; the **Store automation (offline)**
workflow checks all of them on every pull request and push to `main` that
touches them. `APPSTORE.md` is a human-readable copy; edit `store/metadata` for
anything automation uploads.

**Screenshots** live beside the listing, one folder per display type:
`store/metadata/ios/en-US/screenshots/APP_IPHONE_67/` (the 6.7"/6.9" slot) and
`store/metadata/ios/en-US/screenshots/APP_IPHONE_65/` (6.5"), 10 each. They are byte-identical to the live listing
(checked by checksum), and `screenshots.json` keeps the live order
(3, 2, 1, 4, 6, 5, 7, 8, 9, 10). With the switch on, each set that differs is
replaced by exactly the listed files (a set whose live files already match by
checksum, in order, is left alone; uploads record the checksum); an unknown
display type, a wrong size, a missing file or more than 10 files fails the run
with a clear message, and so does turning the switch on without any
`screenshots.json`.

App Store screenshots are uploaded as RGB PNGs. App Store Connect refuses a PNG
that stores an alpha channel, even when every pixel is opaque, and the committed
screenshots are RGBA PNGs. So each screenshot is first copied to a temporary
folder: a file that stores alpha is laid over black (transparent pixels become
black, opaque pixels keep their exact colours) with Pillow, at its own size,
keeping its colour profile (ICC profile, sRGB, gamma and chromaticity chunks);
any other file is copied as it is. The files in `store/metadata` are only read,
never rewritten. Without Pillow, a screenshot that stores alpha stops the run.
Right before upload, every copy is checked again, and one that still stores
alpha (PNG colour type 4 or 6, or a `tRNS` chunk) or is not a well-formed PNG
(complete chunks with matching CRCs, image data of the size its header gives,
a final `IEND`) stops the run before anything is sent. A live set counts as up
to date when its checksums match the RGB copies or the committed files, so the
live sets, which hold the committed files, are left alone, and a rerun after an
upload uploads nothing again. A Pillow update can change the copies' bytes, so
a set uploaded from copies may be uploaded once more after one.

**Apple Watch and iPhone Duo screenshots** go with the other sets when
`screenshots.json` lists them, under the display type their size picks:
416×496 `APP_WATCH_SERIES_10`, 422×514 or 410×502 `APP_WATCH_ULTRA`, 396×484
`APP_WATCH_SERIES_7`, 368×448 `APP_WATCH_SERIES_4`, 312×390
`APP_WATCH_SERIES_3`, and 1398×2034 (outer screen) or 2007×2853 (inner screen)
`APP_IPHONE_DUO`, which is not in Apple's OpenAPI spec yet but App Store Connect
accepts. A frame listed under another display type fails and names the one its
size belongs to. Quit All has none yet. Like every set, one is replaced only
when its files differ, and only compared while the version is in a review
submission. Watch sets the manifest does not list (such as one uploaded by
hand) are left alone; remove them in App Store Connect if they should go.

## Header and search results images

With `IOS_UPLOAD_CREATIVE_ASSETS` on, the images in `store/creative/ios/` go to
the App Store product page: `header/` takes one PNG of exactly 3840×1646, and
`search-results/` one PNG or JPEG in 3:2, from 1920×1280 to 3840×2560. Neither
may store alpha. `prepare` checks sizes, formats, alpha and that each file is
a complete, well-formed image before anything is built, then (read-only) each
image's Asset Library state the way the store step plans it, so an image the
version cannot take now fails before the build. A slot without an image is left
alone. Quit All has no images yet, so both folders hold only a note and the
switch has nothing to do.

They live in the app's Asset Library and are reviewed on their own, apart from
the version:

1. An image is uploaded once, matched by file name and size. A reservation an
   interrupted upload left in `AWAITING_UPLOAD` (like a failed or archived image)
   does not count, and the image is uploaded again. To change an image, commit
   it under a new file name. An image App Review rejected stops the run until it
   is replaced.
2. A new image goes to App Review in a review submission of its own, never the
   version's draft. A draft an earlier attempt left holding only some of the
   images is finished first, else an empty draft, else a new one is created, so
   re-runs never pile up drafts. The run submits it only when it holds exactly
   these images.
3. Once Apple approves an image, the run places it on the version's en-US
   localization (`POST /v1/appAssetLibraryPlacements`, placement group
   `DEFAULT_PROFILE`), only while the version can be edited (Prepare for
   Submission or rejected). An image already placed there is left alone; another
   image in the same slot is replaced in the same request. Approval takes a while,
   so a new image is usually placed by the next release's run.

While the version is in a review submission (`READY_FOR_REVIEW` or
`WAITING_FOR_REVIEW`), nothing is uploaded, reviewed or placed: an image that
still needs uploading or review fails the run, and an approved image waits for
a later run.

With `IOS_SUBMIT_REVIEW` on, the run picks the version's draft review submission
before anything is written: the draft that already holds the version, else a
draft holding no app version, never one holding header or search results images.
That draft is reserved for the version and its products, so image reviews never
take it. A `READY_FOR_REVIEW` version that no such draft holds stops the run in
`prepare`, before the build, and the store step checks it again before its first
write.

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
   `IOS_UPLOAD_SCREENSHOTS`, `IOS_UPLOAD_CREATIVE_ASSETS` or `IOS_SUBMIT_REVIEW`
   is on, the 1.2.2 App Store version must exist. With `IOS_CREATE_VERSION` on,
   the tag run creates it; otherwise **create it in App Store Connect first** (it stays in Prepare for
   Submission). The preflight stops the run before the build if it is missing.
5. Optionally run **iOS Release → Run workflow** with `marketing_version`
   `1.2.2` (validation only; nothing is uploaded).
6. Merge, then push the `v1.2.2` tag only when you intend that release.

## Export compliance

The app declares its export compliance answer in its build settings
(`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`, so every build's
`Info.plist` carries `ITSAppUsesNonExemptEncryption = false`). Without it, App
Store Connect asks about each build by hand, and review submission fails with
`usesNonExemptEncryption` missing (version 1.2.2's first run did).

`NO` is right while the app only uses exempt encryption: HTTPS (Apple's
networking and the RevenueCat SDK), Keychain and Apple's system crypto. If the
app ever adds its own encryption, set it to `YES` and add
`INFOPLIST_KEY_ITSEncryptionExportComplianceCode` with the code App Store
Connect issues for the app's encryption documentation.

Release and validation runs check it twice: `ios_release.py gates` reads each
configuration (Debug and Release) of the app target before anything is built,
and `verify_ios_bundles.sh` reads the
archived app's `Info.plist`. A missing key, or `YES` without the code, fails
the run.

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
sends nothing. (A rerun that finds the version already waiting for review with
this run's build sends a late product in a draft of its own.) The deprecated `inAppPurchaseSubmissions` endpoint, which sent a
purchase to review on its own and immediately, is not used. If a required
product cannot be attached, the version is not submitted. The offline tests
check that the catalog, `SubscriptionProduct` in `PaywallManager.swift` and
`Products.storekit` list the same product ids.

## Scripts

| Script | Role |
|--------|------|
| [`scripts/store/ios_release.py`](../scripts/store/ios_release.py) | Switches, tag/version check, build number, wait for this run's build |
| [`scripts/store/asc_release.py`](../scripts/store/asc_release.py) | Version creation (`--create-version`), read-only preflight (`--preflight`), listing, What's New, screenshots (RGB copies; iPhone, iPhone Duo and Apple Watch sets), header and search results images, build selection, product + version submission |
| [`scripts/store/verify_ios_bundles.sh`](../scripts/store/verify_ios_bundles.sh) | App and widget identity, version, signature, profile and app group checks |
| [`scripts/store/redact_logs.py`](../scripts/store/redact_logs.py) | Removes the App Store Connect key and issuer IDs (and any non-text file) from failure logs before they are kept |
| [`scripts/store/test_ios_release.py`](../scripts/store/test_ios_release.py) | Offline tests: disabled/invalid switches, tag mismatch, validation mode, build wait timeout/failure/ambiguity/mismatch/old build/missing upload time, exact app lookup, selection read-back, preflight, metadata reruns, product submission, the screenshot alpha guard and RGB copies, Apple Watch and iPhone Duo sets, header and search results images (upload, review, placement, drafts), log redaction, token refresh, listing/screenshot/catalog inputs, release notes |
| [`scripts/store/print_gates.py`](../scripts/store/print_gates.py) | Prints the switches (never contacts a store); a value the gates would reject shows as `INVALID` |
| [`scripts/release_notes.py`](../scripts/release_notes.py) | GitHub Release notes from `RELEASE_NOTES.md` (one section per tag) |

`requirements-store.txt` (PyJWT and cryptography, and Pillow for the RGB
screenshot copies) is hash-pinned and installed with `--require-hashes`, in the
release jobs and the offline workflow (whose tests then fail instead of skipping
when Pillow is missing), into the Python 3.13 that `actions/setup-python` sets up
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
python3 -m pip install --require-hashes -r requirements-store.txt   # Pillow, for the RGB copies
python3 -m unittest scripts/store/test_ios_release.py   # CHECK_ONLY_ENABLED_STORE_INPUTS=true: as a release run
python3 scripts/store/print_gates.py
UPLOAD_LISTING=true UPLOAD_WHATS_NEW=true UPLOAD_SCREENSHOTS=true \
  python3 scripts/store/asc_release.py --dry-run --version "$(cat store/metadata/ios/whats_new_version.txt)"
UPLOAD_CREATIVE_ASSETS=true python3 scripts/store/asc_release.py --dry-run   # header / search images
python3 scripts/release_notes.py v1.2.1
```
