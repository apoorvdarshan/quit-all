const DEFAULT_REVENUECAT_IOS_API_KEY = "appl_ubtsOyRubEENNaebBFqLgcfxYBx";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const bundleId = requestUrl.searchParams.get("bundleId") ?? "";
  const isDebugBundle = bundleId.endsWith(".debug");
  const revenueCatAPIKey = isDebugBundle
    ? process.env.REVENUECAT_IOS_DEBUG_API_KEY
      ?? process.env.REVENUECAT_IOS_API_KEY
      ?? DEFAULT_REVENUECAT_IOS_API_KEY
    : process.env.REVENUECAT_IOS_API_KEY ?? DEFAULT_REVENUECAT_IOS_API_KEY;

  return Response.json(
    { revenueCatAPIKey },
    {
      headers: {
        "cache-control": "no-store, max-age=0",
        "x-quit-all-config": "app",
      },
    },
  );
}
