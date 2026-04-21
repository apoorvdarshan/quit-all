<p align="center">
  <img src="ios/logo.png" width="120" alt="Quit All Logo" />
</p>

<h1 align="center">Quit All — Break Every Habit</h1>

<p align="center">Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine — all in one app.</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"><b>App Store</b></a> ·
  <a href="https://quit-all.com"><b>quit-all.com</b></a>
</p>

---

Monorepo containing the iOS app and the marketing website.

## Structure

```
.
├── ios/    # SwiftUI iOS app (Xcode project) — App Store
└── web/    # Next.js marketing website — quit-all.com
```

## iOS app

SwiftUI + CoreData + StoreKit 2. Dark casino-gold theme. Uses the Giphy API for animated cravings-relief GIFs.

```bash
cd ios
open "Quit All.xcodeproj"
```

Requires `ios/Secrets.xcconfig` (gitignored) with:

```
GIPHY_API_KEY = your_key_here
```

Full details → [`ios/README.md`](ios/README.md)

## Web

Next.js + vanilla CSS. Hosts landing page, Privacy Policy, and Terms of Service.

```bash
cd web
npm install
npm run dev   # http://localhost:3000
```

Deployed on Vercel → [quit-all.com](https://quit-all.com)

Full details → [`web/README.md`](web/README.md)

## License

All rights reserved. © 2026 Apoorv Darshan.
