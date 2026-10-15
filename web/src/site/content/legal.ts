// Privacy Policy and Terms of Service, unchanged from the previous site.
// **text** marks emphasis; in a list item, the part before " — " is its name.

export type LegalSection = {
  title: string;
  paragraphs?: string[];
  items?: string[];
};

export type LegalDocument = {
  slug: "privacy" | "terms";
  title: string;
  metaTitle: string;
  metaDescription: string;
  updated: string;
  sections: LegalSection[];
  contactLead: string;
};

export const privacy: LegalDocument = {
  slug: "privacy",
  title: "Privacy Policy",
  metaTitle: "Privacy Policy — Quit All",
  metaDescription:
    "Quit All Privacy Policy. Habit data stays on your device, no account required. Purchases are handled by Apple and RevenueCat; SOS GIFs use Klipy through a Cloudflare proxy. No ad tracking, no habit data sold.",
  updated: "July 10, 2026",
  sections: [
    {
      title: "Overview",
      paragraphs: [
        "Quit All (“we”, “our”, “the app”) is committed to protecting your privacy. This Privacy Policy explains how the app and website handle information.",
      ],
    },
    {
      title: "Data Collection",
      paragraphs: [
        "Quit All does **not** require an account and does not send your habit history, craving logs, relapse notes, milestones, or addiction settings to our servers.",
      ],
      items: [
        "Addiction tracking data — stored locally on your device using CoreData",
        "Craving logs, relapse history, milestones — stored locally, never transmitted",
        "Widget snapshots — stored locally in the app group so Home Screen and Lock Screen widgets can display progress",
        "No accounts — no sign-up, no login, no email required",
        "No advertising — we do not sell your data or share habit data with advertisers",
      ],
    },
    {
      title: "Third-Party Services",
      items: [
        "Apple StoreKit and App Store — Used for subscriptions, lifetime purchases, trials, refunds, refund-request review, and purchase management. Payment processing and final refund decisions are handled by Apple.",
        "RevenueCat — Used to manage purchase entitlements and refund-request handling. RevenueCat may receive an anonymous app user ID, product identifiers, transaction receipts, entitlement status, refund history, and app/device metadata needed to validate access and send Apple purchase context plus our refund preference. Quit All does not send your habit logs or relapse history to RevenueCat.",
        "Klipy GIF API — Used to show online GIFs in SOS mode. Requests are routed through our Cloudflare API proxy so the Klipy API key is not shipped in the app. Search/category requests and standard request metadata may be processed to return GIF results.",
        "Cloudflare — Hosts quit-all.com and API proxy routes used for app configuration and Klipy requests. Server logs may include request URL, IP address, user agent, and timestamps for security and debugging.",
        "Apple Local Notifications — Used for smart reminders at your configured risk times. Notification schedules are generated on device.",
      ],
    },
    {
      title: "Data Storage",
      paragraphs: [
        "Your app data is stored locally on your device. If you delete the app, local app data may be permanently deleted. We do not keep backups of your habit history.",
      ],
    },
    {
      title: "Purchases",
      paragraphs: [
        "Purchases are processed by Apple and entitlement status is managed with RevenueCat. You can manage subscriptions, cancellations, and refunds through your Apple ID or App Store settings. When Apple asks for refund-request information, we may configure RevenueCat to use the Always prefer declining refunds setting and send Apple purchase and entitlement context plus our preference that Apple decline refunds for fulfilled purchases, while Apple makes the final decision.",
      ],
    },
    {
      title: "Children’s Privacy",
      paragraphs: ["Quit All is rated 18+ and is not intended for children. We do not knowingly collect data from children."],
    },
    {
      title: "Changes to This Policy",
      paragraphs: ["We may update this Privacy Policy from time to time. Changes will be reflected on this page with an updated date."],
    },
  ],
  contactLead: "Questions about this Privacy Policy? Reach out at",
};

export const terms: LegalDocument = {
  slug: "terms",
  title: "Terms of Service",
  metaTitle: "Terms of Service — Quit All",
  metaDescription:
    "Quit All Terms of Service. Subscription and lifetime purchase terms, medical disclaimer, third-party services, and usage terms for the Quit All addiction-tracking iOS app.",
  updated: "July 10, 2026",
  sections: [
    {
      title: "Acceptance of Terms",
      paragraphs: [
        "By downloading or using Quit All, you agree to these Terms of Service. If you do not agree, do not use the app.",
      ],
    },
    {
      title: "Description of Service",
      paragraphs: [
        "Quit All is a habit-tracking and addiction recovery app. It provides tools for tracking sobriety streaks, logging cravings and relapses, viewing motivational GIFs, memes, and offline fallback loops, monitoring savings, and using widgets. The app is not a substitute for professional medical advice, diagnosis, or treatment.",
      ],
    },
    {
      title: "Subscriptions and Purchases",
      items: [
        "Quit All offers auto-renewable subscriptions: Weekly ($6.99/week) and Yearly ($34.99/year)",
        "The Weekly and Yearly subscriptions include a 7-day free trial when eligible",
        "Quit All also offers a Lifetime Premium non-consumable purchase ($69.99 one-time)",
        "Prices may vary by country, currency, taxes, App Store price changes, and Apple regional pricing",
        "Payment is charged to your Apple ID account at confirmation or at the end of a trial period when a trial applies",
        "Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period",
        "You can manage and cancel subscriptions in your Apple ID account settings",
        "Refunds, billing issues, and purchase disputes are handled by Apple under App Store policies",
        "When Apple asks for refund-request information, we may configure RevenueCat with the Always prefer declining refunds setting and send Apple purchase and entitlement context plus our preference that Apple decline refunds for fulfilled purchases",
        "Our refund preference is not a guarantee; Apple makes the final decision under App Store policies",
        "Purchase access is managed using RevenueCat and Apple StoreKit",
      ],
    },
    {
      title: "Medical Disclaimer",
      paragraphs: [
        "Quit All is **not** a medical app. It does **not** provide medical advice, diagnosis, or treatment. If you are dealing with substance abuse or addiction, please consult a healthcare professional. The app is a supplementary tool and should **not** replace professional help.",
      ],
    },
    {
      title: "Content",
      paragraphs: [
        "GIFs, memes, local video loops, and motivational text in the app are for entertainment, distraction, and motivation purposes only. Some content may contain humor about addiction. Online GIF availability depends on third-party services and network connectivity.",
      ],
    },
    {
      title: "User Responsibility",
      items: [
        "You are responsible for maintaining the confidentiality of your data",
        "You agree not to misuse the app or attempt to reverse-engineer it",
        "You acknowledge that the app stores data locally and data loss may occur if the app is deleted",
        "You are responsible for seeking professional help when cravings, withdrawal, substance use, self-harm risk, or compulsive behavior require medical or mental health support",
      ],
    },
    {
      title: "Third-Party Services",
      paragraphs: [
        "Quit All uses Apple StoreKit/App Store for purchases and refunds, RevenueCat for entitlement management and refund-request handling, Klipy for online GIF content, and Cloudflare for the website and API proxy. These services may be subject to their own terms and availability.",
      ],
    },
    {
      title: "Limitation of Liability",
      paragraphs: [
        "Quit All is provided “as is” without warranties of any kind. We are not liable for any damages arising from the use or inability to use the app, including but not limited to relapse, health complications, purchase issues handled by Apple, third-party service outages, or data loss.",
      ],
    },
    {
      title: "Changes to These Terms",
      paragraphs: [
        "We reserve the right to modify these Terms at any time. Continued use of the app after changes constitutes acceptance of updated Terms.",
      ],
    },
  ],
  contactLead: "For questions about these Terms, contact us at",
};
