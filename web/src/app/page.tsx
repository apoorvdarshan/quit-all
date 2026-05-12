"use client";

import Image from "next/image";
import Link from "next/link";
import { motion, useScroll, useTransform } from "framer-motion";
import { useRef } from "react";
import { seoPages } from "./seoPages";

// Richer animation variants
const ease = [0.16, 1, 0.3, 1] as const;

const fadeUp = {
  hidden: { opacity: 0, y: 50, filter: "blur(8px)" },
  visible: (i: number) => ({
    opacity: 1, y: 0, filter: "blur(0px)",
    transition: { duration: 1, delay: i * 0.12, ease }
  }),
};

const scaleIn = {
  hidden: { opacity: 0, scale: 0.9 },
  visible: (i: number) => ({
    opacity: 1, scale: 1,
    transition: { duration: 0.8, delay: i * 0.08, ease }
  }),
};

const slideIn = {
  hidden: { opacity: 0, x: -30 },
  visible: (i: number) => ({
    opacity: 1, x: 0,
    transition: { duration: 0.7, delay: i * 0.06, ease }
  }),
};

const features = [
  { icon: "⚡", title: "SOS Craving Button", desc: "Online GIFs when you have connection, bundled offline loops when you do not. Swipe while the craving passes." },
  { icon: "🔍", title: "Pattern Intelligence", desc: "Your cravings have patterns. Hourly heatmaps, trigger analysis, and danger-time reminders reveal them." },
  { icon: "◆", title: "Streaks & Widgets", desc: "Track clean time in the app, then keep progress visible from Home Screen and Lock Screen widgets." },
  { icon: "¤", title: "Money Tracker", desc: "Watch savings grow in real-time. Project 5 years out. See what you could buy with the money." },
  { icon: "∞", title: "GIFs, Memes & Loops", desc: "Klipy-powered GIFs, 2,790+ text memes, and local fallback videos for SOS sessions." },
  { icon: "↺", title: "Zero-Shame Relapse", desc: "It happened. That's okay. Log it, learn, restart. Your history is saved. Progress is never lost." },
];

const addictions = [
  { name: "Smoking", color: "#607D8B" }, { name: "Vaping", color: "#607D8B" },
  { name: "Alcohol", color: "#FF8F00" }, { name: "Porn", color: "#7B1FA2" },
  { name: "Social Media", color: "#1565C0" }, { name: "Weed", color: "#2E7D32" },
  { name: "Gambling", color: "#C62828" }, { name: "Overspending", color: "#F9A825" },
  { name: "Caffeine", color: "#4E342E" },
];

const screenshots = [
  { src: "/ss-onboarding.jpg", alt: "Choose the habits you want to quit in Quit All" },
  { src: "/ss-home.jpg", alt: "Quit All home streak dashboard" },
  { src: "/ss-sos-klipy.jpg", alt: "Quit All SOS screen using a Klipy GIF" },
  { src: "/ss-sos-offline.jpg", alt: "Quit All SOS screen using an offline fallback loop" },
  { src: "/ss-stats-new.jpg", alt: "Quit All stats dashboard" },
];

export default function Home() {
  const heroRef = useRef(null);
  const { scrollYProgress } = useScroll({ target: heroRef, offset: ["start start", "end start"] });
  const heroY = useTransform(scrollYProgress, [0, 1], [0, 150]);
  const heroOpacity = useTransform(scrollYProgress, [0, 0.8], [1, 0]);

  return (
    <>
      {/* Nav */}
      <motion.nav className="nav"
        initial={{ y: -80, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.8, delay: 0.5, ease: [0.16, 1, 0.3, 1] }}>
        <div className="nav-inner">
          <Link href="/" className="nav-logo">
            <Image src="/logo.png" alt="Quit All" width={32} height={32} />
            <span>QUIT ALL</span>
          </Link>
          <div className="nav-links">
            <Link href="#features">Features</Link>
            <Link href="#quit-guides">Guides</Link>
            <Link href="#pricing">Pricing</Link>
            <Link href="/privacy">Privacy</Link>
            <Link href="/terms">Terms</Link>
          </div>
        </div>
      </motion.nav>

      {/* Hero — parallax */}
      <section className="hero" ref={heroRef}>
        <div className="hero-glow" />
        <div className="hero-line" />
        <motion.div className="hero-content" style={{ y: heroY, opacity: heroOpacity }}>
          <motion.div initial="hidden" animate="visible" variants={fadeUp} custom={0} className="hero-badge">
            Break every chain
          </motion.div>

          <motion.h1 initial="hidden" animate="visible" variants={fadeUp} custom={1}>
            Quit <span className="gold-shimmer" style={{ fontWeight: 600, fontStyle: "italic" }}>everything.</span>
            <br /><span className="sub">All at once.</span>
          </motion.h1>

          <motion.p initial="hidden" animate="visible" variants={fadeUp} custom={2}>
            Nine addictions. One app. Track streaks, survive cravings with GIFs and offline fallback loops, watch your money grow, and restart without shame.
          </motion.p>

          <motion.div initial="hidden" animate="visible" variants={fadeUp} custom={3} className="hero-buttons">
            <a href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934" target="_blank" className="btn-gold">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
              Download for iOS
            </a>
            <a href="https://www.producthunt.com/products/quit-all-break-every-habit" target="_blank" className="btn-outline">
              <svg width="18" height="18" viewBox="0 0 40 40" fill="none"><circle cx="20" cy="20" r="20" fill="currentColor" fillOpacity="0.15"/><path d="M22.667 20H18v-6.667h4.667a3.333 3.333 0 0 1 0 6.667z" fill="currentColor"/><path d="M14.667 10h8a6.667 6.667 0 0 1 0 13.333h-4.334V30h-3.666V10z" fill="currentColor"/></svg>
              Find us on Product Hunt
            </a>
          </motion.div>

          <motion.div initial="hidden" animate="visible" className="addiction-pills">
            {addictions.map((a, i) => (
              <motion.span key={a.name} className="addiction-pill"
                variants={scaleIn} custom={i}
                whileHover={{ scale: 1.12, transition: { duration: 0.2 } }}
                style={{ background: `${a.color}10`, border: `1px solid ${a.color}25`, color: a.color }}>
                {a.name}
              </motion.span>
            ))}
          </motion.div>
        </motion.div>
      </section>

      <div className="gold-line" />

      {/* Features */}
      <section id="features" className="features">
        <div className="container">
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-80px" }}>
            <motion.p variants={slideIn} custom={0} className="features-label">What&apos;s inside</motion.p>
            <motion.h2 variants={fadeUp} custom={1} className="features-title">
              Tools that actually <em>work.</em>
            </motion.h2>
            <motion.p variants={fadeUp} custom={2} className="features-subtitle">
              No generic advice. No toxic positivity. Real tools for people actually trying to quit.
            </motion.p>
          </motion.div>

          <div className="features-grid">
            {features.map((f, i) => (
              <motion.div key={f.title} className="feature-card"
                initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-50px" }}
                variants={scaleIn} custom={i}
                whileHover={{ y: -6, transition: { duration: 0.3 } }}>
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
            <motion.p variants={slideIn} custom={0} className="features-label">See it in action</motion.p>
            <motion.h2 variants={fadeUp} custom={1} className="features-title">
              Built for <em>real moments.</em>
            </motion.h2>
          </motion.div>
        </div>
        <motion.div className="screenshots-scroll"
          initial="hidden" whileInView="visible" viewport={{ once: true }}>
          {screenshots.map((ss, i) => (
            <motion.div key={ss.src} className="screenshot-item"
              variants={scaleIn} custom={i}
              whileHover={{ scale: 1.06, y: -8, transition: { duration: 0.3 } }}>
              <Image src={ss.src} alt={ss.alt} width={220} height={476} style={{ width: "100%", height: "auto" }} />
            </motion.div>
          ))}
        </motion.div>
      </section>

      {/* Quit guides */}
      <section id="quit-guides" className="quit-guides">
        <div className="container">
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-80px" }}>
            <motion.p variants={slideIn} custom={0} className="features-label">Quit guides</motion.p>
            <motion.h2 variants={fadeUp} custom={1} className="features-title">
              Find the tracker for <em>your habit.</em>
            </motion.h2>
            <motion.p variants={fadeUp} custom={2} className="features-subtitle">
              Dedicated guides for the habits Quit All supports, written for people looking for the right tracker fast.
            </motion.p>
          </motion.div>

          <motion.div className="quit-guides-grid" initial="hidden" whileInView="visible" viewport={{ once: true }}>
            {seoPages.map((guide, i) => (
              <motion.div key={guide.slug} variants={scaleIn} custom={i}>
                <Link href={`/${guide.slug}`} className="quit-guide-card">
                  <span>{guide.eyebrow}</span>
                  <strong>{guide.label}</strong>
                  <small>{guide.metaDescription}</small>
                </Link>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="pricing">
        <div className="container" style={{ textAlign: "center" }}>
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true }}>
            <motion.p variants={slideIn} custom={0} className="features-label">Pricing</motion.p>
            <motion.h2 variants={fadeUp} custom={1} className="features-title" style={{ marginLeft: "auto", marginRight: "auto" }}>
              Invest in <em>yourself.</em>
            </motion.h2>
            <motion.p variants={fadeUp} custom={2} className="features-subtitle" style={{ marginLeft: "auto", marginRight: "auto" }}>
              Less than a pack of cigarettes. Less than a night out drinking. Worth more than both.
            </motion.p>
          </motion.div>

          <motion.div className="pricing-grid" initial="hidden" whileInView="visible" viewport={{ once: true }}>
            <motion.div variants={fadeUp} custom={0} className="pricing-card"
              whileHover={{ y: -8, transition: { duration: 0.3 } }}>
              <p className="pricing-name">Monthly</p>
              <p className="pricing-price">$7.99<span>/mo</span></p>
              <p className="pricing-sub">Billed monthly</p>
              <ul className="pricing-features">
                <li>All 9 addiction types</li>
                <li>SOS GIFs, memes &amp; offline loops</li>
                <li>Stats &amp; pattern detection</li>
                <li>Milestones &amp; sharing</li>
                <li>Smart notifications</li>
              </ul>
              <p className="pricing-trial">3-day free trial</p>
              <a href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934" target="_blank" className="pricing-btn pricing-btn-secondary">Start Free Trial</a>
            </motion.div>

            <motion.div variants={fadeUp} custom={1} className="pricing-card featured"
              whileHover={{ y: -8, transition: { duration: 0.3 } }}>
              <div className="pricing-badge">Save 48%</div>
              <p className="pricing-name">Yearly</p>
              <p className="pricing-price">$49.99<span>/yr</span></p>
              <p className="pricing-sub">$4.17/month — best value</p>
              <ul className="pricing-features">
                <li>Everything in Monthly</li>
                <li>Save $45.89 per year</li>
                <li>Home &amp; Lock Screen widgets</li>
                <li>Support development</li>
                <li>Cancel anytime</li>
              </ul>
              <p className="pricing-trial">3-day free trial</p>
              <a href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934" target="_blank" className="pricing-btn pricing-btn-primary">Start Free Trial</a>
            </motion.div>

            <motion.div variants={fadeUp} custom={2} className="pricing-card"
              whileHover={{ y: -8, transition: { duration: 0.3 } }}>
              <p className="pricing-name">Lifetime</p>
              <p className="pricing-price">$99.99<span>/once</span></p>
              <p className="pricing-sub">One-time purchase</p>
              <ul className="pricing-features">
                <li>All premium features forever</li>
                <li>No renewal</li>
                <li>No subscription management</li>
                <li>Future premium updates</li>
                <li>Family-friendly App Store billing</li>
              </ul>
              <p className="pricing-trial">No recurring charge</p>
              <a href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934" target="_blank" className="pricing-btn pricing-btn-secondary">Buy Lifetime</a>
            </motion.div>
          </motion.div>
        </div>
      </section>

      <div className="gold-line" />

      {/* Stats — counter-like feel */}
      <section className="stats">
        <div className="container">
          <div className="stats-grid">
            {[
              { v: "9", l: "Addictions" }, { v: "2,790+", l: "Text Memes" },
              { v: "9", l: "Milestones" }, { v: "0", l: "Accounts Required" },
            ].map((s, i) => (
              <motion.div key={s.l}
                initial="hidden" whileInView="visible" viewport={{ once: true }}
                variants={scaleIn} custom={i}
                whileHover={{ scale: 1.08, transition: { duration: 0.2 } }}>
                <div className="stat-value">{s.v}</div>
                <div className="stat-label">{s.l}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="cta">
        <div className="cta-glow" />
        <motion.div style={{ position: "relative", zIndex: 10 }} initial="hidden" whileInView="visible" viewport={{ once: true }}>
          <motion.p variants={slideIn} custom={0} className="cta-label">Your move</motion.p>
          <motion.h2 variants={fadeUp} custom={1}>The best time to quit<br /><em>was yesterday.</em></motion.h2>
          <motion.p variants={fadeUp} custom={2} style={{ fontSize: 16, color: "var(--text-muted)", marginBottom: 48 }}>The second best time is right now.</motion.p>
          <motion.a variants={fadeUp} custom={3} href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934" target="_blank"
            className="btn-gold"
            whileHover={{ scale: 1.04, transition: { duration: 0.2 } }}
            whileTap={{ scale: 0.97 }}>
            Download Quit All
          </motion.a>
        </motion.div>
      </section>

      {/* SEO Content */}
      <section className="seo-content">
        <div className="container">
          <h2>Quit Smoking, Vaping, Alcohol and More</h2>
          <p>Quit All, sometimes searched as AllQuit, helps you quit smoking, stop vaping, quit drinking alcohol, break gambling patterns, quit weed, reduce caffeine, stop overspending, and cut down on social media. Track every streak in one place, use the SOS craving button for Klipy GIFs plus offline fallback loops, log relapses without shame, and see savings and milestones build over time. No account is required. Habit data stays on your iPhone, with purchases handled through Apple and RevenueCat.</p>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer">
        <div className="container">
          <div className="footer-inner">
            <div className="footer-logo">
              <Image src="/logo.png" alt="Quit All" width={24} height={24} />
              <span>Quit All</span>
            </div>
            <div className="footer-links">
              <Link href="/#quit-guides">Guides</Link>
              <Link href="/privacy">Privacy</Link>
              <Link href="/terms">Terms</Link>
              <Link href="https://trustmrr.com/startup/quit-all-break-every-habit" target="_blank">TrustMRR</Link>
              <Link href="https://ko-fi.com/apoorvdarshan" target="_blank">Support</Link>
              <Link href="mailto:ad13dtu@gmail.com">Contact</Link>
            </div>
            <div className="footer-links footer-socials">
              <Link href="https://x.com/apoorvdarshan" target="_blank" aria-label="X">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
              </Link>
              <Link href="https://ko-fi.com/apoorvdarshan" target="_blank" aria-label="Ko-fi">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M3.5 5h13a3.5 3.5 0 0 1 3.34 4.55A4 4 0 0 1 16 14.5h-.62A6.5 6.5 0 0 1 9.5 18h-6A1.5 1.5 0 0 1 2 16.5v-10A1.5 1.5 0 0 1 3.5 5Zm13.5 2.1v5.28A2.1 2.1 0 0 0 17 7.1ZM5 8v7h4.5a3.5 3.5 0 0 0 3.5-3.5V8H5Zm2.2 1.6c.76-.68 1.88-.61 2.55.15.67-.76 1.79-.83 2.55-.15.8.72.82 1.96.07 2.72l-2.62 2.56-2.62-2.56c-.75-.76-.73-2 .07-2.72Z"/></svg>
              </Link>
              <Link href="https://www.instagram.com/quitall_com/" target="_blank" aria-label="Instagram">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M7.8 2h8.4A5.807 5.807 0 0 1 22 7.8v8.4a5.807 5.807 0 0 1-5.8 5.8H7.8A5.807 5.807 0 0 1 2 16.2V7.8A5.807 5.807 0 0 1 7.8 2m-.2 2A3.6 3.6 0 0 0 4 7.6v8.8A3.6 3.6 0 0 0 7.6 20h8.8a3.6 3.6 0 0 0 3.6-3.6V7.6A3.6 3.6 0 0 0 16.4 4H7.6m9.65 1.5a1.25 1.25 0 1 1 0 2.5 1.25 1.25 0 0 1 0-2.5M12 7a5 5 0 1 1 0 10 5 5 0 0 1 0-10m0 2a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"/></svg>
              </Link>
              <Link href="https://www.linkedin.com/company/quit-all/" target="_blank" aria-label="LinkedIn">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 0 1-2.063-2.065 2.064 2.064 0 1 1 2.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
              </Link>
              <Link href="https://www.producthunt.com/products/quit-all-break-every-habit" target="_blank" aria-label="Product Hunt">
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
