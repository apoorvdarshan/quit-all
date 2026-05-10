import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Quit All — Quit Smoking, Vaping, Alcohol & More in One App",
  description: "Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings with local video loops and memes, save money. 100% private, all data on your device.",
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
  ],
  authors: [{ name: "Apoorv Darshan" }],
  creator: "Apoorv Darshan",
  publisher: "Apoorv Darshan",
  metadataBase: new URL("https://quit-all.com"),
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://quit-all.com",
    siteName: "Quit All",
    title: "Quit All - One App to Quit Smoking, Vaping, Alcohol & More",
    description: "One app to quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings, save money.",
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
    description: "Quit smoking, vaping, alcohol & 6 more addictions. Track streaks, survive cravings with local video loops, save money. 100% private.",
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
  alternateName: "Quit All Addiction Tracker",
  operatingSystem: "iOS 17+",
  applicationCategory: "HealthApplication",
  applicationSubCategory: "Addiction Recovery",
  description: "Best app to quit smoking, stop vaping, quit drinking alcohol, quit weed, stop gambling, quit caffeine, and break social media addiction. Track sobriety streaks, survive cravings with memes and local video loops, see money saved, and get pattern-based alerts. 3-day free trial. 100% private.",
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
    description: "3-day free trial, then $7.99/month or $49.99/year",
  },
  author: {
    "@type": "Person",
    name: "Apoorv Darshan",
  },
  aggregateRating: {
    "@type": "AggregateRating",
    ratingValue: "4.8",
    ratingCount: "100",
  },
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
      </head>
      <body className="min-h-screen">{children}<Analytics /></body>
    </html>
  );
}
