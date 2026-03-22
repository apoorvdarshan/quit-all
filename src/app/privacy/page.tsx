import Link from "next/link";
import Image from "next/image";

export const metadata = { title: "Privacy Policy — Quit All" };

export default function Privacy() {
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
          <p className="legal-label">Legal</p>
          <h1 className="legal-title">Privacy Policy</h1>
          <p className="legal-date">Last updated: March 22, 2026</p>
        </div>
        <div className="legal-section"><h2>Overview</h2><p>Quit All (&ldquo;we&rdquo;, &ldquo;our&rdquo;, &ldquo;the app&rdquo;) is committed to protecting your privacy. This Privacy Policy explains how we handle your information.</p></div>
        <div className="legal-section"><h2>Data Collection</h2><p style={{marginBottom:12}}>Quit All does <strong style={{color:"var(--text)"}}>not</strong> collect, store, or transmit any personal data to external servers.</p><ul><li>Addiction tracking data — stored locally using CoreData</li><li>Craving logs, relapse history, milestones — stored locally, never transmitted</li><li>No accounts — no sign-up, no login, no email required</li><li>No analytics — we don&apos;t track your behavior</li><li>No advertising — we don&apos;t serve ads or share data</li></ul></div>
        <div className="legal-section"><h2>Third-Party Services</h2><ul><li><strong style={{color:"var(--text)"}}>Giphy API</strong> — Fetches GIF images. Giphy may collect usage data per their own policy. No personal data is sent.</li><li><strong style={{color:"var(--text)"}}>Apple StoreKit</strong> — Handles subscriptions. Payment processing is entirely by Apple.</li></ul></div>
        <div className="legal-section"><h2>Data Storage</h2><p>All data is stored locally. Deleting the app permanently deletes all data. We have no backups.</p></div>
        <div className="legal-section"><h2>Children&apos;s Privacy</h2><p>Not intended for children under 17. We do not knowingly collect data from children.</p></div>
        <div className="legal-section"><h2>Contact</h2><p>Questions? <a href="mailto:ad13dtu@gmail.com">ad13dtu@gmail.com</a></p></div>
      </main>
    </>
  );
}
