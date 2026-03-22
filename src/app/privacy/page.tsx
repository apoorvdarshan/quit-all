"use client";

import Link from "next/link";
import Image from "next/image";
import { motion } from "framer-motion";

const fadeUp = {
  hidden: { opacity: 0, y: 30, filter: "blur(6px)" },
  visible: (i: number) => ({
    opacity: 1, y: 0, filter: "blur(0px)",
    transition: { duration: 0.8, delay: i * 0.1, ease: [0.16, 1, 0.3, 1] }
  }),
};

const sections = [
  {
    title: "Overview",
    content: "Quit All (\u201Cwe\u201D, \u201Cour\u201D, \u201Cthe app\u201D) is committed to protecting your privacy. This Privacy Policy explains how we handle your information.",
  },
  {
    title: "Data Collection",
    intro: "Quit All does **not** collect, store, or transmit any personal data to external servers. All your data stays on your device.",
    items: [
      "Addiction tracking data \u2014 stored locally on your device using CoreData",
      "Craving logs, relapse history, milestones \u2014 stored locally, never transmitted",
      "No accounts \u2014 no sign-up, no login, no email required",
      "No analytics \u2014 we don\u2019t track your behavior",
      "No advertising \u2014 we don\u2019t serve ads or share data with advertisers",
    ],
  },
  {
    title: "Third-Party Services",
    items: [
      "Giphy API \u2014 Used to fetch GIF images for the SOS craving screen. Giphy may collect usage data per their own privacy policy. No personal data from Quit All is sent to Giphy.",
      "Apple StoreKit \u2014 Used for in-app subscriptions. Payment processing is handled entirely by Apple.",
    ],
  },
  {
    title: "Data Storage",
    content: "All app data is stored locally on your device. If you delete the app, all data is permanently deleted. We have no backups of your data.",
  },
  {
    title: "Children\u2019s Privacy",
    content: "Quit All is not intended for children under 17. We do not knowingly collect data from children.",
  },
  {
    title: "Changes to This Policy",
    content: "We may update this Privacy Policy from time to time. Changes will be reflected on this page with an updated date.",
  },
];

export default function Privacy() {
  return (
    <>
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
          <motion.p variants={fadeUp} custom={2} className="legal-date">Last updated: March 22, 2026</motion.p>
        </motion.div>

        <motion.div className="legal-divider" initial={{ scaleX: 0 }} animate={{ scaleX: 1 }}
          transition={{ duration: 1, delay: 0.4, ease: [0.16, 1, 0.3, 1] }} />

        {sections.map((section, i) => (
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
