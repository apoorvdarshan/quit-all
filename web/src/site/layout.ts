import { guideMap } from "./content/guides.ts";
import { habitOrder } from "./content/home.ts";
import {
  APP_NAME,
  APP_STORE_URL,
  CONTACT_EMAIL,
  LINKS,
  OG_IMAGE,
  SITE_NAME,
  SITE_URL,
  SOCIAL_HANDLES,
} from "./content/site.ts";
import { html, raw, type SafeHtml } from "./html.ts";

export type PageMeta = {
  path: string;
  title: string;
  description: string;
  keywords?: readonly string[];
  ogTitle?: string;
  ogDescription?: string;
  ogImageAlt?: string;
  twitterTitle?: string;
  twitterDescription?: string;
  structuredData?: SafeHtml[];
  scripts?: string[];
  noindex?: boolean;
};

export type Assets = {
  css: string;
  js: Record<string, string>;
};

export const appleIcon = raw(
  '<svg aria-hidden="true" width="17" height="17" viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/></svg>',
);

export function appStoreButton(label = "Download on the App Store", variant: "primary" | "quiet" = "primary") {
  return html`<a class="btn btn-${variant}" href="${APP_STORE_URL}">${appleIcon}<span>${label}</span></a>`;
}

function absolute(path: string) {
  return path === "/" ? SITE_URL : `${SITE_URL}${path}`;
}

function head(meta: PageMeta, assets: Assets) {
  const url = absolute(meta.path);
  const ogTitle = meta.ogTitle ?? meta.title;
  const ogDescription = meta.ogDescription ?? meta.description;
  return html`<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${meta.title}</title>
<meta name="description" content="${meta.description}">
${meta.keywords ? html`<meta name="keywords" content="${meta.keywords.join(", ")}">` : ""}
<meta name="author" content="Apoorv Darshan">
<meta name="robots" content="${meta.noindex ? "noindex, follow" : "index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1"}">
${meta.noindex ? "" : html`<link rel="canonical" href="${url}">`}
<meta name="theme-color" content="#16110c">
<meta name="color-scheme" content="dark">
<meta name="apple-itunes-app" content="app-id=6760978934">
<meta property="og:type" content="website">
<meta property="og:locale" content="en_US">
<meta property="og:site_name" content="${SITE_NAME}">
<meta property="og:url" content="${url}">
<meta property="og:title" content="${ogTitle}">
<meta property="og:description" content="${ogDescription}">
<meta property="og:image" content="${SITE_URL}${OG_IMAGE.path}">
<meta property="og:image:width" content="${OG_IMAGE.width}">
<meta property="og:image:height" content="${OG_IMAGE.height}">
<meta property="og:image:alt" content="${meta.ogImageAlt ?? APP_NAME}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:creator" content="${SOCIAL_HANDLES.x}">
<meta name="twitter:title" content="${meta.twitterTitle ?? ogTitle}">
<meta name="twitter:description" content="${meta.twitterDescription ?? ogDescription}">
<meta name="twitter:image" content="${SITE_URL}${OG_IMAGE.path}">
<link rel="icon" href="/favicon.ico" sizes="32x32">
<link rel="icon" href="/favicon.png" type="image/png" sizes="512x512">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="preload" href="/fonts/schibsted-grotesk.woff2" as="font" type="font/woff2" crossorigin>
<link rel="preload" href="/fonts/cormorant-garamond.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="${assets.css}">
${(meta.scripts ?? []).map((name) => html`<script type="module" src="${assets.js[name] ?? ""}"></script>`)}
${meta.structuredData ?? []}
</head>`;
}

function nav(onHome: boolean) {
  const base = onHome ? "" : "/";
  return html`<header class="site-header">
  <a class="skip-link" href="#main">Skip to content</a>
  <nav class="nav wrap" aria-label="Main">
    <a class="brand" href="/"${onHome ? raw(' aria-current="page"') : ""}>
      <img src="/logo.png" alt="" width="32" height="32">
      <span>Quit All</span>
    </a>
    <ul class="nav-links">
      <li><a href="${base}#habits">Habits</a></li>
      <li><a href="${base}#pricing">Pricing</a></li>
      <li><a href="${base}#faq">FAQ</a></li>
    </ul>
    ${appStoreButton("Get the app", "quiet")}
  </nav>
</header>`;
}

function footer() {
  const habitLinks = habitOrder.map((slug) => {
    const guide = guideMap.get(slug);
    return guide ? html`<li><a href="/${guide.slug}">${guide.label}</a></li>` : "";
  });
  return html`<footer class="site-footer">
  <div class="wrap footer-grid">
    <div class="footer-brand">
      <a class="brand" href="/"><img src="/logo.png" alt="" width="28" height="28"><span>Quit All</span></a>
      <p>One iPhone app for quitting nine habits. Open source under the MIT License, made by Apoorv Darshan.</p>
    </div>
    <nav aria-label="Habit guides">
      <h2>Guides</h2>
      <ul>${habitLinks}</ul>
    </nav>
    <nav aria-label="About Quit All">
      <h2>Quit All</h2>
      <ul>
        <li><a href="${APP_STORE_URL}">App Store</a></li>
        <li><a href="/privacy">Privacy Policy</a></li>
        <li><a href="/terms">Terms of Service</a></li>
        <li><a href="mailto:${CONTACT_EMAIL}">Contact</a></li>
        <li><a href="${LINKS.github}">Source code on GitHub</a></li>
        <li><a href="${LINKS.kofi}">Support on Ko-fi</a></li>
        <li><a href="${LINKS.productHunt}">Product Hunt</a></li>
        <li><a href="${LINKS.trustMrr}">TrustMRR</a></li>
      </ul>
    </nav>
    <nav aria-label="Social">
      <h2>Follow</h2>
      <ul>
        <li><a href="${LINKS.x}">X <span class="handle">${SOCIAL_HANDLES.x}</span></a></li>
        <li><a href="${LINKS.instagram}">Instagram <span class="handle">${SOCIAL_HANDLES.instagram}</span></a></li>
      </ul>
    </nav>
  </div>
  <p class="wrap footer-legal">© 2026 Apoorv Darshan. Quit All is not medical advice or a replacement for professional help.</p>
</footer>`;
}

export function page(meta: PageMeta, assets: Assets, body: SafeHtml, options: { home?: boolean } = {}) {
  return html`<!doctype html>
<html lang="en">
${head(meta, assets)}
<body>
${nav(options.home ?? false)}
<main id="main">
${body}
</main>
${footer()}
</body>
</html>
`.value;
}
