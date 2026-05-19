# VetFinder

VetFinder e um marketplace para conectar veterinarios volantes, estagiarios,
clinicas e hospitais veterinarios em demandas urgentes de plantao, cobertura,
estagio e trabalho temporario.

O produto resolve dois lados do problema:

- instituicoes encontram profissionais disponiveis com rapidez;
- profissionais encontram oportunidades compativeis com agenda, perfil e localizacao.

## Estado Atual

O projeto ja possui um MVP funcional com:

- login e cadastro por tipo de usuario;
- perfis de veterinario, estagiario, clinica, hospital e admin;
- upload e aprovacao de documentos;
- agenda/disponibilidade;
- publicacao e edicao de vagas;
- filtros por tipo, especialidade, distancia e perfil verificado;
- localizacao automatica no app;
- candidaturas e convites;
- fechamento de plantao;
- central interna de alertas;
- pagamento sandbox com preparacao para split;
- avaliacoes entre instituicao e profissional.

## Stack

- Mobile: Flutter
- Backend: NestJS + TypeScript
- Banco: PostgreSQL + PostGIS
- ORM: Prisma
- Cache/fila: Redis
- Infra local: Docker Compose

## Estrutura

```text
Vetfinder/
  apps/
    api/       Backend NestJS
    mobile/    Aplicativo Flutter
  docs/        Documentacao tecnica e produto
```

## Requisitos Locais

- Node.js
- npm
- Docker Desktop
- Flutter SDK
- Android SDK para build Android

## Setup Backend

Na raiz do projeto:

```powershell
npm install
```

Crie o `.env` da API:

```powershell
Copy-Item apps/api/.env.example apps/api/.env
```

Suba Postgres/PostGIS e Redis:

```powershell
cd apps/api
docker compose up -d
```

Volte para a raiz e prepare o Prisma:

```powershell
cd C:\Users\Alisson\Desktop\projetos\Vetfinder
npm run prisma:generate --workspace apps/api
npm run prisma:push --workspace apps/api
npm run prisma:seed --workspace apps/api
```

Rode a API:

```powershell
npm run dev:api
```

Health check:

```text
GET http://localhost:3000/v1/health
```

Resposta esperada:

```json
{"status":"ok","service":"vetfinder-api"}
```

## Setup Mobile

```powershell
cd apps/mobile
flutter pub get
flutter analyze
flutter run -d chrome
```

Para Android/iOS real, valide tambem:

```powershell
flutter doctor
```

## Contas Demo

Senha padrao:

```text
vetfinder123
```

Usuarios criados pelo seed:

- `admin.demo@vetfinder.app`
- `clinica.demo@vetfinder.app`
- `veterinario.demo@vetfinder.app`
- `estagiario.demo@vetfinder.app`

Contas de hospital podem ser criadas pelo cadastro do app e aprovadas no painel
admin.

## Mobile Com API Por Ambiente

Por padrao, o app usa:

- Web: `http://localhost:3000/v1`
- Android emulator: `http://10.0.2.2:3000/v1`
- iOS simulator/desktop: `http://localhost:3000/v1`

Para apontar para uma API online ou IP da rede local:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/v1
flutter run -d android --dart-define=API_BASE_URL=http://SEU_IP:3000/v1
flutter build apk --dart-define=API_BASE_URL=https://api.seudominio.com/v1
```

## Pagamentos

O projeto esta preparado com um provedor `sandbox-split`.

Esse modo:

- gera um checkout sandbox;
- mantem pagamento como aguardando confirmacao;
- simula confirmacao de pagamento;
- agenda split da plataforma e do profissional;
- prepara a troca futura por gateway real.

A escolha do gateway real ainda depende da decisao juridica/financeira da
instituicao responsavel pela operacao.

## Documentacao

- `docs/architecture.md`
- `docs/backend-modules.md`
- `docs/data-model.md`
- `docs/deploy.md`
- `docs/roadmap.md`

## Cuidados

- Nunca subir `apps/api/.env`.
- Nunca subir documentos reais de usuarios.
- Gateway de pagamento real exige contrato, KYC/KYB e validacao juridica.
- Antes de producao, revisar seguranca, CORS, logs, backups e LGPD.
