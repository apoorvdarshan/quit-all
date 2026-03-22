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
  { icon: "🔍", title: "Pattern Intelligence", desc: "Your cravings have patterns. We find them. Hourly heatmaps, trigger analysis, and danger zone alerts before you even feel the urge." },
  { icon: "◆", title: "Milestone Rewards", desc: "From 1 hour to 1 year — 9 science-backed milestones. Each one unlocks a health fact and a card you can share." },
  { icon: "¤", title: "Money Tracker", desc: "See exactly how much you've saved. Project 5 years out. See what you could buy — from coffee to a car." },
  { icon: "∞", title: "2,790+ Memes", desc: "Five categories. Nine addiction types. Fresh GIFs every session. Motivational, roasts, consequences, distractions, and relatable." },
  { icon: "↺", title: "Zero-Shame Relapse", desc: "It happened. That's okay. Log it, learn from it, restart. Your history is saved. Your progress is never lost." },
];

const addictions = [
  { name: "Smoking", color: "#607D8B" },
  { name: "Vaping", color: "#607D8B" },
  { name: "Alcohol", color: "#FF8F00" },
  { name: "Porn", color: "#7B1FA2" },
  { name: "Social Media", color: "#1565C0" },
  { name: "Weed", color: "#2E7D32" },
  { name: "Gambling", color: "#C62828" },
  { name: "Overspending", color: "#F9A825" },
  { name: "Caffeine", color: "#4E342E" },
];

export default function Home() {
  return (
    <>
      {/* Nav */}
      <nav className="fixed top-0 w-full z-50 border-b" style={{ background: "rgba(6,6,6,0.85)", backdropFilter: "blur(24px)", borderColor: "var(--border)" }}>
        <div className="max-w-[1200px] mx-auto px-8 py-5 flex justify-between items-center">
          <Link href="/" className="flex items-center gap-3 group">
            <Image src="/logo.png" alt="Quit All" width={32} height={32} className="rounded-lg opacity-90 group-hover:opacity-100 transition-opacity" />
            <span className="font-display text-xl font-semibold tracking-wide" style={{ color: "var(--gold)" }}>
              QUIT ALL
            </span>
          </Link>
          <div className="hidden md:flex items-center gap-10">
            {["Features", "Privacy", "Terms", "Support"].map((item) => (
              <Link
                key={item}
                href={item === "Features" ? "#features" : `/${item.toLowerCase()}`}
                className="text-[13px] font-body font-light tracking-[2px] uppercase transition-colors duration-300"
                style={{ color: "var(--text-muted)" }}
                onMouseEnter={(e) => (e.currentTarget.style.color = "var(--gold)")}
                onMouseLeave={(e) => (e.currentTarget.style.color = "var(--text-muted)")}
              >
                {item}
              </Link>
            ))}
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
        {/* Background effects */}
        <div className="absolute inset-0">
          <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[600px] rounded-full opacity-[0.04]"
            style={{ background: "radial-gradient(circle, var(--gold) 0%, transparent 70%)" }} />
          <div className="absolute bottom-0 left-0 w-full h-px" style={{ background: "linear-gradient(90deg, transparent, var(--gold), transparent)", opacity: 0.15 }} />
        </div>

        <div className="relative z-10 text-center px-6 pt-32 pb-24 max-w-[900px] mx-auto">
          <motion.div initial="hidden" animate="visible" variants={fadeUp} custom={0}
            className="inline-block mb-10 px-5 py-2.5 rounded-full text-[11px] font-body font-light tracking-[4px] uppercase"
            style={{ border: "1px solid rgba(201,168,76,0.2)", color: "var(--gold)" }}>
            Break every chain
          </motion.div>

          <motion.h1 initial="hidden" animate="visible" variants={fadeUp} custom={1}
            className="font-display font-light text-[clamp(3rem,8vw,6.5rem)] leading-[0.95] mb-8 tracking-tight">
            Quit{" "}
            <span className="gold-shimmer font-semibold italic">everything.</span>
            <br />
            <span className="text-[0.65em] font-light" style={{ color: "var(--text-muted)" }}>All at once.</span>
          </motion.h1>

          <motion.p initial="hidden" animate="visible" variants={fadeUp} custom={2}
            className="font-body font-light text-[17px] leading-[1.8] max-w-[480px] mx-auto mb-12"
            style={{ color: "var(--text-muted)" }}>
            Nine addictions. One app. Track your streaks, survive cravings with memes and GIFs, watch your money grow, and never feel ashamed of a setback.
          </motion.p>

          <motion.a initial="hidden" animate="visible" variants={fadeUp} custom={3}
            href="#"
            className="inline-flex items-center gap-3 px-10 py-4 rounded-xl font-display text-[15px] font-medium tracking-[1px] text-white transition-all duration-300 hover:-translate-y-0.5"
            style={{
              background: "linear-gradient(135deg, var(--gold), var(--gold-dim))",
              boxShadow: "0 0 60px rgba(201,168,76,0.15), 0 8px 32px rgba(0,0,0,0.4)",
            }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>
            Download for iOS
          </motion.a>

          {/* Product Hunt */}
          <motion.a initial="hidden" animate="visible" variants={fadeUp} custom={3.5}
            href="#"
            className="inline-flex items-center gap-3 ml-4 px-7 py-4 rounded-xl font-body text-[13px] font-light tracking-[1px] transition-all duration-300 hover:-translate-y-0.5 hover:border-[var(--gold)]"
            style={{
              border: "1px solid rgba(201,168,76,0.2)",
              color: "var(--gold)",
            }}>
            <svg width="18" height="18" viewBox="0 0 40 40" fill="none">
              <circle cx="20" cy="20" r="20" fill="currentColor" fillOpacity="0.15"/>
              <path d="M22.667 20H18v-6.667h4.667a3.333 3.333 0 0 1 0 6.667z" fill="currentColor"/>
              <path d="M14.667 10h8a6.667 6.667 0 0 1 0 13.333h-4.334V30h-3.666V10z" fill="currentColor"/>
            </svg>
            Find us on Product Hunt
          </motion.a>

          {/* Addiction pills */}
          <motion.div initial="hidden" animate="visible" variants={fadeUp} custom={4}
            className="mt-16 flex flex-wrap justify-center gap-2.5">
            {addictions.map((a) => (
              <span key={a.name}
                className="px-4 py-2 rounded-full text-[12px] font-body font-light tracking-[1px] transition-all duration-300 cursor-default hover:scale-105"
                style={{
                  background: `${a.color}10`,
                  border: `1px solid ${a.color}25`,
                  color: a.color,
                }}>
                {a.name}
              </span>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Divider */}
      <div className="gold-line mx-auto max-w-[200px]" />

      {/* Features */}
      <section id="features" className="py-32 px-6">
        <div className="max-w-[1100px] mx-auto">
          <motion.div initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-100px" }}>
            <motion.p variants={fadeUp} custom={0}
              className="font-display text-[12px] font-light tracking-[5px] uppercase mb-5" style={{ color: "var(--gold-dim)" }}>
              What&apos;s inside
            </motion.p>
            <motion.h2 variants={fadeUp} custom={1}
              className="font-display text-[clamp(2rem,5vw,3.5rem)] font-light leading-[1.15] mb-6">
              Tools that actually{" "}
              <span className="italic font-semibold" style={{ color: "var(--gold)" }}>work.</span>
            </motion.h2>
            <motion.p variants={fadeUp} custom={2}
              className="font-body font-light text-[16px] max-w-[500px] mb-16 leading-relaxed" style={{ color: "var(--text-muted)" }}>
              No generic advice. No toxic positivity. Real tools built for people who are actually trying to quit.
            </motion.p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-[1px]" style={{ background: "var(--border)" }}>
            {features.map((f, i) => (
              <motion.div
                key={f.title}
                initial="hidden" whileInView="visible" viewport={{ once: true }}
                variants={fadeUp} custom={i * 0.5}
                className="p-10 group transition-colors duration-500 hover:bg-[#121210]"
                style={{ background: "var(--bg)" }}>
                <div className="text-[28px] mb-6 font-display font-light transition-colors duration-500"
                  style={{ color: "var(--gold-dim)" }}>
                  {f.icon}
                </div>
                <h3 className="font-display text-[19px] font-medium mb-3 tracking-wide group-hover:text-[var(--gold-bright)] transition-colors duration-500">
                  {f.title}
                </h3>
                <p className="font-body font-light text-[14px] leading-[1.8]" style={{ color: "var(--text-muted)" }}>
                  {f.desc}
                </p>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Stats */}
      <section className="py-24 px-6 border-y" style={{ background: "var(--surface)", borderColor: "var(--border)" }}>
        <div className="max-w-[1100px] mx-auto">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-16 text-center">
            {[
              { v: "9", l: "Addictions" },
              { v: "2,790", l: "Memes" },
              { v: "9", l: "Milestones" },
              { v: "0", l: "Data Collected" },
            ].map((s, i) => (
              <motion.div key={s.l}
                initial="hidden" whileInView="visible" viewport={{ once: true }}
                variants={fadeUp} custom={i}>
                <div className="font-display text-[clamp(2.5rem,6vw,4rem)] font-light tracking-tight" style={{ color: "var(--gold)" }}>
                  {s.v}
                </div>
                <div className="font-body text-[12px] font-light tracking-[3px] uppercase mt-2" style={{ color: "var(--text-muted)" }}>
                  {s.l}
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="relative py-40 px-6 text-center overflow-hidden">
        <div className="absolute inset-0">
          <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[600px] h-[400px] rounded-full opacity-[0.03]"
            style={{ background: "radial-gradient(circle, var(--gold) 0%, transparent 70%)" }} />
        </div>
        <motion.div className="relative z-10"
          initial="hidden" whileInView="visible" viewport={{ once: true }}>
          <motion.p variants={fadeUp} custom={0}
            className="font-display text-[12px] font-light tracking-[5px] uppercase mb-8" style={{ color: "var(--gold-dim)" }}>
            Your move
          </motion.p>
          <motion.h2 variants={fadeUp} custom={1}
            className="font-display text-[clamp(2.5rem,6vw,4.5rem)] font-light leading-[1.1] mb-6">
            The best time to quit<br />
            <span className="italic font-semibold" style={{ color: "var(--gold)" }}>was yesterday.</span>
          </motion.h2>
          <motion.p variants={fadeUp} custom={2}
            className="font-body font-light text-[16px] mb-12" style={{ color: "var(--text-muted)" }}>
            The second best time is right now.
          </motion.p>
          <motion.a variants={fadeUp} custom={3}
            href="#"
            className="inline-flex items-center gap-3 px-10 py-4 rounded-xl font-display text-[15px] font-medium tracking-[1px] text-white transition-all duration-300 hover:-translate-y-0.5"
            style={{
              background: "linear-gradient(135deg, var(--gold), var(--gold-dim))",
              boxShadow: "0 0 80px rgba(201,168,76,0.12), 0 8px 32px rgba(0,0,0,0.4)",
            }}>
            Download Quit All
          </motion.a>
        </motion.div>
      </section>

      {/* Footer */}
      <footer className="py-16 px-6 border-t" style={{ borderColor: "var(--border)" }}>
        <div className="max-w-[1100px] mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
          <div className="flex items-center gap-3">
            <Image src="/logo.png" alt="Quit All" width={24} height={24} className="rounded-md opacity-60" />
            <span className="font-display text-sm tracking-[2px] uppercase" style={{ color: "var(--text-muted)" }}>
              Quit All
            </span>
          </div>
          <div className="flex gap-8">
            {[
              { label: "Privacy", href: "/privacy" },
              { label: "Terms", href: "/terms" },
              { label: "Support", href: "/support" },
              { label: "Product Hunt", href: "#" },
              { label: "GitHub", href: "https://github.com/apoorvdarshan/quit-all" },
            ].map((link) => (
              <Link key={link.label} href={link.href}
                className="font-body text-[12px] font-light tracking-[2px] uppercase transition-colors duration-300"
                style={{ color: "var(--text-muted)" }}
                onMouseEnter={(e) => (e.currentTarget.style.color = "var(--gold)")}
                onMouseLeave={(e) => (e.currentTarget.style.color = "var(--text-muted)")}>
                {link.label}
              </Link>
            ))}
          </div>
          <p className="font-body text-[11px] font-light" style={{ color: "var(--text-muted)" }}>
            © 2026
          </p>
        </div>
      </footer>
    </>
  );
}
