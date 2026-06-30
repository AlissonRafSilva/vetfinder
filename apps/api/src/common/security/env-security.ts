const unsafeSecrets = new Set([
  'change-me',
  'change-me-too',
  'changeme',
  'secret',
  'jwt-secret',
]);

export function assertSafeRuntimeConfig() {
  const nodeEnv = process.env.NODE_ENV ?? 'development';
  const isProduction = nodeEnv === 'production';

  const accessSecret = process.env.JWT_ACCESS_SECRET;
  const refreshSecret = process.env.JWT_REFRESH_SECRET;

  if (!accessSecret || !refreshSecret) {
    throw new Error(
      'JWT_ACCESS_SECRET e JWT_REFRESH_SECRET precisam estar configurados.',
    );
  }

  if (!isProduction) {
    return;
  }

  const normalizedAccessSecret = accessSecret.trim().toLowerCase();
  const normalizedRefreshSecret = refreshSecret.trim().toLowerCase();

  if (
    unsafeSecrets.has(normalizedAccessSecret) ||
    unsafeSecrets.has(normalizedRefreshSecret) ||
    accessSecret.length < 32 ||
    refreshSecret.length < 32
  ) {
    throw new Error(
      'Secrets JWT inseguros para produção. Use valores únicos com pelo menos 32 caracteres.',
    );
  }

  if (!process.env.CORS_ORIGINS?.trim()) {
    throw new Error('CORS_ORIGINS precisa estar definido em produção.');
  }

  if ((process.env.STORAGE_DRIVER ?? 'local').toLowerCase() === 's3') {
    const requiredS3Variables = [
      'STORAGE_BUCKET',
      'S3_ACCESS_KEY_ID',
      'S3_SECRET_ACCESS_KEY',
    ];
    const missingVariables = requiredS3Variables.filter(
      (name) => !process.env[name]?.trim(),
    );

    if (missingVariables.length > 0) {
      throw new Error(
        `Configuração S3 incompleta: ${missingVariables.join(', ')}.`,
      );
    }
  }
}
