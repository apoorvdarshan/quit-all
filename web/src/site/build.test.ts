import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { after, before, test } from "node:test";
import { fileURLToPath } from "node:url";

import { buildSite, resolveSitePath, verifySite } from "./build.ts";
import { guides } from "./content/guides.ts";
import { cravingLines } from "./content/home.ts";
import { escapeHtml, html } from "./html.ts";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
let outDir = "";

before(() => {
  outDir = mkdtempSync(join(tmpdir(), "quit-all-site-"));
  buildSite(outDir, "2026-10-15");
});

after(() => {
  rmSync(outDir, { recursive: true, force: true });
});

const read = (file: string) => readFileSync(join(outDir, file), "utf8");

test("every page has metadata, one h1 and only working internal links", () => {
  assert.deepEqual(verifySite(outDir), []);
});

test("every habit guide is a page, in the sitemap and linked from the home page", () => {
  const home = read("index.html");
  const sitemap = read("sitemap.xml");
  assert.equal(guides.length, 9);
  for (const guide of guides) {
    assert.ok(resolveSitePath(outDir, `/${guide.slug}`), `${guide.slug} page`);
    assert.ok(home.includes(`href="/${guide.slug}"`), `${guide.slug} linked from home`);
    assert.ok(sitemap.includes(`<loc>https://www.quit-all.com/${guide.slug}</loc>`), `${guide.slug} in sitemap`);
    assert.ok(read(`${guide.slug}.html`).includes(`<link rel="canonical" href="https://www.quit-all.com/${guide.slug}">`));
  }
});

test("the 404 page is not indexed and robots.txt points at the sitemap", () => {
  assert.match(read("404.html"), /<meta name="robots" content="noindex, follow">/);
  assert.equal(read("robots.txt"), "User-agent: *\nAllow: /\nSitemap: https://www.quit-all.com/sitemap.xml\n");
});

test("pages link the app, the legal pages and the current social accounts", () => {
  const home = read("index.html");
  assert.ok(home.includes("https://apps.apple.com/us/app/quit-all-break-every-habit/id6760978934"));
  assert.ok(home.includes("https://www.instagram.com/apoorvcodes/"));
  assert.ok(!home.includes("quitall_com"));
  assert.ok(home.includes('href="/privacy"') && home.includes('href="/terms"'));
});

test("the craving lines are real lines from the app's meme library", () => {
  const library = readFileSync(join(REPO_ROOT, "ios/Quit All/Memes/MemeData.swift"), "utf8");
  for (const line of cravingLines) {
    assert.ok(library.includes(`"${line.text}"`), `not in MemeData.swift: ${line.text}`);
  }
});

test("the html helper escapes interpolated text", () => {
  assert.equal(html`<p>${'<script>"x" & \'y\''}</p>`.value, "<p>&lt;script&gt;&quot;x&quot; &amp; &#39;y&#39;</p>");
  assert.equal(escapeHtml("a&b"), "a&amp;b");
});
