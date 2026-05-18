export function buildCorsOrigin() {
  const rawOrigins = process.env.CORS_ORIGINS?.trim();

  if (!rawOrigins) {
    return true;
  }

  const allowedOrigins = rawOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  return (origin: string | undefined, callback: (error: Error | null, allow?: boolean) => void) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error('Origem nao permitida pelo CORS.'), false);
  };
}
