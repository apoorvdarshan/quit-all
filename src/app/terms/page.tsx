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
    title: "Acceptance of Terms",
    content: "By downloading or using Quit All, you agree to these Terms of Service. If you do not agree, do not use the app.",
  },
  {
    title: "Description of Service",
    content: "Quit All is a habit-tracking and addiction recovery app. It provides tools for tracking sobriety streaks, logging cravings, viewing motivational content, and monitoring savings. The app is not a substitute for professional medical advice, diagnosis, or treatment.",
  },
  {
    title: "Subscriptions",
    items: [
      "Quit All offers a 3-day free trial followed by auto-renewable subscriptions: Monthly ($7.99/month) and Yearly ($49.99/year)",
      "Payment is charged to your Apple ID account at the end of the free trial period",
      "Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period",
      "You can manage and cancel subscriptions in your Apple ID account settings",
      "If you cancel during the free trial, you will not be charged",
    ],
  },
  {
    title: "Medical Disclaimer",
    content: "Quit All is not a medical app. It does not provide medical advice, diagnosis, or treatment. If you are dealing with substance abuse or addiction, please consult a healthcare professional. The app is a supplementary tool and should not replace professional help.",
    highlight: "not",
  },
  {
    title: "Content",
    content: "Memes, GIFs, and motivational text in the app are for entertainment and motivation purposes only. Some content may contain humor about addiction. All GIF content is SFW (safe for work) and sourced from Giphy\u2019s PG-rated library.",
  },
  {
    title: "User Responsibility",
    items: [
      "You are responsible for maintaining the confidentiality of your data",
      "You agree not to misuse the app or attempt to reverse-engineer it",
      "You acknowledge that the app stores data locally and data loss may occur if the app is deleted",
    ],
  },
  {
    title: "Limitation of Liability",
    content: "Quit All is provided \u201Cas is\u201D without warranties of any kind. We are not liable for any damages arising from the use or inability to use the app, including but not limited to relapse, health complications, or data loss.",
  },
  {
    title: "Changes to These Terms",
    content: "We reserve the right to modify these Terms at any time. Continued use of the app after changes constitutes acceptance of updated Terms.",
  },
];

export default function Terms() {
  return (
    <>
      <title>Terms of Service — Quit All</title>
      <meta name="description" content="Quit All Terms of Service. Subscription details, medical disclaimer, and usage terms for the addiction tracking iOS app." />
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
            <Link href="/privacy">Privacy</Link>
          </div>
        </div>
      </motion.nav>

      <main className="container-sm" style={{ paddingTop: 140, paddingBottom: 96 }}>
        <motion.div className="legal-header" initial="hidden" animate="visible">
          <motion.p variants={fadeUp} custom={0} className="legal-label">Legal</motion.p>
          <motion.h1 variants={fadeUp} custom={1} className="legal-title">Terms of Service</motion.h1>
          <motion.p variants={fadeUp} custom={2} className="legal-date">Last updated: March 23, 2026</motion.p>
        </motion.div>

        <motion.div className="legal-divider" initial={{ scaleX: 0 }} animate={{ scaleX: 1 }}
          transition={{ duration: 1, delay: 0.4, ease: [0.16, 1, 0.3, 1] }} />

        {sections.map((section) => (
          <motion.div key={section.title} className="legal-section"
            initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-60px" }}
            variants={fadeUp} custom={0}>
            <h2>{section.title}</h2>
            {section.content && (
              <p>
                {section.highlight ? (
                  section.content.split(section.highlight).map((part, j) =>
                    j === 0 ? part : <span key={j}><strong style={{ color: "var(--gold-bright)" }}>{section.highlight}</strong>{part}</span>
                  )
                ) : section.content}
              </p>
            )}
            {section.items && (
              <ul>
                {section.items.map((item, j) => <li key={j}>{item}</li>)}
              </ul>
            )}
          </motion.div>
        ))}

        <motion.div className="legal-section"
          initial="hidden" whileInView="visible" viewport={{ once: true }}
          variants={fadeUp} custom={0}>
          <h2>Contact</h2>
          <p>For questions about these Terms, contact us at{" "}
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
