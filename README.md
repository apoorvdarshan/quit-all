# Quit All

Monorepo for the Quit All addiction recovery app. Quit 9 addictions in one app using memes, GIFs, and streak tracking.

- **App Store:** https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934
- **Website:** https://quit-all.com

## Structure

```
.
├── ios/    # SwiftUI iOS app (Xcode project)
└── web/    # Next.js marketing website (quit-all.com)
```

## iOS app

See [`ios/README.md`](ios/README.md) for setup instructions.

```bash
cd ios
# open Quit All.xcodeproj in Xcode
```

Requires `ios/Secrets.xcconfig` with `GIPHY_API_KEY` (not committed).

## Web

See [`web/README.md`](web/README.md).

```bash
cd web
npm install
npm run dev
```
