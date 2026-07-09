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
    content: "Quit All is a habit-tracking and addiction recovery app. It provides tools for tracking sobriety streaks, logging cravings and relapses, viewing motivational GIFs, memes, and offline fallback loops, monitoring savings, and using widgets. The app is not a substitute for professional medical advice, diagnosis, or treatment.",
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
    content: "Quit All is not a medical app. It does not provide medical advice, diagnosis, or treatment. If you are dealing with substance abuse or addiction, please consult a healthcare professional. The app is a supplementary tool and should not replace professional help.",
    highlight: "not",
  },
  {
    title: "Content",
    content: "GIFs, memes, local video loops, and motivational text in the app are for entertainment, distraction, and motivation purposes only. Some content may contain humor about addiction. Online GIF availability depends on third-party services and network connectivity.",
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
    content: "Quit All uses Apple StoreKit/App Store for purchases and refunds, RevenueCat for entitlement management and refund-request handling, Klipy for online GIF content, and Vercel for the website and API proxy. These services may be subject to their own terms and availability.",
  },
  {
    title: "Limitation of Liability",
    content: "Quit All is provided \u201Cas is\u201D without warranties of any kind. We are not liable for any damages arising from the use or inability to use the app, including but not limited to relapse, health complications, purchase issues handled by Apple, third-party service outages, or data loss.",
  },
  {
    title: "Changes to These Terms",
    content: "We reserve the right to modify these Terms at any time. Continued use of the app after changes constitutes acceptance of updated Terms.",
  },
];

export default function Terms() {
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
            <Link href="/privacy">Privacy</Link>
          </div>
        </div>
      </motion.nav>

      <main className="container-sm" style={{ paddingTop: 140, paddingBottom: 96 }}>
        <motion.div className="legal-header" initial="hidden" animate="visible">
          <motion.p variants={fadeUp} custom={0} className="legal-label">Legal</motion.p>
          <motion.h1 variants={fadeUp} custom={1} className="legal-title">Terms of Service</motion.h1>
          <motion.p variants={fadeUp} custom={2} className="legal-date">Last updated: May 22, 2026</motion.p>
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
