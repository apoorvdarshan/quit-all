"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";

const fadeUp = {
  hidden: { opacity: 0, y: 40 },
  visible: (i: number) => ({
    opacity: 1, y: 0,
    transition: { duration: 0.8, delay: i * 0.1, ease: [0.25, 0.46, 0.45, 0.94] }
  }),
};

const features = [
  { icon: "⚡", title: "SOS Craving Button", desc: "Instant GIF distraction when the urge hits. Swipe through memes while the craving passes. 5-minute timer keeps you grounded." },
  { icon: "🔍", title: "Pattern Intelligence", desc: "Your cravings have patterns. We find them. Hourly heatmaps, trigger analysis, and danger zone alerts." },
  { icon: "◆", title: "Milestone Rewards", desc: "From 1 hour to 1 year — 9 science-backed milestones. Each unlocks a health fact and a shareable card." },
  { icon: "¤", title: "Money Tracker", desc: "See exactly how much you've saved. Project 5 years out. See what you could buy — from coffee to a car." },
  { icon: "∞", title: "2,790+ Memes", desc: "Five categories. Nine types. Fresh GIFs every session. Motivational, roasts, consequences, distractions, relatable." },
  { icon: "↺", title: "Zero-Shame Relapse", desc: "It happened. That's okay. Log it, learn from it, restart. Your history is saved. Progress is never lost." },
];

const addictions = [
  { name: "Smoking", color: "#607D8B" }, { name: "Vaping", color: "#607D8B" },
  { name: "Alcohol", color: "#FF8F00" }, { name: "Porn", color: "#7B1FA2" },
  { name: "Social Media", color: "#1565C0" }, { name: "Weed", color: "#2E7D32" },
  { name: "Gambling", color: "#C62828" }, { name: "Overspending", color: "#F9A825" },
  { name: "Caffeine", color: "#4E342E" },
];

export default function Home() {
  return (
    <>
      <nav className="nav">
        <div className="nav-inner">
          <Link href="/" className="nav-logo">
            <Image src="/logo.png" alt="Quit All" width={32} height={32} />
            <span>QUIT ALL</span>
          </Link>
          <div className="nav-links">
            <Link href="#features">Features</Link>
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
            <Link href="/support">Support</Link>
          </div>
        </div>
      </nav>

      <section className="hero">
        <div className="hero-glow" />
        <div className="hero-line" />
        <div className="hero-content">
          <motion.div initial="hidden" animate="visible" variants={fadeUp} custom={0} className="hero-badge">
            Break every chain
          </motion.div>

          <motion.h1 initial="hidden" animate="visible" variants={fadeUp} custom={1}>
            Quit <span className="gold-shimmer" style={{ fontWeight: 600, fontStyle: "italic" }}>everything.</span>
            <br /><span className="sub">All at once.</span>
          </motion.h1>

          <motion.p initial="hidden" animate="visible" variants={fadeUp} custom={2}>
            Nine addictions. One app. Track your streaks, survive cravings with memes and GIFs, watch your money grow, and never feel ashamed of a setback.
          </motion.p>

          <motion.div initial="hidden" animate="visible" variants={fadeUp} custom={3} className="hero-buttons">
            <a href="#" className="btn-gold">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
              Download for iOS
            </a>
            <a href="#" className="btn-outline">
              <svg width="18" height="18" viewBox="0 0 40 40" fill="none"><circle cx="20" cy="20" r="20" fill="currentColor" fillOpacity="0.15"/><path d="M22.667 20H18v-6.667h4.667a3.333 3.333 0 0 1 0 6.667z" fill="currentColor"/><path d="M14.667 10h8a6.667 6.667 0 0 1 0 13.333h-4.334V30h-3.666V10z" fill="currentColor"/></svg>
              Find us on Product Hunt
            </a>
          </motion.div>

          <motion.div initial="hidden" animate="visible" variants={fadeUp} custom={4} className="addiction-pills">
            {addictions.map((a) => (
              <span key={a.name} className="addiction-pill"
                style={{ background: `${a.color}10`, border: `1px solid ${a.color}25`, color: a.color }}>
                {a.name}
              </span>
            ))}
          </motion.div>
        </div>
      </section>

      <div className="gold-line" />

      <section id="features" className="features">
        <div className="container">
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-100px" }}>
            <motion.p variants={fadeUp} custom={0} className="features-label">What&apos;s inside</motion.p>
            <motion.h2 variants={fadeUp} custom={1} className="features-title">
              Tools that actually <em>work.</em>
            </motion.h2>
            <motion.p variants={fadeUp} custom={2} className="features-subtitle">
              No generic advice. No toxic positivity. Real tools built for people who are actually trying to quit.
            </motion.p>
          </motion.div>

          <div className="features-grid">
            {features.map((f, i) => (
              <motion.div key={f.title} className="feature-card"
                initial="hidden" whileInView="visible" viewport={{ once: true }}
                variants={fadeUp} custom={i * 0.5}>
                <div className="feature-icon">{f.icon}</div>
                <h3>{f.title}</h3>
                <p>{f.desc}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Screenshots */}
      <section className="screenshots">
        <div className="container" style={{ marginBottom: 48 }}>
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }}>
            <motion.p variants={fadeUp} custom={0} className="features-label">See it in action</motion.p>
            <motion.h2 variants={fadeUp} custom={1} className="features-title">
              Built for <em>real moments.</em>
            </motion.h2>
          </motion.div>
        </div>
        <motion.div className="screenshots-scroll"
          initial="hidden" whileInView="visible" viewport={{ once: true }}>
          {["ss-onboarding", "ss-sos2", "ss-sos1", "ss-stats", "ss-sos3", "ss-sos4"].map((ss, i) => (
            <motion.div key={ss} className="screenshot-item" variants={fadeUp} custom={i * 0.5}>
              <Image src={`/${ss}.png`} alt="App screenshot" width={220} height={476} style={{ width: "100%", height: "auto" }} />
            </motion.div>
          ))}
        </motion.div>
      </section>

      {/* Pricing */}
      <section className="pricing">
        <div className="container" style={{ textAlign: "center" }}>
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }}>
            <motion.p variants={fadeUp} custom={0} className="features-label">Pricing</motion.p>
            <motion.h2 variants={fadeUp} custom={1} className="features-title" style={{ marginLeft: "auto", marginRight: "auto" }}>
              Invest in <em>yourself.</em>
            </motion.h2>
            <motion.p variants={fadeUp} custom={2} className="features-subtitle" style={{ marginLeft: "auto", marginRight: "auto" }}>
              Less than a pack of cigarettes. Less than a night out drinking. Worth more than both.
            </motion.p>
          </motion.div>

          <motion.div className="pricing-grid"
            initial="hidden" whileInView="visible" viewport={{ once: true }}>
            <motion.div variants={fadeUp} custom={0} className="pricing-card">
              <p className="pricing-name">Monthly</p>
              <p className="pricing-price">$7.99<span>/mo</span></p>
              <p className="pricing-sub">Billed monthly</p>
              <ul className="pricing-features">
                <li>All 9 addiction types</li>
                <li>SOS craving GIFs &amp; memes</li>
                <li>Stats &amp; pattern detection</li>
                <li>Milestones &amp; sharing</li>
                <li>Smart notifications</li>
              </ul>
              <button className="pricing-btn pricing-btn-secondary">Get Started</button>
            </motion.div>

            <motion.div variants={fadeUp} custom={1} className="pricing-card featured">
              <div className="pricing-badge">Save 48%</div>
              <p className="pricing-name">Yearly</p>
              <p className="pricing-price">$49.99<span>/yr</span></p>
              <p className="pricing-sub">$4.17/month — best value</p>
              <ul className="pricing-features">
                <li>Everything in Monthly</li>
                <li>Save $45.89 per year</li>
                <li>Priority future features</li>
                <li>Support development</li>
                <li>Cancel anytime</li>
              </ul>
              <button className="pricing-btn pricing-btn-primary">Get Started</button>
            </motion.div>
          </motion.div>
        </div>
      </section>

      <div className="gold-line" />

      <section className="stats">
        <div className="container">
          <div className="stats-grid">
            {[
              { v: "9", l: "Addictions" }, { v: "2,790", l: "Memes" },
              { v: "9", l: "Milestones" }, { v: "0", l: "Data Collected" },
            ].map((s, i) => (
              <motion.div key={s.l} initial="hidden" whileInView="visible" viewport={{ once: true }} variants={fadeUp} custom={i}>
                <div className="stat-value">{s.v}</div>
                <div className="stat-label">{s.l}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      <section className="cta">
        <div className="cta-glow" />
        <motion.div style={{ position: "relative", zIndex: 10 }} initial="hidden" whileInView="visible" viewport={{ once: true }}>
          <motion.p variants={fadeUp} custom={0} className="cta-label">Your move</motion.p>
          <motion.h2 variants={fadeUp} custom={1}>The best time to quit<br /><em>was yesterday.</em></motion.h2>
          <motion.p variants={fadeUp} custom={2} style={{ fontSize: 16, color: "var(--text-muted)", marginBottom: 48 }}>The second best time is right now.</motion.p>
          <motion.a variants={fadeUp} custom={3} href="#" className="btn-gold">Download Quit All</motion.a>
        </motion.div>
      </section>

      <footer className="footer">
        <div className="container">
          <div className="footer-inner">
            <div className="footer-logo">
              <Image src="/logo.png" alt="Quit All" width={24} height={24} />
              <span>Quit All</span>
            </div>
            <div className="footer-links">
              <Link href="/privacy">Privacy</Link>
              <Link href="/terms">Terms</Link>
              <Link href="mailto:ad13dtu@gmail.com">Contact</Link>
            </div>
            <div className="footer-links footer-socials">
              <Link href="https://x.com/apoorvdarshan" target="_blank" aria-label="X">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
              </Link>
              <Link href="https://linkedin.com/in/apoorvdarshan" target="_blank" aria-label="LinkedIn">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 0 1-2.063-2.065 2.064 2.064 0 1 1 2.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
              </Link>
              <Link href="https://github.com/apoorvdarshan" target="_blank" aria-label="GitHub">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
              </Link>
              <Link href="#" target="_blank" aria-label="Product Hunt">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M13.604 8.4h-3.405V12h3.405a1.8 1.8 0 0 0 0-3.6zM12 0C5.372 0 0 5.372 0 12s5.372 12 12 12 12-5.372 12-12S18.628 0 12 0zm1.604 14.4h-3.405V18H7.801V6h5.804a4.2 4.2 0 0 1 0 8.4z"/></svg>
              </Link>
            </div>
            <p className="footer-copy">© 2026 Apoorv Darshan. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </>
  );
}
