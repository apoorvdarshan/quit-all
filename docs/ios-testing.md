# iOS testing

The **iOS tests** GitHub Actions workflow builds the Debug app for an iPhone
simulator and runs both `QuitAllTests` (unit) and `QuitAllUITests` (UI) on the
hosted `xcode-27` runner. It runs for pull requests and pushes to `main` that
change the app, its tests or project, the runner script or the workflow, and on
demand. The iOS Release workflow runs it before every tag build. It never
archives, uploads or submits an app.

## Run locally

Use a Mac with Xcode 27 and an iOS 17.6 or newer Simulator runtime:

```sh
bash scripts/test-ios.sh
```

The script creates its own simulator and deletes it afterwards, so existing
simulators and their data are left alone. Packages and build products are
reused under `~/Library/Developer/Xcode/DerivedData/QuitAll-simulator-tests`;
results go to a new `TestResults` subdirectory and the command prints the
`.xcresult` path. Override `IOS_TEST_DERIVED_DATA`, `IOS_TEST_PACKAGES` or
`IOS_TEST_RESULTS` when needed; an existing result bundle is never overwritten.

Tests run in English with the US region (`-testLanguage en -testRegion US`) and
in UTC, so currency, date and streak text is the same on every machine. They run
serially on one simulator. The run fails if any test fails or if either test
bundle ran no tests. On CI, Swift package checkouts are cached by
`Package.resolved`; the build and the test results are never cached. The
`.xcresult` bundle (with failure screenshots), coverage and the build log are
kept as the `ios-test-results` artifact for seven days.

## What the tests cover

- **Unit tests** (`ios/QuitAllTests`): streak math and formatting, milestone
  unlocking and progress, savings, projections and life-time saved, currency
  formatting, habit creation, relapse logging and longest-streak rules, cascade
  deletion, craving logs and the calendar heatmap, pattern and relapse
  insights, the widget snapshot contract, the premium entitlement rule and
  product ids, update-version comparison, bundled memes and offline video
  loops, and Core Data persistence (including reopening an on-disk store).
- **UI tests** (`ios/QuitAllUITests`): the onboarding funnel up to the paywall,
  finishing onboarding with a restored (simulated) entitlement, the hard paywall
  (plans, prices, no purchase possible), Home streaks and savings for two
  habits, milestones and the savings calculator, an SOS craving that is
  survived and shows up in Stats, a relapse that restarts the streak, adding
  and editing habits (with persistence across relaunches), every tab, and
  resetting all data.

## Test mode

Debug simulator builds have a test mode (`ios/Quit All/Core/AppTestEnvironment.swift`).
It turns on when XCTest hosts the app (unit tests) or when a UI test launches
the app with `--ui-testing`. Release builds and device builds compile it out.

In test mode the app never configures RevenueCat, so no store request is made
and nothing can be bought; it never checks the App Store for updates, never
calls the KLIPY GIF proxy (SOS and onboarding use the bundled offline loops)
and never shows the notification permission prompt. UI tests use their own
Core Data store, separate from the simulator app's normal data, and can add:

| Launch argument | Effect |
|-----------------|--------|
| `--ui-testing-reset` | Start with an empty UI-test store and cleared app defaults (simulator only) |
| `--ui-testing-onboarded` | Mark onboarding as finished |
| `--ui-testing-premium` | Simulate an active premium entitlement (RevenueCat is not involved) |
| `--ui-testing-seed-habits` | Add Smoking (10 days clean, $15/day) and Caffeine (3 days clean, $5/day) |

Purchases, restores against a real Apple ID, notifications on a device, the
widget on a Home Screen and live KLIPY GIFs need manual testing on a device or
in the App Store sandbox; these simulator tests do not replace that, nor the
signed Release validation in the iOS Release workflow.
