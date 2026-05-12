"use client";

import Link from "next/link";
import Image from "next/image";
import { motion } from "framer-motion";

const ease = [0.16, 1, 0.3, 1] as const;

const fadeUp = {
  hidden: { opacity: 0, y: 30, filter: "blur(6px)" },
  visible: (i: number) => ({
    opacity: 1, y: 0, filter: "blur(0px)",
    transition: { duration: 0.8, delay: i * 0.1, ease }
  }),
};

const sections = [
  {
    title: "Overview",
    content: "Quit All (\u201Cwe\u201D, \u201Cour\u201D, \u201Cthe app\u201D) is committed to protecting your privacy. This Privacy Policy explains how the app and website handle information.",
  },
  {
    title: "Data Collection",
    intro: "Quit All does **not** require an account and does not send your habit history, craving logs, relapse notes, milestones, or addiction settings to our servers.",
    items: [
      "Addiction tracking data \u2014 stored locally on your device using CoreData",
      "Craving logs, relapse history, milestones \u2014 stored locally, never transmitted",
      "Widget snapshots \u2014 stored locally in the app group so Home Screen and Lock Screen widgets can display progress",
      "No accounts \u2014 no sign-up, no login, no email required",
      "No advertising \u2014 we do not sell your data or share habit data with advertisers",
    ],
  },
  {
    title: "Third-Party Services",
    items: [
      "Apple StoreKit and App Store \u2014 Used for subscriptions, lifetime purchases, trials, refunds, and purchase management. Payment processing is handled by Apple.",
      "RevenueCat \u2014 Used to manage purchase entitlements. RevenueCat may receive an anonymous app user ID, product identifiers, transaction receipts, and app/device metadata needed to validate access. Quit All does not send your habit logs or relapse history to RevenueCat.",
      "Klipy GIF API \u2014 Used to show online GIFs in SOS mode. Requests are routed through our Vercel API proxy so the Klipy API key is not shipped in the app. Search/category requests and standard request metadata may be processed to return GIF results.",
      "Vercel \u2014 Hosts quit-all.com and API proxy routes used for app configuration and Klipy requests. Server logs may include request URL, IP address, user agent, and timestamps for security and debugging.",
      "Vercel Analytics \u2014 Used on the marketing website to understand page usage. This does not include in-app habit tracking data.",
      "Apple Local Notifications \u2014 Used for smart reminders at your configured risk times. Notification schedules are generated on device.",
    ],
  },
  {
    title: "Data Storage",
    content: "Your app data is stored locally on your device. If you delete the app, local app data may be permanently deleted. We do not keep backups of your habit history.",
  },
  {
    title: "Purchases",
    content: "Purchases are processed by Apple and entitlement status is managed with RevenueCat. You can manage subscriptions, cancellations, and refunds through your Apple ID or App Store settings.",
  },
  {
    title: "Children\u2019s Privacy",
    content: "Quit All is rated 18+ and is not intended for children. We do not knowingly collect data from children.",
  },
  {
    title: "Changes to This Policy",
    content: "We may update this Privacy Policy from time to time. Changes will be reflected on this page with an updated date.",
  },
];

export default function Privacy() {
  return (
    <>
      <title>Privacy Policy — Quit All</title>
      <meta name="description" content="Quit All Privacy Policy. Habit data stays on your device. No account required. Purchases use Apple and RevenueCat; SOS GIFs use Klipy through a Vercel proxy." />
      <motion.nav className="nav"
        initial={{ y: -80, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}>
        <div className="nav-inner" style={{ maxWidth: 800 }}>
          <Link href="/" className="nav-logo">
            <Image src="/logo.png" alt="Quit All" width={28} height={28} />
            <span>QUIT ALL</span>
          </Link>
          <div className="nav-links">
            <Link href="/">Home</Link>
            <Link href="/terms">Terms</Link>
          </div>
        </div>
      </motion.nav>

      <main className="container-sm" style={{ paddingTop: 140, paddingBottom: 96 }}>
        <motion.div className="legal-header" initial="hidden" animate="visible">
          <motion.p variants={fadeUp} custom={0} className="legal-label">Legal</motion.p>
          <motion.h1 variants={fadeUp} custom={1} className="legal-title">Privacy Policy</motion.h1>
          <motion.p variants={fadeUp} custom={2} className="legal-date">Last updated: May 12, 2026</motion.p>
        </motion.div>

        <motion.div className="legal-divider" initial={{ scaleX: 0 }} animate={{ scaleX: 1 }}
          transition={{ duration: 1, delay: 0.4, ease: [0.16, 1, 0.3, 1] }} />

        {sections.map((section) => (
          <motion.div key={section.title} className="legal-section"
            initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-60px" }}
            variants={fadeUp} custom={0}>
            <h2>{section.title}</h2>
            {section.intro && (
              <p style={{ marginBottom: 16 }}>
                {section.intro.split("**not**").map((part, j) =>
                  j === 0 ? part : <span key={j}><strong style={{ color: "var(--gold-bright)" }}>not</strong>{part}</span>
                )}
              </p>
            )}
            {section.content && <p>{section.content}</p>}
            {section.items && (
              <ul>
                {section.items.map((item, j) => {
                  const dashIdx = item.indexOf(" \u2014 ");
                  return (
                    <li key={j}>
                      {dashIdx > -1 ? (
                        <>
                          <strong style={{ color: "var(--text)", fontWeight: 500 }}>
                            {item.substring(0, dashIdx)}
                          </strong>
                          {item.substring(dashIdx)}
                        </>
                      ) : item}
                    </li>
                  );
                })}
              </ul>
            )}
          </motion.div>
        ))}

        <motion.div className="legal-section"
          initial="hidden" whileInView="visible" viewport={{ once: true }}
          variants={fadeUp} custom={0}>
          <h2>Contact</h2>
          <p>Questions about this Privacy Policy? Reach out at{" "}
            <a href="mailto:ad13dtu@gmail.com">ad13dtu@gmail.com</a>
          </p>
        </motion.div>

        <motion.div className="legal-back"
          initial={{ opacity: 0 }} whileInView={{ opacity: 1 }}
          viewport={{ once: true }} transition={{ delay: 0.2 }}>
          <Link href="/">
            <span className="legal-back-arrow">&larr;</span> Back to home
          </Link>
        </motion.div>
      </main>
    </>
  );
}
