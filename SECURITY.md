# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Quit All, please report it **privately** so it can be fixed before public disclosure.

**Preferred:** use GitHub's [private vulnerability reporting](https://github.com/apoorvdarshan/quit-all/security/advisories/new). Only you and the maintainer can see the report.

**Alternative:** email **ad13dtu@gmail.com**.

Please include:

- A description of the vulnerability
- Steps to reproduce (a minimal proof of concept is ideal)
- The affected component and version: the iOS app version from the **About** screen (or `MARKETING_VERSION` in `ios/Quit All.xcodeproj/project.pbxproj`), or the website URL and date for `web/`
- The potential impact, such as data exposure, key leakage, purchase bypass or code execution
- Your name or handle if you want credit (optional)

You can expect an acknowledgement within **7 days** and a triage result with an estimated fix timeline within **14 days**. Please don't disclose the issue publicly until a fix has shipped to the App Store or been deployed to quit-all.com.

## Supported Versions

Only the latest App Store release of the iOS app and the currently deployed website receive security fixes. The `main` branch tracks the next release.

## Scope

**In scope (iOS app, `ios/`):**

- The SwiftUI app, the Home and Lock Screen widget and the test targets
- Local data: the Core Data store with habits, cravings and relapses, and the widget snapshot shared through the `group.com.apoorvdarshan.quitall` App Group
- Subscriptions and entitlements: RevenueCat and StoreKit 2 (`PaywallManager`), including any way to unlock premium access without a valid purchase
- Network requests to the Quit All proxy for KLIPY GIFs and app configuration, and the App Store update check
- Notification scheduling and its content

**In scope (website and proxy, `web/`):**

- The static site at quit-all.com and its API Worker (`web/src/worker.ts`), deployed to Cloudflare Workers
- The KLIPY proxy (`/api/klipy/...`): exposure of the server-side KLIPY key, requests to anything other than the allow-listed KLIPY endpoints, and header or cookie leakage
- The app configuration endpoint (`/api/app-config`), which serves the public RevenueCat SDK key
- Accuracy of the privacy policy and terms pages

**In scope (release tooling):**

- The GitHub Actions workflows in `.github/workflows/` and the scripts in `scripts/` that build, sign and upload releases, including handling of App Store Connect credentials and redaction of logs and artifacts

**Out of scope:**

- The RevenueCat **public** SDK key (`appl_…`) in the app and `/api/app-config`. It is designed to ship in client apps and is not a secret.
- Vulnerabilities in KLIPY, RevenueCat, Cloudflare or Apple services. Please report those to the vendor.
- Content of third-party GIFs returned by KLIPY
- Attacks that need physical access to an unlocked device or a jailbroken device
- Denial of service through request volume against the website

## Safe Harbor

If you make a good-faith effort to follow this policy during security research, we will not pursue or support legal action related to your research. Don't access or modify other users' data, avoid service disruption, and give us reasonable time to fix the issue before disclosure.

## Credit

Researchers who responsibly disclose valid vulnerabilities are credited in the release notes and in the commit that ships the fix, unless they ask to remain anonymous.
