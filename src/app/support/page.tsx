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
      <nav className="nav">
        <div className="nav-inner" style={{ maxWidth: 800 }}>
          <Link href="/" className="nav-logo">
            <Image src="/logo.png" alt="Quit All" width={28} height={28} />
            <span>QUIT ALL</span>
          </Link>
          <Link href="/" className="nav-links" style={{ gap: 0 }}><span>Home</span></Link>
        </div>
      </nav>
      <main className="container-sm" style={{ paddingTop: 128, paddingBottom: 96 }}>
        <div className="legal-header">
          <p className="legal-label">Help</p>
          <h1 className="legal-title">Support</h1>
          <p className="legal-date">Get help with Quit All</p>
        </div>

        <div className="contact-card">
          <h2>Contact Us</h2>
          <a href="mailto:ad13dtu@gmail.com" className="contact-link">
            <span className="contact-icon">✉</span> ad13dtu@gmail.com
          </a>
          <a href="https://github.com/apoorvdarshan/quit-all" className="contact-link">
            <span className="contact-icon">◇</span> github.com/apoorvdarshan/quit-all
          </a>
        </div>

        <h2 style={{ fontFamily: "var(--font-display)", fontSize: 20, fontWeight: 500, marginBottom: 24 }}>Frequently Asked Questions</h2>
        {faqs.map((faq) => (
          <div key={faq.q} className="faq-item">
            <h3>{faq.q}</h3>
            <p>{faq.a}</p>
          </div>
        ))}
      </main>
    </>
  );
}
