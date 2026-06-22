# Deploy online do VetFinder

Este guia usa o banco Neon ja configurado e sobe apenas a API NestJS.

## 1. Banco online

O banco Neon ja recebeu:

- schema Prisma
- extensao PostGIS
- seed demo

Nao salve a `DATABASE_URL` real em arquivos versionados.

## 2. Render

1. Acesse Render e crie um novo `Blueprint`.
2. Conecte o repositorio `AlissonRafSilva/vetfinder`.
3. O Render deve detectar o arquivo `render.yaml`.
4. Configure as variaveis secretas:

```text
DATABASE_URL=sua_connection_string_do_neon
JWT_ACCESS_SECRET=um_valor_forte_com_32_ou_mais_caracteres
JWT_REFRESH_SECRET=outro_valor_forte_com_32_ou_mais_caracteres
CORS_ORIGINS=https://sua-api-ou-front-autorizado
```

Para teste mobile sem front web hospedado, `CORS_ORIGINS` pode ser a URL do
proprio Render e/ou a origem web usada no teste. Apps mobile nativos nao usam
CORS como navegador.

## 3. Health check

Depois do deploy, teste:

```text
https://sua-api.onrender.com/v1/health
```

Resposta esperada:

```json
{
  "status": "ok",
  "service": "vetfinder-api"
}
```

## 4. App Flutter

Use a URL publica da API:

```powershell
flutter run -d chrome --dart-define=VETFINDER_API_BASE_URL=https://sua-api.onrender.com/v1
```

Para APK:

```powershell
flutter build apk --release --dart-define=VETFINDER_API_BASE_URL=https://sua-api.onrender.com/v1
```

## 5. Observacoes importantes

- O storage local em Render e temporario. Para documentos reais, migrar para
  Supabase Storage, S3 ou Cloudflare R2.
- Antes de producao real, rotacione a senha do Neon compartilhada durante os
  testes.
- O Asaas deve ser integrado somente depois que a API tiver URL publica estavel,
  porque webhooks precisam chamar a API online.
