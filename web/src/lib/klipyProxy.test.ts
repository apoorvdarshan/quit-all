// Generated-input (property-based fuzz) tests for the KLIPY proxy. Each
// property runs FUZZ_RUNS cases (default 1,000). A failure prints the seed and
// the shrunk counterexample; rerun it with FUZZ_SEED=<seed>.

import assert from "node:assert/strict";
import { test } from "node:test";
import fc from "fast-check";

import {
  blockedClientQueryParams,
  buildUpstreamUrl,
  isAllowedPath,
  proxyKlipyRequest,
} from "./klipyProxy.ts";

const numRuns = Number(process.env.FUZZ_RUNS ?? 1000);
const seed = process.env.FUZZ_SEED === undefined ? undefined : Number(process.env.FUZZ_SEED);
const params = { numRuns, seed };

const API_KEY = "server-secret-key";
const ALLOWED_RESPONSE_HEADERS = ["cache-control", "content-type", "x-quit-all-proxy"];
const ALLOWED_UPSTREAM_HEADERS = ["accept", "content-type", "user-agent"];

// Tokens that matter to URL parsing and to the allow-list, mixed with any text.
const trickySegment = fc.constantFrom(
  ".", "..", "v2", "api", "v1", "", " ", "/", "\\", "?", "#", "%", "&", "=",
  "%2e", "%2e%2e", "..%2f", "%2F", "..\\", ".%2e", "@evil.test", "//evil.test",
  "https://evil.test", "key=stolen", "\u0000", "∕", "．．",
);
const anySegment = fc.oneof(trickySegment, fc.string({ unit: "grapheme", maxLength: 24 }));
// Half the generated paths start with a supported (or near-supported) prefix so
// the traversal and slash checks after the prefix are exercised.
const anyPath = fc.oneof(
  fc.array(anySegment, { maxLength: 6 }),
  fc.tuple(fc.constantFrom(["v2"], ["api", "v1"], ["api"]), fc.array(anySegment, { maxLength: 5 }))
    .map(([prefix, rest]) => [...prefix, ...rest]),
);

// Paths that pass the allow-list: a supported prefix plus segments that are
// neither dot segments nor contain a slash.
const passingSegment = anySegment.filter(
  (segment) => segment !== "." && segment !== ".." && !segment.includes("/"),
);
const allowedPath = fc.oneof(
  fc.tuple(fc.constant(["v2"]), fc.array(passingSegment, { minLength: 1, maxLength: 5 })),
  fc.tuple(fc.constant(["api", "v1"]), fc.array(passingSegment, { maxLength: 5 })),
).map(([prefix, rest]) => [...prefix, ...rest]);

const queryName = fc.oneof(
  fc.constantFrom(...blockedClientQueryParams, "KEY", "Key", "key ", "token", "q", "limit"),
  fc.string({ unit: "grapheme", maxLength: 12 }),
);
const queryPairs = fc.array(
  fc.tuple(queryName, fc.string({ unit: "grapheme", maxLength: 24 })),
  { maxLength: 8 },
);

const baseUrl = fc.constantFrom(
  undefined,
  "https://api.klipy.com",
  "https://api.klipy.com/",
  "https://api.klipy.com///",
  "https://klipy.test/proxy/base/",
);
const keyQueryParam = fc.constantFrom(undefined, "key", "api_key", "token");

const headerName = fc.stringMatching(/^[a-z][a-z0-9-]{0,20}$/);
const headerValue = fc.stringMatching(/^[\x21-\x7e]{0,40}$/);
const headers = fc.array(fc.tuple(headerName, headerValue), { maxLength: 10 });

function clientUrl(path: string[], pairs: [string, string][]) {
  const url = new URL("https://quit-all.com/api/klipy");
  url.pathname += `/${path.map((segment) => encodeURIComponent(segment)).join("/")}`;
  for (const [name, value] of pairs) {
    url.searchParams.append(name, value);
  }
  return url.toString();
}

function expectedAllowed(path: string[]) {
  return path.length >= 2 &&
    path.every((segment) => segment !== "." && segment !== ".." && !segment.includes("/")) &&
    (path[0] === "v2" || (path[0] === "api" && path[1] === "v1"));
}

test("only supported, traversal-free paths are allowed", () => {
  fc.assert(
    fc.property(anyPath, (path) => {
      assert.equal(isAllowedPath(path), expectedAllowed(path));
    }),
    params,
  );
});

test("upstream URL stays on the KLIPY origin and keeps every path segment", () => {
  fc.assert(
    fc.property(allowedPath, queryPairs, baseUrl, keyQueryParam, (path, pairs, base, keyParam) => {
      const upstream = buildUpstreamUrl(clientUrl(path, pairs), path, API_KEY, {
        baseUrl: base,
        keyQueryParam: keyParam,
      });
      const expectedBase = new URL(base ?? "https://api.klipy.com");
      const basePath = expectedBase.pathname.replace(/\/+$/, "");

      assert.equal(upstream.origin, expectedBase.origin);
      assert.ok(upstream.pathname.startsWith(`${basePath}/`));
      const segments = upstream.pathname.slice(basePath.length + 1).split("/");
      assert.deepEqual(segments.map((segment) => decodeURIComponent(segment)), path);
      assert.equal(upstream.hash, "");
      assert.equal(upstream.username, "");
      assert.equal(upstream.password, "");
    }),
    params,
  );
});

test("the server key is sent exactly once and clients cannot supply or override a key", () => {
  fc.assert(
    fc.property(allowedPath, queryPairs, keyQueryParam, (path, pairs, keyParam) => {
      const requestUrl = clientUrl(path, pairs);
      const upstream = buildUpstreamUrl(requestUrl, path, API_KEY, { keyQueryParam: keyParam });
      const keyName = keyParam ?? "key";

      assert.deepEqual(upstream.searchParams.getAll(keyName), [API_KEY]);
      for (const blocked of blockedClientQueryParams) {
        if (blocked !== keyName) {
          assert.deepEqual(upstream.searchParams.getAll(blocked), []);
        }
      }

      // Every other client parameter is forwarded unchanged and in order.
      const forwarded = [...new URL(requestUrl).searchParams].filter(
        ([name]) => !blockedClientQueryParams.has(name) && name !== keyName,
      );
      const sent = [...upstream.searchParams].filter(([name]) => name !== keyName);
      assert.deepEqual(sent, forwarded);
    }),
    params,
  );
});

test("unsupported paths and a missing key never reach the upstream", async () => {
  await fc.assert(
    fc.asyncProperty(anyPath, fc.boolean(), async (path, hasKey) => {
      fc.pre(!hasKey || !isAllowedPath(path));
      let called = false;
      const response = await proxyKlipyRequest(new Request(clientUrl(path, [])), path, {
        apiKey: hasKey ? API_KEY : undefined,
        fetch: async () => {
          called = true;
          return new Response("unexpected");
        },
      });

      assert.equal(called, false);
      assert.equal(response.status, hasKey ? 400 : 500);
    }),
    params,
  );
});

test("client credentials are not forwarded and upstream headers do not leak back", async () => {
  await fc.assert(
    fc.asyncProperty(
      allowedPath,
      fc.constantFrom("GET", "POST", "DELETE"),
      headers,
      headers,
      fc.integer({ min: 200, max: 599 }),
      async (path, method, clientHeaders, upstreamHeaders, status) => {
        const request = new Request(clientUrl(path, []), {
          method,
          headers: [...clientHeaders, ["cookie", "session=1"], ["authorization", "Bearer x"]],
          body: method === "GET" ? undefined : "{}",
        });
        let sentHeaders = new Headers();
        const response = await proxyKlipyRequest(request, path, {
          apiKey: API_KEY,
          fetch: async (_url, init) => {
            sentHeaders = new Headers(init?.headers);
            return new Response(null, { status, headers: [...upstreamHeaders, ["set-cookie", "a=b"]] });
          },
        });

        for (const name of sentHeaders.keys()) {
          assert.ok(ALLOWED_UPSTREAM_HEADERS.includes(name), `forwarded request header ${name}`);
        }
        for (const name of response.headers.keys()) {
          assert.ok(ALLOWED_RESPONSE_HEADERS.includes(name), `leaked response header ${name}`);
        }
        assert.equal(response.headers.get("cache-control"), "no-store");
        assert.equal(response.status, status);
      },
    ),
    params,
  );
});
