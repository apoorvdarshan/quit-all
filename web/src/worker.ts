// Cloudflare Worker for quit-all.com. Static pages and files are served from
// dist/ by Workers Static Assets; this script only runs for /api/* (see
// run_worker_first in wrangler.jsonc). The iOS app calls both routes:
//
//   /api/app-config   the RevenueCat public SDK key, rotatable without an app update
//   /api/klipy/...    the KLIPY GIF proxy that adds the server-side API key

import { proxyKlipyRequest } from "./lib/klipyProxy.ts";

// The public iOS SDK key the app ships with; REVENUECAT_IOS_API_KEY overrides it.
const DEFAULT_REVENUECAT_IOS_API_KEY = "appl_ubtsOyRubEENNaebBFqLgcfxYBx";
const KLIPY_PREFIX = "/api/klipy/";
const KLIPY_METHODS = new Set(["GET", "HEAD", "POST", "DELETE"]);

export type Env = {
  ASSETS: { fetch(request: Request): Promise<Response> };
  KLIPY_API_KEY?: string;
  KLIPY_API_BASE_URL?: string;
  KLIPY_API_KEY_PARAM?: string;
  REVENUECAT_IOS_API_KEY?: string;
};

function jsonError(error: string, status: number, headers: Record<string, string> = {}) {
  return Response.json({ error }, { status, headers: { "cache-control": "no-store", ...headers } });
}

function appConfig(request: Request, env: Env) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return jsonError("Method not allowed.", 405, { allow: "GET, HEAD" });
  }
  return Response.json(
    { revenueCatAPIKey: env.REVENUECAT_IOS_API_KEY || DEFAULT_REVENUECAT_IOS_API_KEY },
    { headers: { "cache-control": "no-store, max-age=0", "x-quit-all-config": "app" } },
  );
}

// Path segments after /api/klipy/, decoded once like a framework route
// parameter would be. Returns null for malformed percent-encoding.
export function klipyPathSegments(pathname: string) {
  try {
    return pathname
      .slice(KLIPY_PREFIX.length)
      .split("/")
      .filter((segment) => segment !== "")
      .map((segment) => decodeURIComponent(segment));
  } catch {
    return null;
  }
}

export async function handleRequest(request: Request, env: Env) {
  const { pathname } = new URL(request.url);

  if (pathname === "/api/app-config") {
    return appConfig(request, env);
  }

  if (pathname.startsWith(KLIPY_PREFIX)) {
    if (!KLIPY_METHODS.has(request.method)) {
      return jsonError("Method not allowed.", 405, { allow: [...KLIPY_METHODS].join(", ") });
    }
    const path = klipyPathSegments(pathname);
    if (!path) {
      return jsonError("Unsupported Klipy API path.", 400);
    }
    return proxyKlipyRequest(request, path, {
      apiKey: env.KLIPY_API_KEY,
      baseUrl: env.KLIPY_API_BASE_URL,
      keyQueryParam: env.KLIPY_API_KEY_PARAM,
    });
  }

  if (pathname === "/api" || pathname.startsWith("/api/")) {
    return jsonError("Not found.", 404);
  }

  return env.ASSETS.fetch(request);
}

export default {
  fetch: handleRequest,
};
