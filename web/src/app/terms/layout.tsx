import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service — Quit All",
  description:
    "Quit All Terms of Service. Subscription and lifetime purchase terms, medical disclaimer, third-party services, and usage terms for the Quit All addiction-tracking iOS app.",
  alternates: { canonical: "/terms" },
  openGraph: {
    type: "website",
    url: "https://www.quit-all.com/terms",
    siteName: "Quit All",
    title: "Terms of Service — Quit All",
    description:
      "Subscription, lifetime purchase, medical disclaimer, and usage terms for the Quit All iOS app.",
  },
};

export default function TermsLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
