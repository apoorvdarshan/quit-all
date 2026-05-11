const DEFAULT_KLIPY_API_BASE_URL = "https://api.klipy.com";
const DEFAULT_API_KEY_QUERY_PARAM = "key";
const UPSTREAM_TIMEOUT_MS = 12_000;

const blockedClientQueryParams = new Set([
  "api_key",
  "apikey",
  "apiKey",
  "client_key",
  "key",
]);

type KlipyRouteContext = {
  params: Promise<{
    path?: string[];
  }>;
};

export async function GET(request: Request, context: KlipyRouteContext) {
  return proxyKlipyRequest(request, context);
}

export async function POST(request: Request, context: KlipyRouteContext) {
  return proxyKlipyRequest(request, context);
}

export async function DELETE(request: Request, context: KlipyRouteContext) {
  return proxyKlipyRequest(request, context);
}

async function proxyKlipyRequest(request: Request, context: KlipyRouteContext) {
  const apiKey = process.env.KLIPY_API_KEY;
  if (!apiKey) {
    return jsonError("KLIPY_API_KEY is not configured.", 500);
  }

  const { path = [] } = await context.params;
  if (!isAllowedPath(path)) {
    return jsonError("Unsupported Klipy API path.", 400);
  }

  const upstreamUrl = buildUpstreamUrl(request.url, path, apiKey);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

  try {
    const upstreamResponse = await fetch(upstreamUrl, {
      method: request.method,
      headers: buildUpstreamHeaders(request),
      body: shouldForwardBody(request.method) ? await request.text() : undefined,
      cache: "no-store",
      signal: controller.signal,
    });

    return new Response(upstreamResponse.body, {
      status: upstreamResponse.status,
      headers: buildResponseHeaders(upstreamResponse),
    });
  } catch (error) {
    const message = error instanceof Error && error.name === "AbortError"
      ? "Klipy request timed out."
      : "Klipy request failed.";
    return jsonError(message, 502);
  } finally {
    clearTimeout(timeout);
  }
}

function buildUpstreamUrl(requestUrl: string, path: string[], apiKey: string) {
  const baseUrl = process.env.KLIPY_API_BASE_URL ?? DEFAULT_KLIPY_API_BASE_URL;
  const normalizedBaseUrl = baseUrl.replace(/\/+$/, "");
  const safePath = path.map((segment) => encodeURIComponent(segment)).join("/");
  const upstreamUrl = new URL(`${normalizedBaseUrl}/${safePath}`);
  const clientUrl = new URL(requestUrl);

  clientUrl.searchParams.forEach((value, key) => {
    if (!blockedClientQueryParams.has(key)) {
      upstreamUrl.searchParams.append(key, value);
    }
  });

  const keyQueryParam = process.env.KLIPY_API_KEY_PARAM ?? DEFAULT_API_KEY_QUERY_PARAM;
  upstreamUrl.searchParams.set(keyQueryParam, apiKey);

  return upstreamUrl;
}

function isAllowedPath(path: string[]) {
  if (path.length < 2) {
    return false;
  }

  if (path.some((segment) => segment === "." || segment === ".." || segment.includes("/"))) {
    return false;
  }

  // Tenor-compatible Klipy endpoints, e.g. /api/klipy/v2/search.
  if (path[0] === "v2") {
    return true;
  }

  // Native Klipy endpoints, e.g. /api/klipy/api/v1/gifs/search.
  if (path[0] === "api" && path[1] === "v1") {
    return true;
  }

  return false;
}

function buildUpstreamHeaders(request: Request) {
  const headers = new Headers();
  const accept = request.headers.get("accept");
  const contentType = request.headers.get("content-type");

  headers.set("user-agent", "QuitAllKlipyProxy/1.0");
  if (accept) {
    headers.set("accept", accept);
  }
  if (contentType && shouldForwardBody(request.method)) {
    headers.set("content-type", contentType);
  }

  return headers;
}

function buildResponseHeaders(upstreamResponse: Response) {
  const headers = new Headers();
  const contentType = upstreamResponse.headers.get("content-type");

  if (contentType) {
    headers.set("content-type", contentType);
  }
  headers.set("cache-control", "no-store");
  headers.set("x-quit-all-proxy", "klipy");

  return headers;
}

function shouldForwardBody(method: string) {
  return method !== "GET" && method !== "HEAD";
}

function jsonError(error: string, status: number) {
  return Response.json({ error }, { status });
}
