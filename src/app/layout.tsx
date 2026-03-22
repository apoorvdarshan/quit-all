import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Quit All — Quit Every Addiction in One App",
  description: "One app to quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings, save money.",
  icons: { icon: "/favicon.png" },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="antialiased">
      <body className="min-h-screen">{children}</body>
    </html>
  );
}
