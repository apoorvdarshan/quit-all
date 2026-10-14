import { proxyKlipyRequest } from "@/lib/klipyProxy";

type KlipyRouteContext = {
  params: Promise<{
    path?: string[];
  }>;
};

export async function GET(request: Request, context: KlipyRouteContext) {
  return handle(request, context);
}

export async function POST(request: Request, context: KlipyRouteContext) {
  return handle(request, context);
}

export async function DELETE(request: Request, context: KlipyRouteContext) {
  return handle(request, context);
}

async function handle(request: Request, context: KlipyRouteContext) {
  const { path = [] } = await context.params;
  return proxyKlipyRequest(request, path, {
    apiKey: process.env.KLIPY_API_KEY,
    baseUrl: process.env.KLIPY_API_BASE_URL,
    keyQueryParam: process.env.KLIPY_API_KEY_PARAM,
  });
}
