# Quit All

An iOS app that helps you quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine — all in one app.

## Features

- **Streak Tracking** — Giant streak counter with circular progress ring toward next milestone
- **Multiple Addictions** — Track as many as you want simultaneously with horizontal scroll cards
- **SOS Craving Screen** — Full-screen takeover with animated GIFs, motivational memes, trigger logging, and outcome tracking
- **Meme Library** — 135 curated text memes across 5 categories (Motivational, Roast, Consequence, Distraction, Relatable) + GIFs from Giphy
- **Stats & Patterns** — Calendar heatmap, craving frequency charts, hourly heatmaps, trigger breakdown, and pattern insights
- **Cost Calculator** — Money saved, projection slider up to 5 years, "what you could buy" cards, life time saved
- **Milestones** — 9 progressive milestones with health facts and shareable cards
- **Relapse Flow** — No-shame relapse logging (activity, mood, plan) with streak reset
- **Smart Notifications** — Pattern-based alerts at your highest risk times
- **Haptic Feedback** — Tactile feedback on all key interactions
- **Dark Mode Only** — Full dark theme with per-addiction accent colors

## Screenshots

Coming soon.

## Tech Stack

- Swift + SwiftUI (iOS 17+)
- CoreData (all data local)
- UserNotifications (smart alerts)
- Giphy API (GIF search)
- AVFoundation / ImageIO (GIF rendering)
- No backend, no server, no sign-in required

## Setup

1. Clone the repo
2. Create a `.env` file in the project root:
   ```
   GIPHY_API_KEY=your_giphy_api_key
   ```
   Get a free key at [developers.giphy.com](https://developers.giphy.com)
3. Open `Quit All.xcodeproj` in Xcode
4. Build and run

## Project Structure

```
Quit All/
├── Quit_AllApp.swift          # App entry point
├── Persistence.swift          # CoreData stack
├── Core/
│   ├── HapticManager.swift    # Haptic feedback
│   └── NotificationManager.swift  # Smart notifications
├── AI/
│   ├── PatternDetector.swift  # Craving pattern analysis
│   └── RelapseAnalyzer.swift  # Relapse trend analysis
├── Memes/
│   ├── GiphyManager.swift     # Giphy API + GIF renderer
│   ├── MemeData.swift         # 135 curated text memes
│   └── MemeLibrary.swift      # Meme filtering & selection
├── Tracking/
│   ├── AddictionTracker.swift # CRUD operations
│   ├── StreakEngine.swift     # Streak calculations
│   ├── CostCalculator.swift   # Savings & life projections
│   └── CravingLogger.swift    # Craving event logging
├── Models/
│   ├── Addiction.swift        # AddictionType enum + colors
│   ├── CravingEvent.swift     # Triggers & moods
│   ├── Milestone.swift        # 9 milestone definitions
│   └── RelapseEvent.swift     # Relapse activities
├── Views/
│   ├── OnboardingView.swift   # Addiction picker + setup
│   ├── HomeView.swift         # Dashboard + streak ring
│   ├── SOSView.swift          # Craving intervention + GIFs
│   ├── MemeBrowseView.swift   # Meme library browser
│   ├── StatsView.swift        # Charts + pattern insights
│   ├── CostView.swift         # Savings calculator
│   ├── MilestonesView.swift   # Progressive milestones
│   ├── RelapseView.swift      # No-shame relapse flow
│   ├── AddictionsView.swift   # Manage addictions
│   └── SettingsView.swift     # Settings + reset
└── Quit_All.xcdatamodeld      # CoreData model
```

## Supported Addictions

| Type | Emoji | Accent Color |
|------|-------|-------------|
| Smoking | 🚬 | #607D8B |
| Vaping | 💨 | #607D8B |
| Alcohol | 🍺 | #FF8F00 |
| Porn | 🔞 | #7B1FA2 |
| Social Media | 📱 | #1565C0 |
| Weed | 🌿 | #2E7D32 |
| Gambling | 🎰 | #C62828 |
| Overspending | 💸 | #F9A825 |
| Caffeine | ☕ | #4E342E |

## License

All rights reserved.
