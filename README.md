<p align="center">
  <img src="ios/logo.png" width="120" alt="Quit All Logo" />
</p>

<h1 align="center">Quit All — Break Every Habit</h1>

<p align="center">
  Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine —<br/>
  all in one app. Powered by streaks, SOS GIF interventions, offline fallbacks, 2,790+ memes, and no shame.
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"><b>Download on the App Store</b></a> ·
  <a href="https://quit-all.com"><b>quit-all.com</b></a> ·
  <a href="https://quit-all.com/privacy">Privacy</a> ·
  <a href="https://quit-all.com/terms">Terms</a>
</p>

<p align="center">
  <a href="https://www.bestpractices.dev/projects/15503"><img src="https://www.bestpractices.dev/projects/15503/badge" alt="OpenSSF Best Practices"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/apoorvdarshan/quit-all"><img src="https://api.scorecard.dev/projects/github.com/apoorvdarshan/quit-all/badge" alt="OpenSSF Scorecard"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
</p>

---

Monorepo for the **Quit All** iOS app and its marketing website.

## Repo Structure

```
.
├── ios/        # SwiftUI iOS app (Xcode project) + unit and UI tests → App Store
├── store/      # App Store listing, screenshot order and product catalog (source of truth)
├── scripts/    # iOS test runner
└── web/        # Static marketing site + API Worker → quit-all.com
```

## Preview

<p align="center">
  <img src="ios/screenshots/readme-onboarding.jpg" width="155" alt="Quit All onboarding addiction selection" />
  <img src="ios/screenshots/readme-home.jpg" width="155" alt="Quit All home streak dashboard" />
  <img src="ios/screenshots/readme-sos-klipy.jpg" width="155" alt="Quit All SOS craving screen with Powered by KLIPY GIF" />
  <img src="ios/screenshots/readme-sos-offline.jpg" width="155" alt="Quit All SOS craving screen with offline fallback" />
  <img src="ios/screenshots/readme-stats.jpg" width="155" alt="Quit All stats dashboard" />
</p>

<p align="center">
  <sub>Onboarding · Home streaks · SOS GIF intervention · Offline fallback loops · Stats</sub>
</p>

## What's inside

### Features

- **9 addictions, one app** — smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, caffeine
- **SOS craving button** — full-screen takeover with Powered by KLIPY GIFs, bundled offline video loops, and 2,790+ curated memes (motivational, roast, consequence, distraction, relatable)
- **Streak tracking** — giant counter with gold gradient progress ring toward the next milestone
- **Pattern detection** — on-device hourly heatmaps and trigger analysis of your cravings
- **Cost calculator** — money saved, life hours reclaimed, 5-year projection slider, "what you could buy" cards
- **Milestones** — 9 progressive health milestones with shareable cards
- **Home and Lock Screen widgets** — quick progress check-ins outside the app
- **No-shame relapse flow** — log activity, mood, and plan without losing progress stigma
- **Smart notifications** — alerts at your personal high-risk times
- **Hard paywall + 7-day free trial** — RevenueCat + StoreKit 2, Weekly $6.99, Yearly $34.99, Lifetime $69.99

### Tech Stack

| iOS (`ios/`) | Web (`web/`) |
|---|---|
| Swift + SwiftUI (iOS 17+) | Static HTML pages built from TypeScript templates (no framework) |
| CoreData (local-only, no backend) | Plain CSS, self-hosted Cormorant Garamond and Schibsted Grotesk |
| RevenueCat + StoreKit 2 | One small script for the craving-button demo |
| WidgetKit + UserNotifications | JSON-LD structured data, sitemap and 9 habit guides for SEO |
| KLIPY GIF proxy + bundled MP4 fallbacks | Cloudflare Workers Static Assets + a Worker for `/api/*` |
| Dark casino-gold theme, Cormorant serif | Same palette and type as the app |

## Running locally

### iOS

```bash
cd ios
open "Quit All.xcodeproj"
```

Optional SOS video loops are manifest-driven. Add compressed silent MP4/MOV clips under `ios/Quit All/Memes/VideoLoops/` and list them in `ios/Quit All/Memes/VideoLoops.json`.

Full setup → [`ios/README.md`](ios/README.md)

### Web

```bash
cd web
npm ci
npm run dev       # builds dist/ and serves the site and API Worker at http://localhost:8787
npm run check     # lint, type check, tests and build
npm run deploy    # build and deploy to Cloudflare with Wrangler
```

`npm run build` renders every page from `web/src/site/` into `web/dist/` and fails on a broken internal link or missing page metadata. Cloudflare serves `dist/` as static files; `web/src/worker.ts` runs only for `/api/*`.

KLIPY requests are proxied through Cloudflare at `/api/klipy/...` so the iOS app never ships the API key. Configure `KLIPY_API_KEY` with `wrangler secret put KLIPY_API_KEY`, then call endpoints like `/api/klipy/v2/search?q=smoking`. Online GIF content shows Powered by KLIPY attribution in the app. Optional overrides: `KLIPY_API_BASE_URL` and `KLIPY_API_KEY_PARAM`.

The iOS RevenueCat public SDK key is loaded from `/api/app-config` so it can be rotated without shipping a new app build. Configure `REVENUECAT_IOS_API_KEY` as a Cloudflare Worker secret. The app falls back to its bundled public key if the config endpoint is unavailable.

## Testing and releases

### Tests

```bash
bash scripts/test-ios.sh   # unit + UI tests on a temporary iPhone simulator (Xcode 27)
cd web && npm test         # website tests, including fuzz tests for the KLIPY proxy and API routes
```

`ios/QuitAllTests` covers streaks, milestones, savings, habit and relapse storage, craving patterns, the widget snapshot and the premium entitlement rule; `ios/QuitAllUITests` walks through onboarding, the paywall, Home, SOS, relapse, habits, stats and settings. Tests run offline: in Debug simulator builds the app has a test mode that never contacts RevenueCat, the App Store or KLIPY, never asks for notification permission and can't buy anything. The **iOS tests** workflow runs both suites on every pull request and push to `main` that changes the app. Details: [`docs/ios-testing.md`](docs/ios-testing.md).

The **Web** workflow lints, type-checks, tests and builds the site, then smoke-tests the built pages and API Worker. Its fast-check property tests check that the KLIPY proxy never leaks or loses its server-side key, never leaves the KLIPY origin and never forwards client credentials. They run 1,000 cases per property on each change and 50,000 weekly. **CodeQL** scans the Swift app, website and workflows, **Dependency review** blocks pull requests that add vulnerable dependencies, and **OpenSSF Scorecard** reviews the repository's supply-chain security weekly.

### Releases

GitHub Actions builds, signs and uploads the App Store binary — Xcode Cloud's workflow and product for this app were removed on 2026-10-14 and must not be re-created. Pushing a `vX.Y.Z` tag that equals `MARKETING_VERSION` runs [`ios-release.yml`](.github/workflows/ios-release.yml), a thin caller of the shared [store-release](https://github.com/apoorvdarshan/store-release) workflows: it runs the tests, then only the store steps whose repository variables are switched on (`IOS_RELEASE_AUTOMATION`, `IOS_CREATE_VERSION`, `IOS_UPLOAD_BUILD`, `IOS_UPLOAD_LISTING`, `IOS_UPLOAD_WHATS_NEW`, `IOS_UPLOAD_SCREENSHOTS`, `IOS_UPLOAD_CREATIVE_ASSETS`, `IOS_SUBMIT_REVIEW`, `IOS_PUBLIC_RELEASE`; all off by default), and creates the GitHub Release with the matching [`RELEASE_NOTES.md`](RELEASE_NOTES.md) section. **Run workflow** on iOS Release only validates a signed build with App Store Connect and never uploads. The App Store listing, What's New and screenshot order live in [`store/metadata`](store/metadata). Details: [`store/README.md`](store/README.md).

## Links

- **App Store:** https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934
- **Website:** https://quit-all.com
- **Privacy Policy:** https://quit-all.com/privacy
- **Terms of Service:** https://quit-all.com/terms

## Contributing and security

- **Contributing:** [`CONTRIBUTING.md`](CONTRIBUTING.md) — setup, tests and pull requests
- **Code of conduct:** [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- **Security:** report vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md)

## License

[MIT](LICENSE) © 2026 Apoorv Darshan.
