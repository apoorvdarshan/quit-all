import assert from "node:assert/strict";
import { test } from "node:test";
import fc from "fast-check";

import { type Env, handleRequest, klipyPathSegments } from "./worker.ts";

function env(overrides: Partial<Env> = {}): Env {
  return {
    ASSETS: { fetch: async () => new Response("static asset", { status: 200 }) },
    ...overrides,
  };
}

const request = (path: string, init?: RequestInit) => new Request(`https://www.quit-all.com${path}`, init);

test("app config returns the RevenueCat key without caching", async () => {
  const fallback = await handleRequest(request("/api/app-config"), env());
  assert.equal(fallback.status, 200);
  assert.equal(fallback.headers.get("cache-control"), "no-store, max-age=0");
  assert.match(((await fallback.json()) as { revenueCatAPIKey: string }).revenueCatAPIKey, /^appl_/);

  const configured = await handleRequest(request("/api/app-config"), env({ REVENUECAT_IOS_API_KEY: "appl_rotated" }));
  assert.deepEqual(await configured.json(), { revenueCatAPIKey: "appl_rotated" });

  const post = await handleRequest(request("/api/app-config", { method: "POST" }), env());
  assert.equal(post.status, 405);
});

test("the KLIPY route decodes path segments and sends the server key upstream", async () => {
  let upstream = "";
  const original = globalThis.fetch;
  globalThis.fetch = async (input) => {
    upstream = String(input);
    return new Response("{}", { headers: { "content-type": "application/json", "set-cookie": "a=b" } });
  };
  try {
    const response = await handleRequest(
      request("/api/klipy/v2/search%20term?q=smoking&key=client"),
      env({ KLIPY_API_KEY: "server-key" }),
    );
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("set-cookie"), null);
    const url = new URL(upstream);
    assert.equal(url.origin, "https://api.klipy.com");
    assert.equal(url.pathname, "/v2/search%20term");
    assert.deepEqual(url.searchParams.getAll("key"), ["server-key"]);
    assert.equal(url.searchParams.get("q"), "smoking");
  } finally {
    globalThis.fetch = original;
  }
});

test("the KLIPY route rejects bad paths, methods and a missing key", async () => {
  assert.equal((await handleRequest(request("/api/klipy/v3/search"), env({ KLIPY_API_KEY: "k" }))).status, 400);
  assert.equal((await handleRequest(request("/api/klipy/v2/%E0%A4%A"), env({ KLIPY_API_KEY: "k" }))).status, 400);
  assert.equal((await handleRequest(request("/api/klipy/v2/search", { method: "PUT" }), env({ KLIPY_API_KEY: "k" }))).status, 405);
  assert.equal((await handleRequest(request("/api/klipy/v2/search"), env())).status, 500);
});

test("other /api paths are 404 and everything else goes to the static files", async () => {
  assert.equal((await handleRequest(request("/api/unknown"), env())).status, 404);
  const page = await handleRequest(request("/quit-smoking"), env());
  assert.equal(await page.text(), "static asset");
});

test("path segment decoding never throws and round-trips encoded segments", () => {
  fc.assert(
    fc.property(fc.array(fc.string({ unit: "grapheme", maxLength: 16 }).filter((s) => s !== ""), { maxLength: 6 }), (segments) => {
      const pathname = `/api/klipy/${segments.map(encodeURIComponent).join("/")}`;
      assert.deepEqual(klipyPathSegments(pathname), segments);
    }),
    { numRuns: Number(process.env.FUZZ_RUNS ?? 1000) },
  );
  fc.assert(
    fc.property(fc.string({ unit: "binary-ascii", maxLength: 40 }), (tail) => {
      const result = klipyPathSegments(`/api/klipy/${tail}`);
      assert.ok(result === null || Array.isArray(result));
    }),
    { numRuns: Number(process.env.FUZZ_RUNS ?? 1000) },
  );
});
