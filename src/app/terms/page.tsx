import Link from "next/link";
import Image from "next/image";

export const metadata = { title: "Terms of Service — Quit All" };

export default function Terms() {
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
          <h1 className="legal-title">Terms of Service</h1>
          <p className="legal-date">Last updated: March 22, 2026</p>
        </div>
        <div className="legal-section"><h2>Acceptance of Terms</h2><p>By downloading or using Quit All, you agree to these Terms. If you do not agree, do not use the app.</p></div>
        <div className="legal-section"><h2>Description of Service</h2><p>Quit All is a habit-tracking and addiction recovery app. It is not a substitute for professional medical advice, diagnosis, or treatment.</p></div>
        <div className="legal-section"><h2>Subscriptions</h2><ul><li>Auto-renewable: Monthly ($7.99/mo) and Yearly ($49.99/yr)</li><li>Payment charged to your Apple ID at confirmation</li><li>Auto-renews unless canceled 24 hours before period end</li><li>Manage in Apple ID account settings</li><li>Free trial forfeited upon purchasing</li></ul></div>
        <div className="legal-section"><h2>Medical Disclaimer</h2><p>Quit All is <strong style={{color:"var(--text)"}}>not</strong> a medical app. Consult a healthcare professional for substance abuse. This is a supplementary tool.</p></div>
        <div className="legal-section"><h2>Content</h2><p>Memes, GIFs, and text are for entertainment and motivation. All GIF content is SFW from Giphy&apos;s PG-rated library.</p></div>
        <div className="legal-section"><h2>User Responsibility</h2><ul><li>You are responsible for maintaining the confidentiality of your data</li><li>You agree not to misuse or reverse-engineer the app</li><li>Data is stored locally; data loss may occur if the app is deleted</li></ul></div>
        <div className="legal-section"><h2>Limitation of Liability</h2><p>Provided &ldquo;as is&rdquo; without warranties. We are not liable for damages arising from use.</p></div>
        <div className="legal-section"><h2>Contact</h2><p><a href="mailto:ad13dtu@gmail.com">ad13dtu@gmail.com</a></p></div>
      </main>
    </>
  );
}
