import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { seoPageMap, seoPages, siteUrl, type SeoPage } from "../seoPages";

type Props = {
  params: Promise<{ slug: string }>;
};

export const dynamicParams = false;

export function generateStaticParams() {
  return seoPages.map((page) => ({
    slug: page.slug,
  }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const page = seoPageMap.get(slug);

  if (!page) {
    return {};
  }

  const canonical = `/${page.slug}`;

  return {
    title: page.metaTitle,
    description: page.metaDescription,
    keywords: page.keywords,
    alternates: {
      canonical,
    },
    openGraph: {
      type: "website",
      url: `${siteUrl}${canonical}`,
      title: page.metaTitle,
      description: page.metaDescription,
      siteName: "Quit All",
      images: [
        {
          url: "/og.png",
          width: 1200,
          height: 630,
          alt: `${page.label} with Quit All`,
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title: page.metaTitle,
      description: page.metaDescription,
      images: ["/og.png"],
      creator: "@apoorvdarshan",
    },
  };
}

export default async function SeoLandingPage({ params }: Props) {
  const { slug } = await params;
  const page = seoPageMap.get(slug);

  if (!page) {
    notFound();
  }

  const canonical = `${siteUrl}/${page.slug}`;
  const relatedPages = page.related
    .map((relatedSlug) => seoPageMap.get(relatedSlug))
    .filter((relatedPage): relatedPage is SeoPage => Boolean(relatedPage));

  const breadcrumbJsonLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      {
        "@type": "ListItem",
        position: 1,
        name: "Quit All",
        item: siteUrl,
      },
      {
        "@type": "ListItem",
        position: 2,
        name: page.label,
        item: canonical,
      },
    ],
  };

  const faqJsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: page.faq.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: item.answer,
      },
    })),
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbJsonLd) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />

      <nav className="nav seo-nav">
        <div className="nav-inner">
          <Link href="/" className="nav-logo">
            <Image src="/logo.png" alt="Quit All" width={32} height={32} />
            <span>QUIT ALL</span>
          </Link>
          <div className="nav-links">
            <Link href="/#features">Features</Link>
            <Link href="/#quit-guides">Guides</Link>
            <Link href="/#pricing">Pricing</Link>
            <Link href="/privacy">Privacy</Link>
          </div>
        </div>
      </nav>

      <main className="seo-page">
        <section className="seo-hero">
          <div className="container">
            <div className="seo-breadcrumb">
              <Link href="/">Quit All</Link>
              <span>/</span>
              <span>{page.label}</span>
            </div>
            <p className="features-label">{page.eyebrow}</p>
            <h1 className="seo-page-title">{page.title}</h1>
            <p className="seo-page-subtitle">{page.intro}</p>
            <div className="seo-page-actions">
              <a
                href="https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"
                target="_blank"
                className="btn-gold"
              >
                Download for iOS
              </a>
              <Link href="/#quit-guides" className="btn-outline">
                View all quit guides
              </Link>
            </div>
          </div>
        </section>

        <section className="seo-page-body">
          <div className="container">
            <div className="seo-two-column">
              <div className="seo-panel">
                <h2>What Quit All Helps You Do</h2>
                <ul className="seo-check-list">
                  {page.bullets.map((bullet) => (
                    <li key={bullet}>{bullet}</li>
                  ))}
                </ul>
              </div>

              <div className="seo-panel seo-download-panel">
                <Image src="/logo.png" alt="Quit All app icon" width={72} height={72} />
                <h2>Quit All - Break Every Habit</h2>
                <p>
                  One private iPhone app for streaks, craving SOS sessions,
                  milestones, savings, widgets, and relapse tracking across
                  nine habit types.
                </p>
              </div>
            </div>

            <div className="seo-section-grid">
              {page.sections.map((section) => (
                <article key={section.title} className="seo-section-card">
                  <h2>{section.title}</h2>
                  <p>{section.body}</p>
                </article>
              ))}
            </div>

            <section className="seo-faq">
              <p className="features-label">Questions</p>
              <h2>Common Questions</h2>
              <div className="seo-faq-list">
                {page.faq.map((item) => (
                  <article key={item.question} className="faq-item">
                    <h3>{item.question}</h3>
                    <p>{item.answer}</p>
                  </article>
                ))}
              </div>
            </section>

            <section className="seo-related">
              <p className="features-label">Related guides</p>
              <h2>More Ways to Use Quit All</h2>
              <div className="seo-related-grid">
                {relatedPages.map((relatedPage) => (
                  <Link
                    key={relatedPage.slug}
                    href={`/${relatedPage.slug}`}
                    className="seo-related-card"
                  >
                    <span>{relatedPage.eyebrow}</span>
                    <strong>{relatedPage.label}</strong>
                    <small>{relatedPage.metaDescription}</small>
                  </Link>
                ))}
              </div>
            </section>
          </div>
        </section>
      </main>

      <footer className="footer">
        <div className="container">
          <div className="footer-inner">
            <div className="footer-logo">
              <Image src="/logo.png" alt="Quit All" width={24} height={24} />
              <span>Quit All</span>
            </div>
            <div className="footer-links">
              <Link href="/">Home</Link>
              <Link href="/privacy">Privacy</Link>
              <Link href="/terms">Terms</Link>
              <Link href="mailto:ad13dtu@gmail.com">Contact</Link>
            </div>
            <p className="footer-copy">© 2026 Apoorv Darshan. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </>
  );
}
