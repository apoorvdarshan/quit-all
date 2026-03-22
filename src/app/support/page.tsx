import Link from "next/link";
import Image from "next/image";

export const metadata = { title: "Support — Quit All" };

const faqs = [
  { q: "Is my data private?", a: "Yes. Everything stays on your device. Zero data leaves your phone." },
  { q: "Can I track multiple addictions?", a: "Yes. All 9 types simultaneously, each with its own streak, cost tracking, and craving history." },
  { q: "What happens if I relapse?", a: "No judgment. Log what happened, restart your streak. Your history is always saved." },
  { q: "How do I cancel my subscription?", a: "iPhone Settings → Apple ID → Subscriptions → Quit All → Cancel." },
  { q: "Can I get a refund?", a: "Refunds are handled by Apple at reportaproblem.apple.com." },
  { q: "Does it work offline?", a: "Streak tracking, memes, milestones, and stats all work offline. GIFs need internet." },
];

export default function Support() {
  return (
    <>
      <nav className="fixed top-0 w-full z-50 border-b" style={{ background: "rgba(6,6,6,0.85)", backdropFilter: "blur(24px)", borderColor: "var(--border)" }}>
        <div className="max-w-[800px] mx-auto px-8 py-5 flex justify-between items-center">
          <Link href="/" className="flex items-center gap-3">
            <Image src="/logo.png" alt="Quit All" width={28} height={28} className="rounded-lg opacity-80" />
            <span className="font-display text-lg font-semibold tracking-wide" style={{ color: "var(--gold)" }}>QUIT ALL</span>
          </Link>
          <Link href="/" className="font-body text-[12px] tracking-[2px] uppercase transition-colors" style={{ color: "var(--text-muted)" }}>Home</Link>
        </div>
      </nav>

      <main className="max-w-[800px] mx-auto px-8 pt-32 pb-24">
        <p className="font-display text-[11px] tracking-[5px] uppercase mb-5" style={{ color: "var(--gold-dim)" }}>Help</p>
        <h1 className="font-display text-[clamp(2rem,5vw,3rem)] font-light mb-2" style={{ color: "var(--gold-bright)" }}>Support</h1>
        <p className="font-body text-[13px] font-light mb-16" style={{ color: "var(--text-muted)" }}>Get help with Quit All</p>

        {/* Contact */}
        <section className="p-8 rounded-2xl mb-12" style={{ background: "var(--surface)", border: "1px solid var(--border)" }}>
          <h2 className="font-display text-[20px] font-medium mb-5" style={{ color: "var(--text)" }}>Contact Us</h2>
          <div className="space-y-4">
            <a href="mailto:ad13dtu@gmail.com" className="flex items-center gap-4 font-body text-[15px] font-light transition-colors group">
              <span className="w-10 h-10 rounded-xl flex items-center justify-center text-lg" style={{ background: "rgba(201,168,76,0.08)" }}>✉</span>
              <span style={{ color: "var(--gold)" }} className="group-hover:text-[var(--gold-bright)]">ad13dtu@gmail.com</span>
            </a>
            <a href="https://github.com/apoorvdarshan/quit-all" className="flex items-center gap-4 font-body text-[15px] font-light transition-colors group">
              <span className="w-10 h-10 rounded-xl flex items-center justify-center text-lg" style={{ background: "rgba(201,168,76,0.08)" }}>◇</span>
              <span style={{ color: "var(--gold)" }} className="group-hover:text-[var(--gold-bright)]">github.com/apoorvdarshan/quit-all</span>
            </a>
          </div>
        </section>

        {/* FAQ */}
        <section>
          <h2 className="font-display text-[20px] font-medium mb-8" style={{ color: "var(--text)" }}>
            Frequently Asked Questions
          </h2>
          <div className="space-y-3">
            {faqs.map((faq) => (
              <div key={faq.q} className="p-6 rounded-xl transition-colors" style={{ background: "var(--surface)", border: "1px solid var(--border)" }}>
                <h3 className="font-display text-[15px] font-medium mb-2" style={{ color: "var(--text)" }}>{faq.q}</h3>
                <p className="font-body text-[14px] font-light leading-relaxed" style={{ color: "var(--text-muted)" }}>{faq.a}</p>
              </div>
            ))}
          </div>
        </section>
      </main>
    </>
  );
}
