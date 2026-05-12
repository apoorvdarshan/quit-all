"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { seoPages } from "./seoPages";

const ease = [0.16, 1, 0.3, 1] as const;

const fadeUp = {
  hidden: { opacity: 0, y: 24 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.68, delay: i * 0.07, ease },
  }),
};

const reveal = {
  hidden: { opacity: 0, scale: 0.96 },
  visible: (i: number) => ({
    opacity: 1,
    scale: 1,
    transition: { duration: 0.68, delay: i * 0.06, ease },
  }),
};

const habits = [
  "Smoking",
  "Vaping",
  "Alcohol",
  "Porn",
  "Social media",
  "Weed",
  "Gambling",
  "Overspending",
  "Caffeine",
];

const metrics = [
  { value: "9", label: "habit tracks" },
  { value: "2,790+", label: "craving prompts" },
  { value: "0", label: "accounts required" },
  { value: "3", label: "premium options" },
];

const chapters = [
  {
    number: "01",
    title: "Open SOS before the urge takes over.",
    tag: "Craving timer",
    copy:
      "A full-screen craving mode starts the clock, shows Powered by KLIPY GIFs or local fallback loops, and keeps your hands busy until the spike passes.",
  },
  {
    number: "02",
    title: "Track every quit attempt in one place.",
    tag: "Multi-habit",
    copy:
      "Smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine can live together without separate apps or public profiles.",
  },
  {
    number: "03",
    title: "Turn slips into usable pattern data.",
    tag: "Stats",
    copy:
      "Danger times, triggers, streaks, savings, relapse history, and milestones make the next plan sharper instead of making you start from zero mentally.",
  },
  {
    number: "04",
    title: "Keep your streak visible outside the app.",
    tag: "Widgets",
    copy:
      "Home Screen and Lock Screen widgets keep the current streak close, so the habit you are breaking stays visible before you even open Quit All.",
  },
];

const process = [
  "Pick the habit you are quitting.",
  "Use SOS when a craving hits.",
  "Swipe through GIFs, prompts, and consequences.",
  "Log slips without shame when they happen.",
  "Review patterns and adjust the next attempt.",
];

const screenshots = [
  { src: "/ss-home.jpg", label: "Plate 01", title: "Streak dashboard", alt: "Quit All home streak dashboard" },
  { src: "/ss-sos-klipy.jpg", label: "Plate 02", title: "Powered by KLIPY SOS", alt: "Quit All SOS craving screen with Powered by KLIPY GIF" },
  { src: "/ss-onboarding.jpg", label: "Plate 03", title: "Choose battles", alt: "Quit All onboarding habit picker" },
  { src: "/ss-stats-new.jpg", label: "Plate 04", title: "Pattern stats", alt: "Quit All stats dashboard" },
  { src: "/ss-sos-offline.jpg", label: "Plate 05", title: "Offline fallback", alt: "Quit All offline SOS fallback" },
];

const plans = [
  {
    name: "Monthly",
    price: "$7.99",
    suffix: "/month",
    note: "Flexible access",
  },
  {
    name: "Yearly",
    price: "$49.99",
    suffix: "/year",
    note: "$4.17/month - best value",
    featured: true,
  },
  {
    name: "Lifetime",
    price: "$99.99",
    suffix: "/once",
    note: "One-time purchase",
  },
];

function AppStoreIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

export default function Home() {
  return (
    <main className="almanac-home">
      <nav className="almanac-nav" aria-label="Primary">
        <Link href="/" className="almanac-brand">
          <Image src="/logo.png" alt="Quit All" width={34} height={34} priority />
          <span>Quit All</span>
        </Link>
        <div className="almanac-nav-links">
          <Link href="#chapters">Chapters</Link>
          <Link href="#screens">Plates</Link>
          <Link href="#guides">Guides</Link>
          <Link href="#pricing">Pricing</Link>
        </div>
        <a
          href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
          target="_blank"
          rel="noopener noreferrer"
          className="almanac-nav-cta"
        >
          Get iOS app
        </a>
      </nav>

      <section className="almanac-hero">
        <div className="almanac-container">
          <header className="almanac-meta">
            <span>
              <span className="almanac-dot" /> Issue 01 - Quit better
            </span>
            <span>iPhone - widgets - SOS</span>
            <span>Powered by KLIPY GIFs</span>
          </header>

          <div className="almanac-hero-grid">
            <motion.div initial="hidden" animate="visible" className="almanac-hero-copy">
              <motion.p variants={fadeUp} custom={0} className="almanac-eyebrow">
                Break every habit
              </motion.p>
              <motion.h1 variants={fadeUp} custom={1}>
                Quit All,
                <br />
                <em>one urge at a time.</em>
              </motion.h1>
              <motion.p variants={fadeUp} custom={2} className="almanac-lede">
                A private iPhone app for quitting smoking, vaping, alcohol, porn, social media,
                weed, gambling, overspending, caffeine, or all of them together. When a craving
                hits, open SOS, ride out the timer, and keep the streak visible.
              </motion.p>
              <motion.div variants={fadeUp} custom={3} className="almanac-actions">
                <a
                  href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="almanac-button primary"
                >
                  <AppStoreIcon />
                  Download on the App Store
                </a>
                <Link href="#screens" className="almanac-button secondary">
                  View app plates
                </Link>
              </motion.div>
              <motion.div variants={fadeUp} custom={4} className="almanac-chip-row">
                <a
                  href="https://www.producthunt.com/products/quit-all-break-every-habit"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Product Hunt
                </a>
                <a
                  href="https://trustmrr.com/startup/quit-all-break-every-habit"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  TrustMRR
                </a>
                <a
                  href="https://www.instagram.com/quitall_com/"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Instagram
                </a>
                <a
                  href="https://www.linkedin.com/company/quit-all/"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  LinkedIn
                </a>
                <a href="https://ko-fi.com/apoorvdarshan" target="_blank" rel="noopener noreferrer">
                  Ko-fi
                </a>
              </motion.div>
            </motion.div>

            <motion.aside initial="hidden" animate="visible" className="almanac-hero-visual">
              <motion.figure variants={reveal} custom={0} className="almanac-phone main">
                <Image src="/ss-home.jpg" alt="Quit All home dashboard" width={296} height={640} priority />
              </motion.figure>
              <motion.figure variants={reveal} custom={1} className="almanac-phone floating left">
                <Image src="/ss-sos-klipy.jpg" alt="Quit All SOS screen" width={188} height={407} priority />
              </motion.figure>
              <motion.figure variants={reveal} custom={2} className="almanac-phone floating right">
                <Image src="/ss-stats-new.jpg" alt="Quit All stats screen" width={188} height={407} priority />
              </motion.figure>
              <div className="almanac-visual-note top">SOS / Timer / GIF</div>
              <div className="almanac-visual-note bottom">Widgets in v1.1</div>
            </motion.aside>
          </div>
        </div>
      </section>

      <div className="almanac-ticker" aria-label="Quit All features">
        {[...habits, "Lock Screen widgets", "Home Screen widgets", "Private by default", ...habits].map(
          (item, index) => (
            <span key={`${item}-${index}`}>* {item}</span>
          ),
        )}
      </div>

      <section className="almanac-stats">
        <div className="almanac-container">
          <span className="almanac-eyebrow">Section 01 - By the numbers</span>
          <div className="almanac-stats-grid">
            {metrics.map((metric) => (
              <article key={metric.label}>
                <strong>{metric.value}</strong>
                <span>{metric.label}</span>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="chapters" className="almanac-section">
        <div className="almanac-container">
          <div className="almanac-section-head">
            <span className="almanac-eyebrow">Section 02 - Chapters</span>
            <h2>
              A quitting app with <em>structure</em>, not noise.
            </h2>
          </div>
          <div className="almanac-chapters">
            {chapters.map((chapter, index) => (
              <motion.article
                key={chapter.title}
                className="almanac-chapter"
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, margin: "-80px" }}
                variants={fadeUp}
                custom={index}
              >
                <span className="chapter-number">{chapter.number}</span>
                <div>
                  <h3>{chapter.title}</h3>
                  <small>{chapter.tag}</small>
                </div>
                <p>{chapter.copy}</p>
              </motion.article>
            ))}
          </div>
        </div>
      </section>

      <section className="almanac-process-section">
        <div className="almanac-container almanac-process-grid">
          <div>
            <span className="almanac-eyebrow">Section 03 - Process</span>
            <h2>From craving spike to clean data.</h2>
          </div>
          <ol className="almanac-process">
            {process.map((step, index) => (
              <motion.li
                key={step}
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, margin: "-80px" }}
                variants={fadeUp}
                custom={index}
              >
                <span>Step {String(index + 1).padStart(2, "0")}</span>
                <p>{step}</p>
              </motion.li>
            ))}
          </ol>
        </div>
      </section>

      <section id="screens" className="almanac-gallery">
        <div className="almanac-container">
          <div className="almanac-section-head">
            <span className="almanac-eyebrow">Section 04 - Plates</span>
            <h2>
              Real app screens, <em>laid out like plates.</em>
            </h2>
          </div>
        </div>
        <div className="almanac-plates">
          {screenshots.map((screen, index) => (
            <motion.figure
              key={screen.src}
              className="almanac-plate"
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, margin: "-80px" }}
              variants={reveal}
              custom={index}
            >
              <Image src={screen.src} alt={screen.alt} width={226} height={490} />
              <figcaption>
                <span>{screen.label}</span>
                <strong>{screen.title}</strong>
              </figcaption>
            </motion.figure>
          ))}
        </div>
      </section>

      <section id="guides" className="almanac-guides">
        <div className="almanac-container almanac-guides-grid">
          <div>
            <span className="almanac-eyebrow">Section 05 - Guides</span>
            <h2>Every habit gets its own entry point.</h2>
            <p>
              Specific quit guides help search visitors land on the habit they care about, while
              the homepage stays focused on the product.
            </p>
          </div>
          <div className="almanac-guide-list">
            {seoPages.map((guide) => (
              <Link key={guide.slug} href={`/${guide.slug}`}>
                <span>{guide.eyebrow}</span>
                <strong>{guide.label}</strong>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section id="pricing" className="almanac-pricing">
        <div className="almanac-container">
          <div className="almanac-section-head center">
            <span className="almanac-eyebrow">Section 06 - Pricing</span>
            <h2>
              Simple premium options. <em>No account required.</em>
            </h2>
          </div>
          <div className="almanac-plan-grid">
            {plans.map((plan) => (
              <article key={plan.name} className={plan.featured ? "almanac-plan featured" : "almanac-plan"}>
                {plan.featured && <span className="almanac-plan-badge">Best value</span>}
                <h3>{plan.name}</h3>
                <p className="almanac-price">
                  {plan.price}
                  <span>{plan.suffix}</span>
                </p>
                <p>{plan.note}</p>
                <ul>
                  <li>All 9 habit tracks</li>
                  <li>SOS GIFs and offline loops</li>
                  <li>Stats, milestones, widgets, and savings</li>
                </ul>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="almanac-final">
        <div className="almanac-container">
          <span className="almanac-eyebrow">Coda</span>
          <h2>The next urge does not need to win.</h2>
          <a
            href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
            target="_blank"
            rel="noopener noreferrer"
            className="almanac-button primary"
          >
            <AppStoreIcon />
            Download Quit All
          </a>
        </div>
      </section>

      <section className="seo-content">
        <div className="almanac-container">
          <h2>Quit Smoking, Vaping, Alcohol and More</h2>
          <p>
            Quit All, sometimes searched as AllQuit, helps you quit smoking, stop vaping, quit
            drinking alcohol, break gambling patterns, quit weed, reduce caffeine, stop
            overspending, and cut down on social media. Track every streak in one place, use the
            SOS craving button for Powered by KLIPY GIFs plus offline fallback loops, log relapses
            without shame, and see savings and milestones build over time.
          </p>
        </div>
      </section>

      <footer className="almanac-footer">
        <div className="almanac-container almanac-footer-grid">
          <Link href="/" className="almanac-brand">
            <Image src="/logo.png" alt="Quit All" width={30} height={30} />
            <span>Quit All</span>
          </Link>
          <div className="almanac-footer-links">
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
            <Link href="https://trustmrr.com/startup/quit-all-break-every-habit" target="_blank">
              TrustMRR
            </Link>
            <Link href="https://www.producthunt.com/products/quit-all-break-every-habit" target="_blank">
              Product Hunt
            </Link>
            <Link href="https://www.instagram.com/quitall_com/" target="_blank">
              Instagram
            </Link>
            <Link href="https://www.linkedin.com/company/quit-all/" target="_blank">
              LinkedIn
            </Link>
            <Link href="https://ko-fi.com/apoorvdarshan" target="_blank">
              Ko-fi
            </Link>
            <Link href="mailto:ad13dtu@gmail.com">Contact</Link>
          </div>
          <p>2026 Apoorv Darshan. All rights reserved.</p>
        </div>
      </footer>
    </main>
  );
}
