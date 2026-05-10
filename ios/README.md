<p align="center">
  <img src="logo.png" width="120" alt="Quit All Logo" />
</p>

<h1 align="center">Quit All - Break Every Habit</h1>

<p align="center">Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine — all in one app.</p>

**Website:** [quit-all.com](https://quit-all.com) · Part of the Quit All monorepo

## Features

- **8-Step Onboarding Funnel** — Quiz, personalized analysis, symptom check, feature showcase, reviews, custom quit plan, and paywall
- **Streak Tracking** — Giant streak counter with gold gradient progress ring toward next milestone
- **Multiple Addictions** — Track as many as you want with drag-to-reorder horizontal scroll cards
- **SOS Craving Screen** — Full-screen takeover with bundled local video loops, 2,790+ motivational memes, trigger logging, and outcome tracking
- **Stats & Patterns** — Overall summary, calendar heatmap, craving frequency charts, hourly heatmaps, trigger breakdown, and pattern insights
- **Cost Calculator** — Money saved, projection slider up to 5 years, "what you could buy" cards, life time saved
- **Currency Selection** — 9 currencies (USD, EUR, GBP, INR, CAD, AUD, JPY, CNY, BRL), chosen during onboarding via dropdown
- **Milestones** — 9 progressive milestones with health facts and shareable cards
- **Relapse Flow** — No-shame relapse logging (activity, mood, plan) with instant streak reset
- **Smart Notifications** — Pattern-based alerts at your highest risk times and danger zones
- **Edit & Reorder** — Edit daily spending, motivation, drag-to-reorder, add/remove addictions, and reset order from Settings
- **StoreKit 2 Paywall** — 3-day free trial, Monthly ($7.99) and Yearly ($49.99) subscriptions, manage subscription from Settings
- **Haptic Feedback** — Tactile feedback on all key interactions
- **Dark Casino Gold Theme** — Luxury dark theme with gold accents, Cormorant serif fonts, and Gemini-generated icons

## Screenshots

<p align="center">
  <img src="screenshots/onboarding.png" width="180" />
  <img src="screenshots/sos2.png" width="180" />
  <img src="screenshots/sos1.png" width="180" />
  <img src="screenshots/stats.png" width="180" />
</p>

## Tech Stack

- Swift + SwiftUI (iOS 17+)
- CoreData (all data local, no server)
- StoreKit 2 (subscriptions)
- UserNotifications (smart alerts)
- AVFoundation (silent looping MP4/MOV playback)
- No backend, no sign-in required

## Setup

1. Clone the repo
2. Open `Quit All.xcodeproj` in Xcode
3. Build and run

Optional SOS video loops are local-only. Add compressed silent MP4/MOV files under `Quit All/Memes/VideoLoops/` and list them in `Quit All/Memes/VideoLoops.json`.

Example manifest entry:

```json
{
  "id": "smoking-001",
  "addictionType": "Smoking",
  "fileName": "smoking_001.mp4",
  "title": "Smoking urge loop"
}
```

## Project Structure

```
Quit All/
├── Quit_AllApp.swift              # App entry point
├── Persistence.swift              # CoreData stack
├── Core/
│   ├── HapticManager.swift        # Haptic feedback
│   ├── NotificationManager.swift  # Smart pattern-based notifications
│   └── PaywallManager.swift       # StoreKit 2 subscriptions
├── AI/
│   ├── PatternDetector.swift      # Craving pattern analysis (on-device)
│   └── RelapseAnalyzer.swift      # Relapse trend analysis
├── Memes/
│   ├── LocalVideoLoopLibrary.swift # Bundled video loop loading + playback
│   ├── MemeData.swift             # 2,790 curated text memes
│   └── MemeLibrary.swift          # Meme filtering & selection
├── Tracking/
│   ├── AddictionTracker.swift     # CRUD operations + relapse logging
│   ├── StreakEngine.swift         # Streak calculations + milestone progress
│   ├── CostCalculator.swift       # Savings, projections & life hours saved
│   └── CravingLogger.swift        # Craving event logging & queries
├── Models/
│   ├── Addiction.swift            # AddictionType enum, colors, icons
│   ├── CravingEvent.swift         # Triggers & moods
│   ├── Milestone.swift            # 9 milestone definitions + health facts
│   └── RelapseEvent.swift         # Relapse activities
├── Views/
│   ├── OnboardingView.swift       # 8-step conversion funnel
│   ├── PaywallView.swift          # Subscription paywall
│   ├── HomeView.swift             # Dashboard + gold streak ring
│   ├── SOSView.swift              # Craving intervention + video loops + confetti
│   ├── StatsView.swift            # Overall summary + charts + insights
│   ├── CostView.swift             # Savings calculator + projections
│   ├── MilestonesView.swift       # Progressive milestones + share cards
│   ├── RelapseView.swift          # No-shame relapse flow
│   ├── AddictionsView.swift       # Manage, edit & reorder addictions
│   └── SettingsView.swift         # Settings, manage subscription, full data reset
└── Quit_All.xcdatamodeld          # CoreData model (4 entities)
```

## Supported Addictions

| Type | Color | Icon |
|------|-------|------|
| Smoking | `#607D8B` | Gemini-generated |
| Vaping | `#607D8B` | Gemini-generated |
| Alcohol | `#FF8F00` | Gemini-generated |
| Porn | `#7B1FA2` | Gemini-generated |
| Social Media | `#1565C0` | Gemini-generated |
| Weed | `#2E7D32` | Gemini-generated |
| Gambling | `#C62828` | Gemini-generated |
| Overspending | `#F9A825` | Gemini-generated |
| Caffeine | `#4E342E` | Gemini-generated |

## Links

- **Website:** [quit-all.com](https://quit-all.com)
- **Privacy Policy:** [quit-all.com/privacy](https://quit-all.com/privacy)
- **Terms of Service:** [quit-all.com/terms](https://quit-all.com/terms)

## License

All rights reserved. © 2026 Apoorv Darshan.
