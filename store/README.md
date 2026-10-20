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
           ─► IOS_CREATE_VERSION: create the tag's App Store version if it is missing
           ─► IOS_CREATE_PRODUCTS: read-only plan of every catalog product (fields,
              review screenshot, price point, territories); then create the missing
              ones, Ready to Submit (see Creating products)
           ─► read-only App Store Connect preflight (when a listing, What's New,
              screenshot, creative asset or review switch is on): the version exists
              in a usable state, every locale is there, needed changes are possible
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
       IOS_UPLOAD_CREATIVE_ASSETS ─► header / search results images: upload and
                                     review new ones on their own, place approved ones
       IOS_SUBMIT_REVIEW ─► select this run's build, read it back, set release type
                         ─► attach Ready-to-Submit catalog products (including ones
                            IOS_CREATE_PRODUCTS created) to the draft submission
                         ─► recheck build + selection, check the draft holds only
                            this version and catalog products
                         ─► one submit: version + products
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

### App Store Connect CLI (`asc`)

Every App Store Connect call goes through the
[App Store Connect CLI](https://github.com/rorkai/App-Store-Connect-CLI) (`asc`,
MIT) instead of hand-written API code (the same setup as Fud AI).
[`scripts/store/asc_cli.py`](../scripts/store/asc_cli.py) is the only place
that runs it:

- It is pinned to one release (`ASC_VERSION`, today 5.15.0) and installed by
  `asc_cli.py install`, which refuses a binary whose SHA-256 differs from the
  pinned value for that platform (`linux_amd64` and `macOS_arm64`). Every job
  runs `asc_cli.py check`, and every run re-checks the checksum of the `asc` on
  `PATH` before handing it credentials; no environment variable can point the
  scripts at another executable.
- Credentials come only from the `APP_STORE_CONNECT_*` secrets, through asc's
  own environment variables; the keychain and asc config files are bypassed,
  and `ASC_STRICT_AUTH` rejects credentials mixed from several sources.
- Telemetry (`ASC_TELEMETRY_DISABLED`, `DO_NOT_TRACK`) and the skills update
  check are off.
- Checks that must never write run asc read-only (`ASC_READ_ONLY`): the
  preflight, the product plan, build numbering, the build wait, and the whole
  `prepare` job on validation runs. asc refuses a write in that mode before
  sending it (exit 6).
- On failure the error keeps asc's exit code and drops the key and issuer IDs.
  asc retries a failed read itself (`ASC_MAX_RETRIES=5`). The build wait then
  also retries asc's server-side exit codes (HTTP 5xx, 408, 429 and timeouts)
  and network drops, which asc reports as a generic exit 1 with a connection
  error; auth, usage and not-found errors stop at once.

The binary itself is still exported and uploaded by `xcodebuild`. To move to a
newer asc, change `ASC_VERSION` and both `ASC_SHA256` values from that release's
`asc_<version>_checksums.txt`, then run the store tests.

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

Creative assets follow the screenshots column: in `READY_FOR_REVIEW` and
`WAITING_FOR_REVIEW` nothing is uploaded, sent to review or placed, so the
step passes only when each image is already placed, still in App Review, or
approved and waiting to be placed once the version can be edited.
When a change is needed that the state cannot take, the step fails before
writing anything; take the version out of review in App Store Connect, then
rerun. Any other state (in review, approved, live) fails with a metadata,
creative asset or review switch on.

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
| `IOS_CREATE_PRODUCTS` | Create every iOS product in `store/catalog/products.json` that App Store Connect does not have yet (matched by product ID) and bring it to Ready to Submit, in `prepare`, before anything is built, so `IOS_SUBMIT_REVIEW` sends it to review in the same run. A read-only plan of every product runs first and must pass completely (fields, review screenshot, price point, territories), so a problem stops the run before any write. Existing products are never changed: their period, type, and price and family sharing when the catalog sets them, are compared and differences printed as warnings. One left in Missing Metadata by an interrupted run is finished, never created twice. Tag runs only; validation runs print the plan read-only (see [Creating products](#creating-products-ios_create_products)) |
| `IOS_UPLOAD_BUILD` | Build, sign and upload the binary to App Store Connect, then wait for processing |
| `IOS_UPLOAD_LISTING` | Description, keywords, promotional text, marketing and support URLs from `store/metadata/ios/<locale>/` |
| `IOS_UPLOAD_WHATS_NEW` | What's New from `store/metadata/ios/<locale>/whats_new.txt`. `store/metadata/ios/whats_new_version.txt` must equal the tag's version, so last release's text can never ship again |
| `IOS_UPLOAD_SCREENSHOTS` | Replaces the iPhone 6.7"/6.9" (`APP_IPHONE_67`) and 6.5" (`APP_IPHONE_65`) screenshots with the files listed in `store/metadata/ios/<locale>/screenshots.json`, in that order. A set whose live files already match (by checksum, in order) is left alone |
| `IOS_UPLOAD_CREATIVE_ASSETS` | Product page header and search results images from `store/creative/ios` (see below). A new image is uploaded to the Asset Library and sent to App Review in a submission of its own; once Apple approves it, a later run places it on every listing locale of the version (or swaps it in for the image there). Never changes anything while the version waits for review |
| `IOS_SUBMIT_REVIEW` | Select this run's build and submit the version **and** the Ready-to-Submit products in `store/catalog/products.json` whose `platforms` list `ios` (including ones `IOS_CREATE_PRODUCTS` created earlier in the run) for review. Requires `IOS_UPLOAD_BUILD` |
| `IOS_PUBLIC_RELEASE` | Release automatically after approval. Off = manual release. Requires `IOS_SUBMIT_REVIEW` |
| `IOS_BUILD_POLL_SECONDS` | Poll interval, default 30 (10–600) |
| `IOS_BUILD_WAIT_MINUTES` | Total wait from upload start, default 120 (10–300) |

Copy the names from [`gates.env.example`](gates.env.example). Quit All ships
only on iOS, so there are no Android or shared `STORE_*` switches.

Listing, What's New, screenshots, creative assets and review submission need
the version (for example `1.2.2`) to exist in App Store Connect in an editable
state. With `IOS_CREATE_VERSION` on, the tag run creates a missing version
itself; otherwise create it there before tagging. With any of these switches
on, a tag run checks this read-only before anything is built (the preflight in
the `prepare` job), so a missing or locked version, a missing locale, or a
needed change the version's state cannot take fails the run before the upload
instead of after it. Validation runs never run the preflight.

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
store/creative/ios/        App Store creative assets (IOS_UPLOAD_CREATIVE_ASSETS); none yet
  header/                  one product page header image, 3840×1646 PNG
  search-results/          one search results image, 3:2 PNG or JPEG, 1920×1280 to 3840×2560
                           (a 5244×2950 PNG is a universal image that fits either slot)
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

App Store Connect, and `asc` before it uploads, refuses a PNG that stores an
alpha channel, even when every pixel is opaque. The committed screenshots are
RGBA PNGs, so a set that has to be replaced is uploaded from a temporary
folder of RGB copies: each file that stores alpha is flattened once, at its
own size, onto black (transparent pixels become black, opaque pixels keep
their exact colors) with Pillow, pinned with hashes in
[`requirements-store.txt`](../requirements-store.txt). The committed files are
never changed. Every staged copy is checked for alpha again just before the
upload, and one that still has it stops the run. A live set counts as up to
date when its checksums match the committed files or the RGB copies made from
them, so a rerun uploads nothing again. Without Pillow, a set that would need
RGB copies stops the release in the preflight, before anything is built.

**Creative assets** (the product page header and search results images) have
no images yet, so `IOS_UPLOAD_CREATIVE_ASSETS` stays off; turning it on without
an image fails before any App Store Connect call. To add one, put exactly one
PNG or JPEG in `store/creative/ios/header/` or `store/creative/ios/search-results/`.
An image is matched in the Asset Library by file name and size, so give a
changed image a new file name. Apple reviews each new image on its own (the
app already has an approved version), and a later run places it on every
listing locale once it is approved; a rejected image stops the run with
Apple's reason, and an upload an earlier run left unfinished is uploaded again.
Images never take the draft the version and its products chose. An unfinished
draft holding only these images is finished first, else an empty one, instead
of starting another, so a rerun leaves no extra drafts. Sizes, formats and alpha are checked with the other local inputs,
before the build, so a wrong file stops the run early. An image approved while the version
waits for review is not a mismatch: the rerun passes and the image is placed
once the version can be edited. Apple's rules for these images: no prices,
website addresses, other platforms or Apple badges, and no transparency.

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
   `IOS_UPLOAD_SCREENSHOTS`, `IOS_UPLOAD_CREATIVE_ASSETS` or
   `IOS_SUBMIT_REVIEW` is on, the 1.2.2 App Store version must exist. With
   `IOS_CREATE_VERSION` on, the tag run creates it; otherwise **create it in
   App Store Connect first** (it stays in Prepare for Submission). The
   preflight stops the run before the build if it is missing.
5. New in-app purchase or subscription: add it to `store/catalog/products.json`
   with its `ios` fields and review screenshot (and to `PaywallManager.swift`
   and `Products.storekit`), turn on `IOS_CREATE_PRODUCTS` (and
   `IOS_SUBMIT_REVIEW` to send it with the version), and add it to RevenueCat
   by hand. A validation run (step 6) prints what the tag would create.
6. Optionally run **iOS Release → Run workflow** with `marketing_version`
   `1.2.2` (validation only; nothing is uploaded).
7. Merge, then push the `v1.2.2` tag only when you intend that release.

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
listed product whose `platforms` list `ios` that is Ready to Submit (or a
subscription left in Developer Rejected) goes to review with the version, as
App Review requires for a first-time subscription; products not in the catalog
are never submitted.
Each product's current version is attached to the same draft review
submission as the app version (`subscriptionVersions` items for subscriptions,
`inAppPurchaseVersions` for the lifetime purchase, via `asc review items-add`),
and nothing reaches App Review until the one submit after the final build
recheck, so a failed recheck sends nothing. (A rerun that finds the version
already waiting for review with this run's build sends a late product in a
draft of its own.) A purchase is never sent to App Review on its own and
immediately. If a required product cannot be attached, the version is not
submitted. A reused draft is submitted only when it holds this version and
nothing but versions of catalog products besides it; anything else stops the
run. The draft that already holds this version is reused; otherwise only a
draft holding no app version is, so another version's draft is never touched,
and a `READY_FOR_REVIEW` version that no draft holds stops the run before
anything is written: the draft is checked before the listing text, screenshots,
images or build are touched, and the read-only preflight checks it too, before
anything is built. Drafts holding creative images belong to those images' own
review and are never used for the version. A rerun with nothing left to send
creates no draft. The offline tests check that the catalog,
`SubscriptionProduct` in `PaywallManager.swift` and `Products.storekit` list
the same product ids.

Product groups and their App Store type: `subscriptions` (auto-renewable),
`non_consumables` (`NON_CONSUMABLE`, the lifetime purchase), and the optional
`consumables` and `tips` (`CONSUMABLE`). Only items whose `platforms` list
`ios` are App Store products; Quit All ships on iOS only, so every item does.
The top-level `ios_subscription_groups` names the subscription groups by their
App Store Connect reference name (`premium`, the group Weekly and Yearly belong
to). The existing three products carry no `ios` block: they already exist, so
nothing is invented for them.

### Creating products (`IOS_CREATE_PRODUCTS`)

[`asc_products.py`](../scripts/store/asc_products.py) (the same file as in Fud
AI) matches every iOS product to App Store Connect by product ID:

| In App Store Connect | What a tag run does |
|---|---|
| Missing | Creates it and brings it to Ready to Submit |
| Missing Metadata, with the catalog's reference name, type (or period) and family sharing | Finishes it: an interrupted run left it there. Only missing parts are added; a part that is already set and differs from the catalog (localization, price, availability, review note, or a failed or different review screenshot) stops the run in the plan, before any write. A screenshot that matches the file is kept even while Apple is still processing it |
| Anything else | Never changed. Period and type, and price (United States) and family sharing when the catalog sets them, are compared, and differences are printed as warnings |

The existing products have no `suggested_price_usd` or `ios.family_sharing`,
so their price and family sharing are not compared; their period and type are.

What a created product gets, all from the catalog:

| Part | Source |
|---|---|
| Reference name | `ios.reference_name` (up to 64 characters) |
| Type | the catalog group (above) |
| Subscription group and period | `ios.subscription_group` (a `reference_name` from the top-level `ios_subscription_groups`) and `period` (`P1W`, `P1M`, `P2M`, `P3M`, `P6M`, `P1Y`) |
| Base price | `suggested_price_usd` in the United States (`USA`); App Store Connect derives the other territories' prices from it (Apple's equalized prices). The plan checks it is a price point by asking a live product of the same kind (Quit All has live subscriptions and a live non-consumable, so both kinds are checked that way) |
| Availability | `ios.territories`: `"all"` (the default) is every current territory plus new ones automatically; a list of alpha-3 codes (`["USA", "CAN"]`) is exactly those |
| en-US display name and description | `ios.display_name` (2–30 characters), `ios.description` (up to 45) |
| App Review screenshot | `ios.review_screenshot`: a path under `store/` (keep them in `store/catalog/review/`), a PNG or JPEG named for its format, RGB without alpha, at an iPhone or iPad screenshot size (e.g. 1290×2796 or 2064×2752), and complete (a PNG is fully decoded; a JPEG must reach its end marker) |
| Review note | `ios.review_note` (subscriptions only, up to 4,000 characters) |
| Family sharing | `ios.family_sharing`, default `false`. It can never be turned off again, so it is only sent when the catalog says `true` (subscriptions and non-consumables only) |

A new subscription group also needs `display_name` in its `ios_subscription_groups`
entry (its en-US name); a group App Store Connect already names, like
`premium` ("Quit All Premium"), is never renamed. Comparing an existing
product's price is only a warning, so an App Store Connect error while reading
it is reported and the release goes on. The offline tests check every `ios`
block (including the screenshot file) on every pull request and before every
tag run, and the plan checks, read-only, that each product to create has every
field, that its price is a price point in the United States, and that its
territories exist. Example of a new subscription:

```json
"subscriptions": [
  {
    "id": "com.quitall.premium.monthly",
    "period": "P1M",
    "suggested_price_usd": "4.99",
    "platforms": ["ios"],
    "ios": {
      "reference_name": "Monthly",
      "display_name": "Quit All Premium Monthly",
      "description": "Every Quit All Premium feature",
      "review_note": "Monthly Quit All Premium; the paywall offers it.",
      "review_screenshot": "store/catalog/review/paywall.png",
      "subscription_group": "premium"
    }
  }
]
```

A new product must also be added to `SubscriptionProduct` in
`PaywallManager.swift` and to `Products.storekit` (the offline tests check all
three list the same ids), and to RevenueCat.

How it runs (`prepare` job, after `IOS_CREATE_VERSION` and before the
preflight and anything built): the plan (read-only) checks every product
first; any problem stops the run with nothing created. Subscriptions go
through asc's reconciling `asc subscriptions setup`: once without the
screenshot (group, localization, price, availability), then the review note,
then again with the screenshot, which completes it and verifies the result.
In-app purchases are added one part at a time (product, en-US localization,
price, availability, screenshot last). Because the screenshot is required for
Ready to Submit and always goes last, a product an interrupted run left behind
stays in Missing Metadata, and the next run finishes it. Each product is read
back until it is Ready to Submit (up to 2 minutes). The `prepare` job allows
30 minutes for this. A manual validation run prints the plan and creates
nothing (when `IOS_RELEASE_AUTOMATION` and `IOS_CREATE_PRODUCTS` are on).

What stays manual:

- **RevenueCat**: add each new product to its RevenueCat app, entitlement and
  offering by hand; the app only sells what RevenueCat offers.
- An in-app purchase's review note: the pinned asc 5.15.0 has no command for it,
  so `ios.review_note` is refused on in-app purchases. Add one in App Store
  Connect when App Review needs it.
- Other locales, promotional images, introductory and promotional offers, offer
  codes, a subscription's level within its group, and the app's own product
  list (`PaywallManager.swift`, `Products.storekit`).
- Changing an existing product (price, name, availability); the release only
  warns about differences.
- A new subscription group's own review item, if App Store Connect asks for one:
  the review step attaches subscription and in-app purchase versions only.

## Scripts

| Script | Role |
|--------|------|
| [`scripts/store/ios_release.py`](../scripts/store/ios_release.py) | Switches, tag/version check, build number, wait for this run's build (both read-only) |
| [`scripts/store/asc_cli.py`](../scripts/store/asc_cli.py) | Installs the pinned, checksum-verified `asc` and runs it (credentials, read-only mode, telemetry off, redacted errors) |
| [`scripts/store/asc_products.py`](../scripts/store/asc_products.py) | `plan`: read-only check of the catalog products App Store Connect does not have (or has in Missing Metadata) and drift warnings for the rest; `create` (`CREATE_IOS_PRODUCTS`): the plan, then create or finish them, Ready to Submit. Byte-identical to Fud AI's; its offline field checks run in the store tests |
| [`scripts/store/asc_release.py`](../scripts/store/asc_release.py) | Version creation (`--create-version`), read-only preflight (`--preflight`), listing, What's New, screenshots, header and search results images, build selection, product + version submission; every call through `asc` |
| [`scripts/store/verify_ios_bundles.sh`](../scripts/store/verify_ios_bundles.sh) | App and widget identity, version, signature, profile and app group checks |
| [`scripts/store/redact_logs.py`](../scripts/store/redact_logs.py) | Removes the App Store Connect key and issuer IDs (and any non-text file) from failure logs before they are kept |
| [`scripts/store/test_ios_release.py`](../scripts/store/test_ios_release.py) | Offline tests against a fake App Store Connect behind `asc`: disabled/invalid switches, tag mismatch, validation mode, build wait timeout/failure/ambiguity/mismatch/old build/missing upload time, the pinned app record, selection read-back, preflight, metadata reruns, screenshot order, alpha channels and RGB copies, creative assets, product creation (each type, finishing an interrupted product, drift warnings, failed checks before any write, plan-only validation runs, new products reaching review, the workflow wiring), product submission and draft checks, the asc runner (credentials, read-only, redaction, pinned checksum), log redaction, listing/screenshot/catalog inputs, release notes |
| [`scripts/store/print_gates.py`](../scripts/store/print_gates.py) | Prints the switches (never contacts a store); a value the gates would reject shows as `INVALID` |
| [`scripts/release_notes.py`](../scripts/release_notes.py) | GitHub Release notes from `RELEASE_NOTES.md` (one section per tag) |

The store scripts run on the Python 3.13 that `actions/setup-python` sets up
(never the runner image's system Python); store scripts run unbuffered
(`python3 -u`) so long waits log as they go. Their only Python package is
Pillow, for the RGB screenshot copies: the release jobs and the offline
workflow install [`requirements-store.txt`](../requirements-store.txt)
(compiled from `requirements-store.in`) with `pip --require-hashes`, and the
offline tests there fail instead of skipping when Pillow is missing. The pinned
`asc` is the only tool they download, and only after its checksum matches (see
above). Dependabot proposes monthly updates for the pinned actions and for
Pillow ([`dependabot.yml`](../.github/dependabot.yml)); `asc` is moved to a
newer release by hand. The **Store automation (offline)** workflow runs the
offline tests, installs and checks the pinned `asc`, and dry-runs every App
Store Connect operation on pull requests that touch these files.

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
# Read-only against App Store Connect (needs the APP_STORE_CONNECT_* variables):
ASC_READ_ONLY=1 python3 scripts/store/asc_products.py plan
python3 scripts/release_notes.py v1.2.1
```
