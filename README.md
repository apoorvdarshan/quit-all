# Quit All

An iOS app that helps you quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine — all in one app.

## Features

- **8-Step Onboarding Funnel** — Quiz, personalized analysis, symptom check, feature showcase, reviews, custom quit plan, and paywall
- **Streak Tracking** — Giant streak counter with gold gradient progress ring toward next milestone
- **Multiple Addictions** — Track as many as you want with reorderable horizontal scroll cards
- **SOS Craving Screen** — Full-screen takeover with animated GIFs from Giphy, motivational memes, trigger logging, and outcome tracking
- **2,790 Memes** — Curated text memes across 5 categories (Motivational, Roast, Consequence, Distraction, Relatable) + fresh GIFs every session
- **Stats & Patterns** — Overall summary, calendar heatmap, craving frequency charts, hourly heatmaps, trigger breakdown, and pattern insights
- **Cost Calculator** — Money saved, projection slider up to 5 years, "what you could buy" cards, life time saved
- **Currency Selection** — 9 currencies supported (USD, EUR, GBP, INR, CAD, AUD, JPY, CNY, BRL), chosen during onboarding
- **Milestones** — 9 progressive milestones with health facts and shareable cards
- **Relapse Flow** — No-shame relapse logging (activity, mood, plan) with streak reset
- **Smart Notifications** — Pattern-based alerts at your highest risk times
- **Edit & Reorder Addictions** — Edit daily spending, motivation, and drag-to-reorder from Settings
- **StoreKit 2 Paywall** — Monthly ($7.99) and Yearly ($49.99) subscription with free trial
- **Haptic Feedback** — Tactile feedback on all key interactions
- **Dark Casino Gold Theme** — Luxury dark theme (#080808) with gold accents (#D4AF37), serif fonts, and Gemini-generated icons

## Screenshots

Coming soon.

## Tech Stack

- Swift + SwiftUI (iOS 17+)
- CoreData (all data local)
- StoreKit 2 (subscriptions)
- UserNotifications (smart alerts)
- Giphy API (GIF search)
- ImageIO (GIF rendering)
- No backend, no server, no sign-in required

## Setup

1. Clone the repo
2. Create `Secrets.xcconfig` in the project root:
   ```
   GIPHY_API_KEY = your_giphy_api_key
   ```
   Get a free key at [developers.giphy.com](https://developers.giphy.com)
3. Open `Quit All.xcodeproj` in Xcode
4. Build and run

## Project Structure

```
Quit All/
├── Quit_AllApp.swift              # App entry point
├── Persistence.swift              # CoreData stack
├── EnvConfig.swift                # API key config (gitignored)
├── Core/
│   ├── HapticManager.swift        # Haptic feedback
│   ├── NotificationManager.swift  # Smart notifications
│   └── PaywallManager.swift       # StoreKit 2 subscriptions
├── AI/
│   ├── PatternDetector.swift      # Craving pattern analysis
│   └── RelapseAnalyzer.swift      # Relapse trend analysis
├── Memes/
│   ├── GiphyManager.swift         # Giphy API + GIF renderer
│   ├── MemeData.swift             # 2,790 curated text memes
│   └── MemeLibrary.swift          # Meme filtering & selection
├── Tracking/
│   ├── AddictionTracker.swift     # CRUD operations
│   ├── StreakEngine.swift         # Streak calculations
│   ├── CostCalculator.swift       # Savings & life projections
│   └── CravingLogger.swift        # Craving event logging
├── Models/
│   ├── Addiction.swift            # AddictionType enum + colors
│   ├── CravingEvent.swift         # Triggers & moods
│   ├── Milestone.swift            # 9 milestone definitions
│   └── RelapseEvent.swift         # Relapse activities
├── Views/
│   ├── OnboardingView.swift       # 8-step conversion funnel
│   ├── PaywallView.swift          # Subscription paywall
│   ├── HomeView.swift             # Dashboard + streak ring
│   ├── SOSView.swift              # Craving intervention + GIFs
│   ├── MemeBrowseView.swift       # Meme library browser
│   ├── StatsView.swift            # Charts + pattern insights
│   ├── CostView.swift             # Savings calculator
│   ├── MilestonesView.swift       # Progressive milestones
│   ├── RelapseView.swift          # No-shame relapse flow
│   ├── AddictionsView.swift       # Manage & reorder addictions
│   └── SettingsView.swift         # Settings + reset
└── Quit_All.xcdatamodeld          # CoreData model
```

## Supported Addictions

| Type | Accent Color |
|------|-------------|
| Smoking | #607D8B |
| Vaping | #607D8B |
| Alcohol | #FF8F00 |
| Porn | #7B1FA2 |
| Social Media | #1565C0 |
| Weed | #2E7D32 |
| Gambling | #C62828 |
| Overspending | #F9A825 |
| Caffeine | #4E342E |

## License

All rights reserved.
