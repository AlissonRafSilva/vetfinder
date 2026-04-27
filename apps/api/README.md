# VetFinder API

Backend inicial em NestJS + TypeScript com Prisma para PostgreSQL/PostGIS.

## Objetivos desta base

- organizar o backend como monolito modular
- preparar a modelagem principal do marketplace
- permitir evolucao incremental por modulo

## Estrutura

```text
apps/api/
  prisma/
    schema.prisma
  src/
    main.ts
    app.module.ts
    modules/
```

## Passos sugeridos

1. Instalar dependencias com `npm install`.
2. Configurar `.env` a partir de `.env.example`.
3. Subir a infraestrutura local com `docker compose up -d`.
4. Rodar `npm run prisma:generate --workspace apps/api`.
5. Criar a primeira migration.
6. Rodar `npm run prisma:seed --workspace apps/api`.
7. Iniciar a API com `npm run dev:api`.

## Endpoints iniciais

- `GET /v1/health`
- `POST /v1/auth/register`
- `POST /v1/auth/login`
- `GET /v1/users/me`
- `GET /v1/users/:id`
- `POST /v1/professionals/veterinarians`
- `POST /v1/professionals/interns`
- `GET /v1/professionals/:userId`
- `POST /v1/institutions`
- `GET /v1/institutions/:id`
- `POST /v1/documents`
- `POST /v1/documents/prepare-upload`
- `GET /v1/documents`
- `GET /v1/documents/:id`
- `PATCH /v1/documents/:id/review`
- `POST /v1/applications/opportunities/:opportunityId/apply`
- `POST /v1/applications/opportunities/:opportunityId/invite`
- `GET /v1/applications/me`
- `GET /v1/applications/opportunities/:opportunityId`
- `POST /v1/applications/:applicationId/respond`
- `POST /v1/applications/invites/:inviteId/respond`
- `POST /v1/engagements`
- `GET /v1/engagements/:id`
- `POST /v1/payments`
- `GET /v1/payments/:id`
- `GET /v1/payments/engagement/:engagementId`
- `GET /v1/opportunities`
- `GET /v1/opportunities/:id`
- `POST /v1/opportunities`

## Observacoes

- o schema usa modelos preparados para geolocalizacao
- a integracao real com pagamentos deve ser escolhida antes da implementacao financeira detalhada
- a validacao de CRMV deve comecar com suporte administrativo
- autenticacao agora usa hash, JWT e guards basicos, mas ainda sem refresh persistence e revogacao
- algumas rotas principais ja usam JWT bearer token com restricao por papel
- geolocalizacao no Prisma ainda exigira migrations SQL complementares para indices espaciais mais ricos
- o modulo de documentos registra metadados e revisao, e o preparo de upload hoje gera apenas placeholders de storage
- o modulo de pagamentos ainda esta em modo MVP, sem gateway real e sem webhook
