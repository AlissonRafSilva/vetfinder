# VetFinder - Roadmap Inicial de Implementacao

## 1. Objetivo

Transformar a visao do VetFinder em um MVP lancavel, com base na stack:

- Flutter no mobile
- NestJS + TypeScript no backend
- PostgreSQL + PostGIS
- Redis para filas e cache
- storage para documentos
- gateway com split validado juridicamente

## 2. Fase 1 - Fundacao Tecnica

Objetivo: deixar a base pronta para desenvolvimento consistente.

Entregas:
- definicao da arquitetura
- definicao do modelo de dados
- setup inicial do backend NestJS
- setup inicial do app Flutter
- padrao de ambientes
- observabilidade minima
- pipeline de deploy basico

## 3. Fase 2 - Cadastro e Validacao

Objetivo: permitir entrada segura e controlada dos usuarios.

Entregas:
- cadastro por perfil
- login e recuperacao de senha
- perfis de veterinario, estagiario e instituicao
- upload de foto e documentos
- fila de analise documental
- aprovacao/reprovacao pelo admin

## 4. Fase 3 - Oferta e Busca

Objetivo: habilitar o nucleo do marketplace.

Entregas:
- cadastro de agenda/disponibilidade
- publicacao de oportunidades
- listagem de vagas proximas
- busca de profissionais por proximidade
- filtros por especialidade, valor e disponibilidade

## 5. Fase 4 - Contratacao

Objetivo: fechar plantao dentro da plataforma.

Entregas:
- candidaturas
- convites
- aceite/recusa
- fechamento de oportunidade
- status operacional do plantao

## 6. Fase 5 - Financeiro

Objetivo: capturar receita e profissionalizar a operacao.

Entregas:
- integracao com gateway
- calculo de taxa da plataforma
- split/repasse conforme modelo juridico validado
- historico financeiro
- monitoramento de falhas e conciliacao basica

## 7. Fase 6 - Qualidade Operacional

Objetivo: consolidar confianca e retencao.

Entregas:
- notificacoes push
- lembretes de plantao
- avaliacoes bilaterais
- dashboard admin com metricas
- logs e auditoria

## 8. Ordem Recomendada de Implementacao Tecnica

1. Arquitetura, banco e padroes
2. Auth e usuarios
3. Documentos e admin
4. Perfis profissionais e instituicoes
5. Agenda
6. Oportunidades
7. Busca geoespacial
8. Candidaturas e convites
9. Engagements
10. Pagamentos
11. Notificacoes
12. Avaliacoes

## 9. Criticos para Validar Antes de Codar Fundo

- fornecedor de pagamento com split aderente ao modelo
- politica juridica de repasse e estorno
- operacao de validacao de CRMV
- estrategia de lancamento por cidade/regiao

## 10. Definicao de MVP Comercializavel

O MVP esta pronto para piloto quando houver:

- cadastro completo dos 4 perfis
- validacao documental operacional
- busca por proximidade
- publicacao e fechamento de vaga
- pagamento funcional
- painel admin minimo

## 11. Proximos Passos Recomendados

1. Criar o monorepo inicial com app Flutter e API NestJS.
2. Escolher ORM e padrao de migrations.
3. Definir gateway prioritario de pagamento.
4. Desenhar o fluxo detalhado de onboarding e validacao.
5. Implementar o primeiro conjunto de entidades e modulos.
