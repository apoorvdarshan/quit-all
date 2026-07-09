import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Quit All",
  description:
    "Quit All Privacy Policy. Habit data stays on your device, no account required. Purchases are handled by Apple and RevenueCat; SOS GIFs use Klipy through a Vercel proxy. No ad tracking, no habit data sold.",
  alternates: { canonical: "/privacy" },
  openGraph: {
    type: "website",
    url: "https://www.quit-all.com/privacy",
    siteName: "Quit All",
    title: "Privacy Policy — Quit All",
    description:
      "How Quit All handles your data: local-first, no account, no ad tracking, no habit data sold.",
  },
};

export default function PrivacyLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
