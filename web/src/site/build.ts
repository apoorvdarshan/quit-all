// Builds the static site into dist/: copies public/, renders every page to
// HTML and writes the sitemap. Fails if a page links to a file or anchor that
// does not exist, or is missing its title, description, canonical URL or h1.
//
//   node src/site/build.ts [out dir]

import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { guides } from "./content/guides.ts";
import { privacy, terms } from "./content/legal.ts";
import { SITE_URL } from "./content/site.ts";
import type { Assets } from "./layout.ts";
import { guidePage, homePage, legalPage, notFoundPage, sitemap } from "./pages.ts";

const WEB_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const PUBLIC_DIR = join(WEB_ROOT, "public");

function fingerprint(file: string) {
  return createHash("sha256").update(readFileSync(file)).digest("hex").slice(0, 10);
}

function assetUrl(path: string) {
  return `${path}?v=${fingerprint(join(PUBLIC_DIR, path))}`;
}

export function renderPages(assets: Assets) {
  const pages = new Map<string, string>();
  pages.set("index.html", homePage(assets));
  for (const guide of guides) {
    pages.set(`${guide.slug}.html`, guidePage(guide, assets));
  }
  pages.set("privacy.html", legalPage(privacy, assets));
  pages.set("terms.html", legalPage(terms, assets));
  pages.set("404.html", notFoundPage(assets));
  return pages;
}

export function buildSite(outDir: string, lastModified = new Date().toISOString().slice(0, 10)) {
  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });
  cpSync(PUBLIC_DIR, outDir, {
    recursive: true,
    filter: (source) => !source.endsWith(".DS_Store"),
  });

  const assets: Assets = {
    css: assetUrl("/assets/site.css"),
    js: { craving: assetUrl("/assets/craving.js") },
  };
  const pages = renderPages(assets);
  for (const [file, markup] of pages) {
    writeFileSync(join(outDir, file), markup);
  }
  writeFileSync(join(outDir, "sitemap.xml"), sitemap(lastModified));
  writeFileSync(join(outDir, "robots.txt"), `User-agent: *\nAllow: /\nSitemap: ${SITE_URL}/sitemap.xml\n`);
  return pages;
}

function listFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? listFiles(path) : [path];
  });
}

// The file the static asset server would answer a site path with
// (html_handling "auto-trailing-slash": /privacy -> privacy.html).
export function resolveSitePath(outDir: string, sitePath: string) {
  const clean = decodeURIComponent(sitePath.split(/[?#]/)[0] ?? "/");
  if (clean === "/") {
    return join(outDir, "index.html");
  }
  const base = join(outDir, clean);
  for (const candidate of [base, `${base}.html`, join(base, "index.html")]) {
    if (existsSync(candidate) && statSync(candidate).isFile()) {
      return candidate;
    }
  }
  return null;
}

function idsIn(markup: string) {
  return new Set([...markup.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]));
}

export function verifySite(outDir: string) {
  const problems: string[] = [];
  const htmlFiles = listFiles(outDir).filter((file) => file.endsWith(".html"));
  const ids = new Map(htmlFiles.map((file) => [file, idsIn(readFileSync(file, "utf8"))]));

  for (const file of htmlFiles) {
    const name = relative(outDir, file);
    const markup = readFileSync(file, "utf8");

    if (!/<title>[^<]+<\/title>/.test(markup)) problems.push(`${name}: missing <title>`);
    if (!/<meta name="description" content="[^"]+">/.test(markup)) problems.push(`${name}: missing meta description`);
    if (name !== "404.html" && !/<link rel="canonical" href="https:\/\/www\.quit-all\.com[^"]*">/.test(markup)) {
      problems.push(`${name}: missing canonical URL`);
    }
    const h1Count = (markup.match(/<h1[\s>]/g) ?? []).length;
    if (h1Count !== 1) problems.push(`${name}: has ${h1Count} <h1> elements`);

    for (const block of markup.matchAll(/<script type="application\/(?:ld\+)?json"[^>]*>([\s\S]*?)<\/script>/g)) {
      try {
        JSON.parse(block[1] ?? "");
      } catch {
        problems.push(`${name}: invalid JSON in a script block`);
      }
    }

    for (const match of markup.matchAll(/\s(?:href|src)="([^"]+)"/g)) {
      const target = match[1] ?? "";
      if (target.startsWith("#")) {
        if (target.length > 1 && !ids.get(file)?.has(target.slice(1))) problems.push(`${name}: no element with id ${target}`);
        continue;
      }
      if (!target.startsWith("/") || target.startsWith("//")) continue;
      const resolved = resolveSitePath(outDir, target);
      if (!resolved) {
        problems.push(`${name}: link to missing ${target}`);
        continue;
      }
      const hash = target.split("#")[1];
      if (hash && resolved.endsWith(".html") && !ids.get(resolved)?.has(hash)) {
        problems.push(`${name}: ${target} has no element with id ${hash}`);
      }
    }
  }
  return problems;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const outDir = resolve(process.argv[2] ?? join(WEB_ROOT, "dist"));
  const pages = buildSite(outDir);
  const problems = verifySite(outDir);
  if (problems.length > 0) {
    console.error(`Site check failed:\n  ${problems.join("\n  ")}`);
    process.exit(1);
  }
  console.log(`Built ${pages.size} pages into ${relative(process.cwd(), outDir) || "."}`);
}
