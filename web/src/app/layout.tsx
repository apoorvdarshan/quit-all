import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Quit All — Quit Smoking, Vaping, Alcohol & More in One App",
  description: "Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings with GIFs and offline fallback loops, save money, and use Home Screen or Lock Screen widgets.",
  keywords: [
    "quit smoking app", "stop smoking", "quit smoking tracker", "smoking cessation",
    "stop vaping", "quit vaping app", "vape free",
    "quit drinking", "quit alcohol", "sober tracker", "sobriety app", "sober counter",
    "addiction tracker", "addiction recovery app", "break addiction",
    "dopamine detox", "dopamine detox app", "digital detox",
    "habit tracker", "habit breaker", "bad habit tracker",
    "quit weed", "stop smoking weed", "marijuana quit",
    "stop gambling", "gambling addiction help",
    "quit caffeine", "caffeine free",
    "quit porn", "screen time addiction",
    "sobriety counter", "days sober counter", "clean days tracker",
    "craving help", "craving tracker", "urge surfing",
    "quit all addictions", "multiple addiction tracker",
    "streak tracker", "streak counter app",
    "money saved quitting", "savings from quitting",
    "relapse tracker", "relapse prevention",
    "motivation to quit", "quit smoking motivation",
    "health benefits quitting", "quit smoking health",
    "free trial addiction app", "best quit smoking app 2026",
    "quit all app", "allquit", "all quit addiction tracker",
  ],
  authors: [{ name: "Apoorv Darshan" }],
  creator: "Apoorv Darshan",
  publisher: "Apoorv Darshan",
  metadataBase: new URL("https://www.quit-all.com"),
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://www.quit-all.com",
    siteName: "Quit All",
    title: "Quit All - One App to Quit Smoking, Vaping, Alcohol & More",
    description: "One app to quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings with GIFs, save money, and use widgets.",
    images: [
      {
        url: "/og.png",
        width: 1200,
        height: 630,
        alt: "Quit All - Break Every Habit",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Quit All — Quit Every Addiction in One App",
    description: "Quit smoking, vaping, alcohol & 6 more addictions. Track streaks, survive cravings with GIFs and offline fallback loops, save money.",
    creator: "@apoorvdarshan",
    images: ["/og.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "32x32" },
      { url: "/favicon.png", sizes: "512x512", type: "image/png" },
    ],
    apple: "/apple-touch-icon.png",
  },
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "MobileApplication",
  name: "Quit All - Break Every Habit",
  alternateName: ["Quit All Addiction Tracker", "AllQuit", "Quit All App"],
  url: "https://www.quit-all.com",
  downloadUrl: "https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934",
  image: "https://www.quit-all.com/og.png",
  operatingSystem: "iOS 17+",
  applicationCategory: "HealthApplication",
  applicationSubCategory: "Addiction Recovery",
  inLanguage: "en",
  description: "App to quit smoking, stop vaping, quit drinking alcohol, quit weed, stop gambling, quit caffeine, and break social media addiction. Track sobriety streaks, survive cravings with GIFs and offline fallback loops, see money saved, use widgets, and get pattern-based reminders. 7-day free trial available on weekly and yearly premium when eligible.",
  sameAs: [
    "https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934",
    "https://www.producthunt.com/products/quit-all-break-every-habit",
    "https://www.instagram.com/quitall_com/",
    "https://x.com/apoorvdarshan",
    "https://trustmrr.com/startup/quit-all-break-every-habit",
  ],
  offers: [
    {
      "@type": "Offer",
      price: "6.99",
      priceCurrency: "USD",
      description: "Weekly premium subscription with 7-day free trial when eligible",
    },
    {
      "@type": "Offer",
      price: "34.99",
      priceCurrency: "USD",
      description: "Yearly premium subscription with 7-day free trial when eligible",
    },
    {
      "@type": "Offer",
      price: "69.99",
      priceCurrency: "USD",
      description: "Lifetime premium one-time purchase",
    },
  ],
  author: {
    "@type": "Person",
    name: "Apoorv Darshan",
  },
};

// Organization + WebSite entity graph — helps Google understand the brand
// (searched as "quit all", "allquit", "quitall", "all quit") and can enable
// brand sitelinks in search results.
const entityJsonLd = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": "https://www.quit-all.com/#organization",
      name: "Quit All",
      alternateName: ["AllQuit", "Quit All App", "Quitall"],
      url: "https://www.quit-all.com",
      logo: {
        "@type": "ImageObject",
        url: "https://www.quit-all.com/logo.png",
      },
      sameAs: [
        "https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934",
        "https://www.instagram.com/quitall_com/",
        "https://x.com/apoorvdarshan",
        "https://www.producthunt.com/products/quit-all-break-every-habit",
      ],
    },
    {
      "@type": "WebSite",
      "@id": "https://www.quit-all.com/#website",
      name: "Quit All",
      alternateName: ["AllQuit", "Quitall", "All Quit"],
      url: "https://www.quit-all.com",
      inLanguage: "en",
      publisher: { "@id": "https://www.quit-all.com/#organization" },
    },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="antialiased">
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(entityJsonLd) }}
        />
      </head>
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
