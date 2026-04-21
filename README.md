<p align="center">
  <img src="ios/logo.png" width="120" alt="Quit All Logo" />
</p>

<h1 align="center">Quit All — Break Every Habit</h1>

<p align="center">
  Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine —<br/>
  all in one app. Powered by streaks, GIFs, 2,790+ memes, and no shame.
</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"><b>Download on the App Store</b></a> ·
  <a href="https://quit-all.com"><b>quit-all.com</b></a> ·
  <a href="https://quit-all.com/privacy">Privacy</a> ·
  <a href="https://quit-all.com/terms">Terms</a>
</p>

---

Monorepo for the **Quit All** iOS app and its marketing website.

## Repo Structure

```
.
├── ios/    # SwiftUI iOS app (Xcode project) → App Store
└── web/    # Next.js marketing site → quit-all.com
```

## Screenshots

<p align="center">
  <img src="ios/screenshots/onboarding.png" width="170" />
  <img src="ios/screenshots/sos2.png" width="170" />
  <img src="ios/screenshots/sos1.png" width="170" />
  <img src="ios/screenshots/stats.png" width="170" />
</p>

## What's inside

### Features

- **9 addictions, one app** — smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, caffeine
- **SOS craving button** — full-screen takeover with animated Giphy GIFs + 2,790+ curated memes (motivational, roast, consequence, distraction, relatable)
- **Streak tracking** — giant counter with gold gradient progress ring toward the next milestone
- **Pattern detection** — on-device hourly heatmaps and trigger analysis of your cravings
- **Cost calculator** — money saved, life hours reclaimed, 5-year projection slider, "what you could buy" cards
- **Milestones** — 9 progressive health milestones with shareable cards
- **No-shame relapse flow** — log activity, mood, and plan without losing progress stigma
- **Smart notifications** — alerts at your personal high-risk times
- **Hard paywall + 3-day free trial** — StoreKit 2, $7.99/month or $49.99/year

### Tech Stack

| iOS (`ios/`) | Web (`web/`) |
|---|---|
| Swift + SwiftUI (iOS 17+) | Next.js + TypeScript |
| CoreData (local-only, no backend) | Vanilla CSS (no Tailwind) |
| StoreKit 2 (subscriptions) | Framer Motion (animations) |
| UserNotifications | JSON-LD structured data for SEO |
| Giphy API (SOS GIFs) | Vercel hosting |
| Dark casino-gold theme, Cormorant serif | Same theme system as iOS |

## Running locally

### iOS

```bash
cd ios
open "Quit All.xcodeproj"
```

Create `ios/Secrets.xcconfig` (gitignored) with your Giphy key:

```
GIPHY_API_KEY = your_key_here
```

A pre-build script injects this into `EnvConfig.swift` at build time, so no keys are committed.

Full setup → [`ios/README.md`](ios/README.md)

### Web

```bash
cd web
npm install
npm run dev    # http://localhost:3000
```

The `web/` folder is the Vercel root — pushes that don't touch `web/` skip deployment.

## Links

- **App Store:** https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934
- **Website:** https://quit-all.com
- **Privacy Policy:** https://quit-all.com/privacy
- **Terms of Service:** https://quit-all.com/terms

## License

All rights reserved. © 2026 Apoorv Darshan.
