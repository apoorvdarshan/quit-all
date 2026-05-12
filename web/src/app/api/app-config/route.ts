const DEFAULT_REVENUECAT_IOS_API_KEY = "appl_ubtsOyRubEENNaebBFqLgcfxYBx";

export const dynamic = "force-dynamic";

export async function GET() {
  const revenueCatAPIKey =
    process.env.REVENUECAT_IOS_API_KEY ?? DEFAULT_REVENUECAT_IOS_API_KEY;

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
