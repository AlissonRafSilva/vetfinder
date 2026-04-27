# VetFinder

Marketplace para conectar veterinarios, estagiarios, clinicas e hospitais em
fluxos de plantao, cobertura e contratacao temporaria.

## Estrutura

- `apps/mobile`: aplicativo Flutter
- `apps/api`: backend NestJS + Prisma
- `docs`: arquitetura, modelo de dados, modulos e roadmap

## Stack

- Flutter no mobile
- NestJS + TypeScript no backend
- PostgreSQL + PostGIS
- Redis para filas/cache
- Storage para documentos
- Gateway com split validado juridicamente

## Documentacao

- `docs/architecture.md`
- `docs/data-model.md`
- `docs/backend-modules.md`
- `docs/roadmap.md`

## Status Atual

- autenticacao real no backend e no app
- fluxos separados para profissionais e instituicoes
- publicacao, edicao e gestao de vagas
- busca de profissionais disponiveis
- candidaturas e convites
- fechamento de plantao
- acompanhamento em `Contratacoes`
