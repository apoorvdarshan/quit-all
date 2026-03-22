import Link from "next/link";
import Image from "next/image";

export const metadata = { title: "Privacy Policy — Quit All" };

export default function Privacy() {
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
        <h1 className="font-display text-[clamp(2rem,5vw,3rem)] font-light mb-2" style={{ color: "var(--gold-bright)" }}>Privacy Policy</h1>
        <p className="font-body text-[13px] font-light mb-16" style={{ color: "var(--text-muted)" }}>Last updated: March 22, 2026</p>

        <article className="space-y-10">
          <Section title="Overview">
            <p>Quit All (&ldquo;we&rdquo;, &ldquo;our&rdquo;, &ldquo;the app&rdquo;) is committed to protecting your privacy. This Privacy Policy explains how we handle your information.</p>
          </Section>

          <Section title="Data Collection">
            <p className="mb-4">Quit All does <strong style={{ color: "var(--text)" }}>not</strong> collect, store, or transmit any personal data to external servers. All your data stays on your device.</p>
            <ul className="space-y-2 list-none">
              <Li>Addiction tracking data — stored locally using CoreData</Li>
              <Li>Craving logs, relapse history, milestones — stored locally, never transmitted</Li>
              <Li>No accounts — no sign-up, no login, no email required</Li>
              <Li>No analytics — we don&apos;t track your behavior</Li>
              <Li>No advertising — we don&apos;t serve ads or share data</Li>
            </ul>
          </Section>

          <Section title="Third-Party Services">
            <ul className="space-y-2 list-none">
              <Li><strong style={{ color: "var(--text)" }}>Giphy API</strong> — Fetches GIF images. Giphy may collect usage data per their own policy. No personal data is sent.</Li>
              <Li><strong style={{ color: "var(--text)" }}>Apple StoreKit</strong> — Handles subscriptions. Payment processing is entirely by Apple.</Li>
            </ul>
          </Section>

          <Section title="Data Storage">
            <p>All data is stored locally on your device. Deleting the app permanently deletes all data. We have no backups.</p>
          </Section>

          <Section title="Children's Privacy">
            <p>Quit All is not intended for children under 17. We do not knowingly collect data from children.</p>
          </Section>

          <Section title="Contact">
            <p>Questions? Contact us at <a href="mailto:ad13dtu@gmail.com" className="transition-colors" style={{ color: "var(--gold)" }}>ad13dtu@gmail.com</a></p>
          </Section>
        </article>
      </main>
    </>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
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
