import type { Metadata } from "next";
import { Analytics } from "@vercel/analytics/next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Quit All — Quit Smoking, Vaping, Alcohol & More in One App",
  description: "Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings with GIFs & memes, save money. 100% private, all data on your device.",
  keywords: [
    "quit smoking app", "stop vaping", "quit drinking", "sober tracker",
    "addiction tracker", "quit alcohol", "dopamine detox", "habit tracker",
    "quit weed", "stop gambling", "quit caffeine", "no fap",
    "sobriety counter", "craving help", "quit all addictions",
    "streak tracker", "money saved quitting", "relapse tracker",
  ],
  authors: [{ name: "Apoorv Darshan" }],
  creator: "Apoorv Darshan",
  publisher: "Apoorv Darshan",
  metadataBase: new URL("https://quit-all.vercel.app"),
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://quit-all.vercel.app",
    siteName: "Quit All",
    title: "Quit All — Quit Every Addiction in One App",
    description: "One app to quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings, save money.",
    images: [
      {
        url: "/logo.png",
        width: 1024,
        height: 1024,
        alt: "Quit All App Logo",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Quit All — Quit Every Addiction in One App",
    description: "Quit smoking, vaping, alcohol & 6 more addictions. Track streaks, survive cravings with GIFs, save money. 100% private.",
    creator: "@apoorvdarshan",
    images: ["/logo.png"],
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
  name: "Quit All",
  operatingSystem: "iOS",
  applicationCategory: "HealthApplication",
  description: "Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine — all in one app.",
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
