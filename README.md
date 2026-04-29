# VetFinder

VetFinder e um marketplace para conectar veterinarios volantes, estagiarios,
clinicas e hospitais veterinarios em fluxos de plantao, cobertura, contratacao
temporaria e demandas urgentes.

O objetivo do produto e reduzir o tempo entre a necessidade de uma instituicao
e a confirmacao de um profissional disponivel, com apoio de agenda,
geolocalizacao, validacao cadastral e fluxo financeiro centralizado.

## Visao Geral

O projeto esta organizado como um monorepo com duas aplicacoes principais:

- `apps/mobile`: aplicativo Flutter
- `apps/api`: backend NestJS + Prisma

Tambem existe uma pasta de apoio com documentacao funcional e tecnica:

- `docs`: arquitetura, modelo de dados, modulos e roadmap

## Principais Fluxos Ja Implementados

- autenticacao real no backend e no app
- navegacao separada para profissionais e instituicoes
- criacao, edicao e publicacao de vagas
- busca de profissionais disponiveis por agenda
- candidatura em oportunidades
- convite direto de profissionais para vagas
- resposta de convites e candidaturas
- fechamento de plantao
- acompanhamento institucional em `Contratacoes`

## Stack Tecnologica

- Flutter
- NestJS
- TypeScript
- Prisma ORM
- PostgreSQL + PostGIS
- Redis
- Docker

## Estrutura do Repositorio

```text
Vetfinder/
  apps/
    api/
    mobile/
  docs/
  package.json
  README.md
```

## Como Executar

### 1. Backend

Na raiz do projeto:

```bash
npm install
docker compose up -d --workspace apps/api
npm run prisma:generate --workspace apps/api
npm run prisma:push --workspace apps/api
npm run dev:api
```

Healthcheck esperado:

```bash
GET http://localhost:3000/v1/health
```

### 2. Mobile

Na pasta do app:

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter run -d chrome
```

## Contas Demo

- `clinica.demo@vetfinder.app` / `vetfinder123`
- `veterinario.demo@vetfinder.app` / `vetfinder123`

## Documentacao Complementar

- `docs/architecture.md`
- `docs/data-model.md`
- `docs/backend-modules.md`
- `docs/roadmap.md`
- `apps/api/README.md`
- `apps/mobile/README.md`

## Observacoes

- o arquivo `apps/api/.env` nao deve ser versionado
- a integracao real de pagamentos ainda depende da decisao do gateway
- o fluxo documental e financeiro ainda esta em evolucao de MVP

## Status do Projeto

O VetFinder ja possui base funcional suficiente para demonstracao do fluxo
principal do marketplace, com especial foco no lado institucional:

- publicacao e gestao de vagas
- interacao com profissionais
- aceite e fechamento de plantao
- acompanhamento de contratacoes

Os proximos passos naturais sao:

- visao do profissional apos o fechamento do plantao
- fluxo de pagamentos
- onboarding e validacao documental no app
