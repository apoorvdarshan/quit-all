import { type Guide, guideMap, guides } from "./content/guides.ts";
import { cravingLines, faqs, features, habitOrder, plans, screens } from "./content/home.ts";
import type { LegalDocument } from "./content/legal.ts";
import {
  APP_NAME,
  APP_STORE_URL,
  CONTACT_EMAIL,
  LINKS,
  PRICES,
  SITE_URL,
} from "./content/site.ts";
import { escapeHtml, html, jsonData, jsonLd, raw } from "./html.ts";
import { type Assets, appStoreButton, page } from "./layout.ts";

const milestones = ["1 hour", "24 hours", "3 days", "1 week", "2 weeks", "30 days", "100 days", "6 months", "1 year"];

const warningIcon = raw(
  '<svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.5c.6 0 1.1.3 1.4.8l9.2 16c.6 1-.1 2.2-1.3 2.2H2.7c-1.2 0-1.9-1.2-1.3-2.2l9.2-16c.3-.5.8-.8 1.4-.8Zm0 6.2c-.7 0-1.2.6-1.1 1.3l.4 4.6c0 .4.3.7.7.7s.7-.3.7-.7l.4-4.6c.1-.7-.4-1.3-1.1-1.3Zm0 7.6a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4Z"/></svg>',
);

function faqList(items: readonly { q: string; a: string }[]) {
  return html`<div class="faq-list">${items.map(
    (item) => html`<details><summary>${item.q}</summary><p>${item.a}</p></details>`,
  )}</div>`;
}

function faqJsonLd(items: readonly { q: string; a: string }[]) {
  return jsonLd({
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map((item) => ({
      "@type": "Question",
      name: item.q,
      acceptedAnswer: { "@type": "Answer", text: item.a },
    })),
  });
}

function habitLinks(slugs: readonly string[], className = "habit-list") {
  const items = slugs
    .map((slug) => guideMap.get(slug))
    .filter((guide): guide is Guide => Boolean(guide))
    .map(
      (guide) => html`<li><a href="/${guide.slug}"><span class="habit-name">${guide.habit}</span><span class="habit-summary">${guide.summary}</span></a></li>`,
    );
  return html`<ul class="${className}">${items}</ul>`;
}

export function homePage(assets: Assets) {
  const first = cravingLines[0];
  const body = html`
<section class="hero wrap" aria-labelledby="hero-title">
  <div class="hero-copy">
    <h1 id="hero-title">Quit all of it.</h1>
    <p class="lede">Smoking, vaping, drinking, weed, porn, gambling, scrolling, overspending and caffeine. Quit All counts every streak in one iPhone app and gets you through the minutes when you’d usually give in.</p>
    <div class="hero-actions">
      ${appStoreButton()}
      <p class="fine">Free to download. Premium starts with a 7-day free trial when eligible.</p>
    </div>
  </div>
  <section class="craving" aria-labelledby="craving-title" data-craving>
    <h2 id="craving-title">Try the craving button</h2>
    <p class="craving-intro">In the app it starts a five-minute SOS timer with GIFs and offline video loops. Here it shows real lines from the app.</p>
    <div class="dial">
      <svg class="ring" viewBox="0 0 120 120" aria-hidden="true">
        <circle class="ring-track" cx="60" cy="60" r="54"/>
        <circle class="ring-fill" cx="60" cy="60" r="54" pathLength="100" data-ring/>
      </svg>
      <p class="dial-text"><span class="dial-label" data-label>Hold on</span><span class="dial-time" data-time>5:00</span></p>
    </div>
    <figure class="craving-line" aria-live="polite">
      <blockquote><p data-line>${first.text}</p></blockquote>
      <figcaption><span class="kind" data-kind>${first.kind}</span><span class="for" data-habit>${first.habit}</span></figcaption>
    </figure>
    <div class="craving-actions" data-controls hidden>
      <button type="button" class="btn btn-craving" data-start>${warningIcon}<span data-start-label>I’m craving</span></button>
      <button type="button" class="btn-text" data-stop hidden>Stop</button>
    </div>
    ${jsonData("craving-lines", cravingLines)}
  </section>
</section>

<section class="band" id="habits" aria-labelledby="habits-title">
  <div class="wrap">
    <div class="section-head">
      <h2 id="habits-title">Nine habits, one count each</h2>
      <p>Track one habit or all nine. Each keeps its own streak, savings and craving history. Pick one to see how Quit All handles it.</p>
    </div>
    ${habitLinks(habitOrder)}
  </div>
</section>

<section class="screens" aria-labelledby="screens-title">
  <div class="wrap">
    <div class="section-head"><h2 id="screens-title">What it looks like</h2></div>
  </div>
  <ul class="screen-strip">${screens.map(
    (screen) => html`<li><figure><img src="${screen.src}" alt="${screen.alt}" width="520" height="1127" loading="lazy" decoding="async"><figcaption>${screen.caption}</figcaption></figure></li>`,
  )}</ul>
</section>

<section class="wrap features" aria-labelledby="features-title">
  <div class="section-head">
    <h2 id="features-title">Also in the app</h2>
  </div>
  <dl class="feature-list">${features.map((feature) => html`<div><dt>${feature.title}</dt><dd>${feature.body}</dd></div>`)}</dl>
  <div class="milestones">
    <h3>The milestones</h3>
    <ol class="milestone-track">${milestones.map((label) => html`<li>${label}</li>`)}</ol>
  </div>
</section>

<section class="band" id="pricing" aria-labelledby="pricing-title">
  <div class="wrap">
    <div class="section-head">
      <h2 id="pricing-title">Pricing</h2>
      <p>Free to download. Premium unlocks everything. Prices are in US dollars, and the App Store shows yours in local currency.</p>
    </div>
    <ul class="plans">${plans.map(
      (plan) => html`<li class="plan${plan.best ? " plan-best" : ""}">
        <h3>${plan.name}${plan.best ? html` <span class="plan-tag">Best value</span>` : ""}</h3>
        <p class="price"><span class="amount">$${plan.price}</span> <span class="period">${plan.period}</span></p>
        <p class="plan-note">${plan.note}</p>
      </li>`,
    )}</ul>
    <p class="plans-action">${appStoreButton()}</p>
  </div>
</section>

<section class="wrap faq" id="faq" aria-labelledby="faq-title">
  <div class="section-head"><h2 id="faq-title">Questions</h2></div>
  ${faqList(faqs)}
</section>

<section class="wrap closing" aria-labelledby="closing-title">
  <h2 id="closing-title">Start the count today.</h2>
  <p>Your first milestone is an hour away.</p>
  ${appStoreButton()}
</section>`;

  const appJsonLd = jsonLd({
    "@context": "https://schema.org",
    "@type": "MobileApplication",
    name: APP_NAME,
    alternateName: ["Quit All Addiction Tracker", "AllQuit", "Quit All App"],
    url: SITE_URL,
    downloadUrl: APP_STORE_URL,
    image: `${SITE_URL}/og.png`,
    operatingSystem: "iOS 17+",
    applicationCategory: "HealthApplication",
    applicationSubCategory: "Addiction Recovery",
    inLanguage: "en",
    description:
      "App to quit smoking, stop vaping, quit drinking alcohol, quit weed, stop gambling, quit caffeine, and break social media addiction. Track sobriety streaks, survive cravings with GIFs and offline fallback loops, see money saved, use widgets, and get pattern-based reminders. 7-day free trial available on weekly and yearly premium when eligible.",
    sameAs: [APP_STORE_URL, LINKS.productHunt, LINKS.instagram, LINKS.x, LINKS.trustMrr],
    offers: [
      { "@type": "Offer", price: PRICES.weekly, priceCurrency: "USD", description: "Weekly premium subscription with 7-day free trial when eligible" },
      { "@type": "Offer", price: PRICES.yearly, priceCurrency: "USD", description: "Yearly premium subscription with 7-day free trial when eligible" },
      { "@type": "Offer", price: PRICES.lifetime, priceCurrency: "USD", description: "Lifetime premium one-time purchase" },
    ],
    author: { "@type": "Person", name: "Apoorv Darshan" },
  });

  const entityJsonLd = jsonLd({
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": `${SITE_URL}/#organization`,
        name: "Quit All",
        alternateName: ["AllQuit", "Quit All App", "Quitall"],
        url: SITE_URL,
        logo: { "@type": "ImageObject", url: `${SITE_URL}/logo.png` },
        sameAs: [APP_STORE_URL, LINKS.instagram, LINKS.x, LINKS.productHunt],
      },
      {
        "@type": "WebSite",
        "@id": `${SITE_URL}/#website`,
        name: "Quit All",
        alternateName: ["AllQuit", "Quitall", "All Quit"],
        url: SITE_URL,
        inLanguage: "en",
        publisher: { "@id": `${SITE_URL}/#organization` },
      },
    ],
  });

  return page(
    {
      path: "/",
      title: "Quit All — Quit Smoking, Vaping, Alcohol & More in One App",
      description:
        "Quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings with GIFs and offline fallback loops, save money, and use Home Screen or Lock Screen widgets.",
      keywords: [
        "quit smoking app", "stop vaping", "quit drinking", "sobriety app", "sober counter",
        "addiction tracker", "habit tracker", "quit weed", "stop gambling", "quit caffeine",
        "quit porn", "digital detox", "craving help", "streak tracker", "money saved quitting",
        "relapse tracker", "quit all app", "allquit",
      ],
      ogTitle: "Quit All - One App to Quit Smoking, Vaping, Alcohol & More",
      ogDescription:
        "One app to quit smoking, vaping, alcohol, porn, social media, weed, gambling, overspending, and caffeine. Track streaks, survive cravings with GIFs, save money, and use widgets.",
      ogImageAlt: "Quit All - Break Every Habit",
      twitterTitle: "Quit All — Quit Every Addiction in One App",
      twitterDescription:
        "Quit smoking, vaping, alcohol & 6 more addictions. Track streaks, survive cravings with GIFs and offline fallback loops, save money.",
      structuredData: [appJsonLd, entityJsonLd, faqJsonLd(faqs)],
      scripts: ["craving"],
    },
    assets,
    body,
    { home: true },
  );
}

export function guidePage(guide: Guide, assets: Assets) {
  const faq = guide.faq.map((item) => ({ q: item.question, a: item.answer }));
  const body = html`
<article class="wrap guide">
  <nav class="crumbs" aria-label="Breadcrumb">
    <ol><li><a href="/">Quit All</a></li><li aria-current="page">${guide.label}</li></ol>
  </nav>
  <header class="guide-head">
    <div>
      <h1>${guide.title}</h1>
      <p class="lede">${guide.intro}</p>
      <div class="hero-actions">
        ${appStoreButton()}
        <a class="btn-text" href="/#habits">See all nine habits</a>
      </div>
    </div>
    <figure class="guide-shot"><img src="/ss-home.jpg" alt="Quit All home screen with a streak counter" width="520" height="1127"></figure>
  </header>
  <section class="guide-points" aria-labelledby="points-title">
    <h2 id="points-title">What Quit All helps you do</h2>
    <ul class="checks">${guide.bullets.map((bullet) => html`<li>${bullet}</li>`)}</ul>
  </section>
  <div class="guide-sections">${guide.sections.map(
    (section) => html`<section><h2>${section.title}</h2><p>${section.body}</p></section>`,
  )}</div>
  <section class="faq" aria-labelledby="guide-faq-title">
    <h2 id="guide-faq-title">Common questions</h2>
    ${faqList(faq)}
  </section>
  <section class="related" aria-labelledby="related-title">
    <h2 id="related-title">Related habits</h2>
    ${habitLinks(guide.related, "habit-list habit-list-compact")}
  </section>
</article>`;

  const breadcrumb = jsonLd({
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Quit All", item: SITE_URL },
      { "@type": "ListItem", position: 2, name: guide.label, item: `${SITE_URL}/${guide.slug}` },
    ],
  });

  return page(
    {
      path: `/${guide.slug}`,
      title: guide.metaTitle,
      description: guide.metaDescription,
      keywords: guide.keywords,
      ogImageAlt: `${guide.label} with Quit All`,
      structuredData: [breadcrumb, faqJsonLd(faq)],
    },
    assets,
    body,
  );
}

// Escapes the text, then turns **x** into <strong>x</strong>.
function emphasis(text: string) {
  return raw(escapeHtml(text).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>"));
}

function legalItem(item: string) {
  const split = item.indexOf(" — ");
  if (split === -1) {
    return html`<li>${emphasis(item)}</li>`;
  }
  return html`<li><strong>${item.slice(0, split)}</strong>${emphasis(item.slice(split))}</li>`;
}

export function legalPage(doc: LegalDocument, assets: Assets) {
  const body = html`
<article class="wrap legal">
  <header>
    <h1>${doc.title}</h1>
    <p class="updated">Last updated: ${doc.updated}</p>
  </header>
  ${doc.sections.map(
    (section) => html`<section>
    <h2>${section.title}</h2>
    ${(section.paragraphs ?? []).map((paragraph) => html`<p>${emphasis(paragraph)}</p>`)}
    ${section.items ? html`<ul>${section.items.map(legalItem)}</ul>` : ""}
  </section>`,
  )}
  <section>
    <h2>Contact</h2>
    <p>${doc.contactLead} <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></p>
  </section>
</article>`;

  return page(
    { path: `/${doc.slug}`, title: doc.metaTitle, description: doc.metaDescription },
    assets,
    body,
  );
}

export function notFoundPage(assets: Assets) {
  const body = html`
<section class="wrap not-found" aria-labelledby="nf-title">
  <h1 id="nf-title">There’s no page here.</h1>
  <p class="lede">The link may be old or mistyped. Start from the home page or pick a habit.</p>
  <p><a class="btn btn-quiet" href="/">Go to the home page</a></p>
  ${habitLinks(habitOrder, "habit-list habit-list-compact")}
</section>`;

  return page(
    {
      path: "/404",
      title: "Page not found — Quit All",
      description: "This page doesn't exist. Find the Quit All app and its habit guides from the home page.",
      noindex: true,
    },
    assets,
    body,
  );
}

export function sitemap(lastModified: string) {
  const urls = [
    { loc: SITE_URL, priority: "1.0", changefreq: "weekly" },
    ...guides.map((guide) => ({ loc: `${SITE_URL}/${guide.slug}`, priority: "0.85", changefreq: "monthly" })),
    { loc: `${SITE_URL}/privacy`, priority: "0.5", changefreq: "monthly" },
    { loc: `${SITE_URL}/terms`, priority: "0.5", changefreq: "monthly" },
  ];
  const entries = urls
    .map(
      (url) =>
        `  <url>\n    <loc>${url.loc}</loc>\n    <lastmod>${lastModified}</lastmod>\n    <changefreq>${url.changefreq}</changefreq>\n    <priority>${url.priority}</priority>\n  </url>`,
    )
    .join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${entries}\n</urlset>\n`;
}
