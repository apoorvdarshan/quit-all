"use client";

import Image from "next/image";
import Link from "next/link";
import type { CSSProperties } from "react";
import { motion } from "framer-motion";
import { seoPages } from "./seoPages";

const ease = [0.16, 1, 0.3, 1] as const;

const fadeUp = {
  hidden: { opacity: 0, y: 28 },
  visible: (i: number) => ({
    opacity: 1,
    y: 0,
    transition: { duration: 0.72, delay: i * 0.08, ease },
  }),
};

const reveal = {
  hidden: { opacity: 0, scale: 0.96 },
  visible: (i: number) => ({
    opacity: 1,
    scale: 1,
    transition: { duration: 0.7, delay: i * 0.06, ease },
  }),
};

const addictions = [
  { name: "Smoking", color: "#5ec4ff" },
  { name: "Vaping", color: "#89d6ff" },
  { name: "Alcohol", color: "#ffb86b" },
  { name: "Porn", color: "#c894ff" },
  { name: "Social Media", color: "#83f0c5" },
  { name: "Weed", color: "#8ee16f" },
  { name: "Gambling", color: "#ff6f8f" },
  { name: "Overspending", color: "#ffd45f" },
  { name: "Caffeine", color: "#d7a874" },
];

const stats = [
  { value: "9", label: "habit tracks" },
  { value: "2,790+", label: "text prompts" },
  { value: "0", label: "accounts required" },
  { value: "3", label: "purchase options" },
];

const moments = [
  {
    step: "01",
    title: "Choose the habit",
    copy: "Track one problem or stack several together without scattering progress across apps.",
  },
  {
    step: "02",
    title: "Hit SOS when it spikes",
    copy: "Swipe through Powered by KLIPY GIFs, local fallback loops, and quick prompts while the urge passes.",
  },
  {
    step: "03",
    title: "Find the pattern",
    copy: "Stats, triggers, danger times, savings, and relapse context make the next attempt smarter.",
  },
  {
    step: "04",
    title: "Keep it visible",
    copy: "Home Screen and Lock Screen widgets keep the streak close when the app is closed.",
  },
];

const featurePanels = [
  {
    kicker: "SOS",
    title: "A craving screen that moves faster than the craving.",
    copy: "The SOS flow fills the screen, starts a timer, and gives your hands something better to do than relapse.",
    image: "/ss-sos-klipy.jpg",
    alt: "Quit All SOS craving screen with Powered by KLIPY GIF",
  },
  {
    kicker: "Streaks",
    title: "A quiet dashboard for every habit you are leaving behind.",
    copy: "See clean time, progress, and quick actions in one place. No feed, no account, no public profile.",
    image: "/ss-home.jpg",
    alt: "Quit All home streak dashboard",
  },
  {
    kicker: "Stats",
    title: "Danger times, triggers, and money saved become visible.",
    copy: "Quit All turns messy relapse history into usable patterns so your next plan is based on evidence.",
    image: "/ss-stats-new.jpg",
    alt: "Quit All stats dashboard",
  },
];

const screenshots = [
  { src: "/ss-onboarding.jpg", alt: "Choose habits to quit in Quit All" },
  { src: "/ss-home.jpg", alt: "Quit All home dashboard" },
  { src: "/ss-sos-klipy.jpg", alt: "Quit All SOS with Powered by KLIPY GIF" },
  { src: "/ss-sos-offline.jpg", alt: "Quit All offline SOS fallback" },
  { src: "/ss-stats-new.jpg", alt: "Quit All stats view" },
];

const plans = [
  {
    name: "Monthly",
    price: "$7.99",
    suffix: "/month",
    note: "Billed monthly",
    cta: "Start Free Trial",
    featured: false,
  },
  {
    name: "Yearly",
    price: "$49.99",
    suffix: "/year",
    note: "$4.17/month, best value",
    cta: "Start Free Trial",
    featured: true,
  },
  {
    name: "Lifetime",
    price: "$99.99",
    suffix: "/once",
    note: "One-time purchase",
    cta: "Buy Lifetime",
    featured: false,
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
    <main className="home-refresh">
      <nav className="fresh-nav">
        <Link href="/" className="fresh-logo">
          <Image src="/logo.png" alt="Quit All" width={34} height={34} priority />
          <span>Quit All</span>
        </Link>
        <div className="fresh-nav-links">
          <Link href="#inside">Inside</Link>
          <Link href="#screens">Screens</Link>
          <Link href="#guides">Guides</Link>
          <Link href="#pricing">Pricing</Link>
        </div>
        <a
          href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
          target="_blank"
          className="fresh-nav-cta"
        >
          Get the app
        </a>
      </nav>

      <section className="fresh-hero">
        <div className="fresh-container fresh-hero-grid">
          <motion.div initial="hidden" animate="visible" className="fresh-hero-copy">
            <motion.p variants={fadeUp} custom={0} className="fresh-eyebrow">
              Break every habit, one urgent minute at a time
            </motion.p>
            <motion.h1 variants={fadeUp} custom={1}>Quit All</motion.h1>
            <motion.p variants={fadeUp} custom={2} className="fresh-hero-subtitle">
              The private iPhone app for quitting smoking, vaping, alcohol, porn, social media,
              weed, gambling, overspending, caffeine, or all of them together.
            </motion.p>
            <motion.div variants={fadeUp} custom={3} className="fresh-actions">
              <a
                href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
                target="_blank"
                className="fresh-button primary"
              >
                <AppStoreIcon />
                Download for iOS
              </a>
              <Link href="#inside" className="fresh-button secondary">
                See how it works
              </Link>
            </motion.div>
            <motion.div variants={fadeUp} custom={4} className="fresh-metrics">
              {stats.map((item) => (
                <div key={item.label}>
                  <strong>{item.value}</strong>
                  <span>{item.label}</span>
                </div>
              ))}
            </motion.div>
          </motion.div>

          <motion.div initial="hidden" animate="visible" className="phone-stage" aria-label="Quit All app previews">
            <motion.figure variants={reveal} custom={1} className="phone-shot phone-shot-left">
              <Image src="/ss-sos-klipy.jpg" alt="SOS craving GIF screen" width={220} height={476} priority />
            </motion.figure>
            <motion.figure variants={reveal} custom={0} className="phone-shot phone-shot-main">
              <Image src="/ss-home.jpg" alt="Quit All home dashboard" width={280} height={606} priority />
            </motion.figure>
            <motion.figure variants={reveal} custom={2} className="phone-shot phone-shot-right">
              <Image src="/ss-stats-new.jpg" alt="Quit All stats screen" width={220} height={476} priority />
            </motion.figure>
          </motion.div>
        </div>

        <div className="habit-ribbon" aria-label="Supported habits">
          {addictions.map((habit) => (
            <span key={habit.name} style={{ "--accent": habit.color } as CSSProperties}>
              {habit.name}
            </span>
          ))}
        </div>
      </section>

      <section id="inside" className="fresh-section">
        <div className="fresh-container">
          <div className="fresh-section-head">
            <p className="fresh-eyebrow">The quitting loop</p>
            <h2>Built for the moment your plan gets tested.</h2>
          </div>
          <div className="moment-grid">
            {moments.map((moment, index) => (
              <motion.article
                key={moment.title}
                className="moment-card"
                initial="hidden"
                whileInView="visible"
                viewport={{ once: true, margin: "-80px" }}
                variants={fadeUp}
                custom={index}
              >
                <span>{moment.step}</span>
                <h3>{moment.title}</h3>
                <p>{moment.copy}</p>
              </motion.article>
            ))}
          </div>
        </div>
      </section>

      <section className="feature-showcase">
        <div className="fresh-container">
          {featurePanels.map((feature, index) => (
            <motion.article
              key={feature.title}
              className="feature-row"
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, margin: "-100px" }}
              variants={fadeUp}
              custom={index}
            >
              <div className="feature-copy">
                <p className="fresh-eyebrow">{feature.kicker}</p>
                <h2>{feature.title}</h2>
                <p>{feature.copy}</p>
              </div>
              <div className="feature-media">
                <Image src={feature.image} alt={feature.alt} width={260} height={563} />
              </div>
            </motion.article>
          ))}
        </div>
      </section>

      <section id="screens" className="screen-wall">
        <div className="fresh-container">
          <div className="fresh-section-head compact">
            <p className="fresh-eyebrow">Screens</p>
            <h2>Real app screens, not a mock dashboard.</h2>
          </div>
        </div>
        <div className="screen-rail">
          {screenshots.map((screen, index) => (
            <motion.figure
              key={screen.src}
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true, margin: "-80px" }}
              variants={reveal}
              custom={index}
            >
              <Image src={screen.src} alt={screen.alt} width={220} height={476} />
            </motion.figure>
          ))}
        </div>
      </section>

      <section id="guides" className="guide-section">
        <div className="fresh-container guide-grid">
          <div className="guide-copy">
            <p className="fresh-eyebrow">Quit guides</p>
            <h2>Every habit has its own route in.</h2>
            <p>
              These pages are built for people searching for a specific tracker, while keeping
              the homepage focused on the app experience.
            </p>
          </div>
          <div className="guide-links">
            {seoPages.map((guide) => (
              <Link key={guide.slug} href={`/${guide.slug}`}>
                <span>{guide.eyebrow}</span>
                <strong>{guide.label}</strong>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section id="pricing" className="pricing-refresh">
        <div className="fresh-container">
          <div className="fresh-section-head compact center">
            <p className="fresh-eyebrow">Pricing</p>
            <h2>Simple options. No account required.</h2>
          </div>
          <div className="plan-grid">
            {plans.map((plan) => (
              <article key={plan.name} className={plan.featured ? "plan-card featured" : "plan-card"}>
                {plan.featured && <div className="plan-badge">Save 48%</div>}
                <h3>{plan.name}</h3>
                <p className="plan-price">
                  {plan.price}
                  <span>{plan.suffix}</span>
                </p>
                <p className="plan-note">{plan.note}</p>
                <ul>
                  <li>All 9 addiction types</li>
                  <li>SOS GIFs, memes, and offline loops</li>
                  <li>Stats, milestones, widgets, and savings</li>
                </ul>
                <a
                  href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
                  target="_blank"
                  className="fresh-button primary"
                >
                  {plan.cta}
                </a>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="fresh-cta">
        <div className="fresh-container fresh-cta-inner">
          <div>
            <p className="fresh-eyebrow">Your move</p>
            <h2>The next urge does not need to win.</h2>
          </div>
          <a
            href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
            target="_blank"
            className="fresh-button primary"
          >
            <AppStoreIcon />
            Download Quit All
          </a>
        </div>
      </section>

      <section className="seo-content">
        <div className="fresh-container">
          <h2>Quit Smoking, Vaping, Alcohol and More</h2>
          <p>
            Quit All, sometimes searched as AllQuit, helps you quit smoking, stop vaping,
            quit drinking alcohol, break gambling patterns, quit weed, reduce caffeine,
            stop overspending, and cut down on social media. Track every streak in one
            place, use the SOS craving button for Powered by KLIPY GIFs plus offline fallback
            loops, log relapses without shame, and see savings and milestones build over time.
          </p>
        </div>
      </section>

      <footer className="fresh-footer">
        <div className="fresh-container fresh-footer-inner">
          <Link href="/" className="fresh-logo">
            <Image src="/logo.png" alt="Quit All" width={30} height={30} />
            <span>Quit All</span>
          </Link>
          <div className="fresh-footer-links">
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
            <Link href="https://trustmrr.com/startup/quit-all-break-every-habit" target="_blank">TrustMRR</Link>
            <Link href="https://www.producthunt.com/products/quit-all-break-every-habit" target="_blank">Product Hunt</Link>
            <Link href="https://www.instagram.com/quitall_com/" target="_blank">Instagram</Link>
            <Link href="https://www.linkedin.com/company/quit-all/" target="_blank">LinkedIn</Link>
            <Link href="https://ko-fi.com/apoorvdarshan" target="_blank">Ko-fi</Link>
            <Link href="mailto:ad13dtu@gmail.com">Contact</Link>
          </div>
          <p>© 2026 Apoorv Darshan. All rights reserved.</p>
        </div>
      </footer>
    </main>
  );
}
