# VetFinder API

Backend NestJS + TypeScript do VetFinder.

## Responsabilidades

- Autenticacao e papeis de usuario.
- Perfis profissionais e institucionais.
- Documentos e aprovacao administrativa.
- Agenda e disponibilidade.
- Vagas, candidaturas e convites.
- Fechamento de plantoes.
- Pagamento sandbox com preparacao para split.
- Avaliacoes.
- Notificacoes internas.

## Setup Local

Na raiz do repositorio:

```powershell
npm install
Copy-Item apps/api/.env.example apps/api/.env
```

Subir infraestrutura:

```powershell
cd apps/api
docker compose up -d
```

Preparar banco:

```powershell
cd C:\Users\Alisson\Desktop\projetos\Vetfinder
npm run prisma:generate --workspace apps/api
npm run prisma:push --workspace apps/api
npm run prisma:seed --workspace apps/api
```

Rodar:

```powershell
npm run dev:api
```

Build:

```powershell
npm run build:api
```

## Principais Rotas

Base local:

```text
http://localhost:3000/v1
```

Saude:

- `GET /health`

Auth:

- `POST /auth/register`
- `POST /auth/login`

Usuarios:

- `GET /users/me`

Profissionais:

- `POST /professionals/veterinarians`
- `POST /professionals/interns`
- `GET /professionals/:userId`

Instituicoes:

- `POST /institutions`
- `GET /institutions/me`
- `GET /institutions/:id`

Documentos:

- `POST /documents/upload`
- `GET /documents`
- `PATCH /documents/:id/review`

Vagas:

- `GET /opportunities`
- `GET /opportunities/me`
- `GET /opportunities/:id`
- `POST /opportunities`
- `PATCH /opportunities/:id`
- `PATCH /opportunities/:id/status`

Candidaturas e convites:

- `POST /applications/opportunities/:opportunityId/apply`
- `POST /applications/opportunities/:opportunityId/invite`
- `GET /applications/me`
- `GET /applications/invites/me`
- `POST /applications/:applicationId/respond`
- `POST /applications/invites/:inviteId/respond`

Contratacoes:

- `POST /engagements`
- `GET /engagements/me`
- `GET /engagements/professional/me`
- `GET /engagements/:id`

Pagamentos:

- `POST /payments`
- `GET /payments/:id`
- `GET /payments/engagement/:engagementId`
- `PATCH /payments/:id/confirm-sandbox`

Avaliacoes:

- `POST /reviews`
- `GET /reviews/engagement/:engagementId`

Notificacoes:

- `GET /notifications`
- `GET /notifications/unread-count`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/read-all`

## Observacoes

- O pagamento atual usa `sandbox-split`.
- Gateway real depende de definicao juridica/financeira.
- O storage local e suficiente para desenvolvimento; producao deve usar storage privado.
- O banco usa PostGIS, mas indices espaciais avancados devem ser revisados antes de escala.
