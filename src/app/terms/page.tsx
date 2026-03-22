import Link from "next/link";
import Image from "next/image";

export const metadata = { title: "Terms of Service — Quit All" };

export default function Terms() {
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
        <p className="font-display text-[11px] tracking-[5px] uppercase mb-5" style={{ color: "var(--gold-dim)" }}>Legal</p>
        <h1 className="font-display text-[clamp(2rem,5vw,3rem)] font-light mb-2" style={{ color: "var(--gold-bright)" }}>Terms of Service</h1>
        <p className="font-body text-[13px] font-light mb-16" style={{ color: "var(--text-muted)" }}>Last updated: March 22, 2026</p>

        <article className="space-y-10">
          <S title="Acceptance of Terms">
            <p>By downloading or using Quit All, you agree to these Terms. If you do not agree, do not use the app.</p>
          </S>
          <S title="Description of Service">
            <p>Quit All is a habit-tracking and addiction recovery app providing tools for tracking sobriety streaks, logging cravings, viewing motivational content, and monitoring savings. It is not a substitute for professional medical advice, diagnosis, or treatment.</p>
          </S>
          <S title="Subscriptions">
            <ul className="space-y-2 list-none">
              <Li>Auto-renewable subscriptions: Monthly ($7.99/mo) and Yearly ($49.99/yr)</Li>
              <Li>Payment charged to your Apple ID at confirmation</Li>
              <Li>Auto-renews unless canceled 24 hours before period end</Li>
              <Li>Manage and cancel in Apple ID account settings</Li>
              <Li>Free trial forfeited upon purchasing a subscription</Li>
            </ul>
          </S>
          <S title="Medical Disclaimer">
            <p>Quit All is <strong style={{ color: "var(--text)" }}>not</strong> a medical app. It does not provide medical advice, diagnosis, or treatment. If you are dealing with substance abuse, please consult a healthcare professional. This app is a supplementary tool.</p>
          </S>
          <S title="Content">
            <p>Memes, GIFs, and text are for entertainment and motivation. Some content contains humor about addiction. All GIF content is SFW and sourced from Giphy&apos;s PG-rated library.</p>
          </S>
          <S title="User Responsibility">
            <ul className="space-y-2 list-none">
              <Li>You are responsible for maintaining the confidentiality of your data</Li>
              <Li>You agree not to misuse or reverse-engineer the app</Li>
              <Li>Data is stored locally; data loss may occur if the app is deleted</Li>
            </ul>
          </S>
          <S title="Limitation of Liability">
            <p>Quit All is provided &ldquo;as is&rdquo; without warranties. We are not liable for any damages arising from use or inability to use the app.</p>
          </S>
          <S title="Contact">
            <p>Questions? <a href="mailto:ad13dtu@gmail.com" style={{ color: "var(--gold)" }}>ad13dtu@gmail.com</a></p>
          </S>
        </article>
      </main>
    </>
  );
}

function S({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="font-display text-[20px] font-medium mb-4" style={{ color: "var(--text)" }}>{title}</h2>
      <div className="font-body font-light text-[15px] leading-[1.9]" style={{ color: "var(--text-muted)" }}>{children}</div>
    </section>
  );
}

function Li({ children }: { children: React.ReactNode }) {
  return (
    <li className="flex gap-3 items-start">
      <span className="mt-2 w-1 h-1 rounded-full shrink-0" style={{ background: "var(--gold-dim)" }} />
      <span>{children}</span>
    </li>
  );
}
