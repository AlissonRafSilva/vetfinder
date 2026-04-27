# VetFinder - Modulos do Backend NestJS

## 1. Visao

O backend sera estruturado como um monolito modular em NestJS + TypeScript, com separacao por dominio de negocio.

## 2. Modulos Iniciais

### auth
Responsabilidades:
- cadastro
- login
- refresh token
- recuperacao de senha
- validacao de sessao

### users
Responsabilidades:
- dados base da conta
- perfis comuns
- controle de visibilidade
- configuracoes de conta

### professionals
Responsabilidades:
- perfil de veterinario
- perfil de estagiario
- especialidades
- preferencias
- raio de atendimento

### institutions
Responsabilidades:
- perfil da clinica/hospital
- tipo de instituicao
- dados operacionais
- historico institucional

### documents
Responsabilidades:
- upload de arquivos
- controle de status documental
- aprovacao/reprovacao
- trilha de revisao

### availability
Responsabilidades:
- agenda semanal
- disponibilidade pontual
- bloqueios de horario
- validacao de conflito basica

### opportunities
Responsabilidades:
- criacao e publicacao de vagas
- edicao e cancelamento
- filtros de listagem
- detalhamento da oportunidade

### matching
Responsabilidades:
- busca por proximidade
- filtros por especialidade
- filtros por agenda
- elegibilidade por tipo de perfil

### applications
Responsabilidades:
- candidaturas
- convites
- aceite e recusa
- expiracao de interacoes

### engagements
Responsabilidades:
- fechamento da vaga
- vinculo entre instituicao e profissional
- status operacional do plantao
- cancelamentos e conclusao

### payments
Responsabilidades:
- calculo de valores
- integracao com gateway
- registro de pagamento
- split e repasse
- historico financeiro

### reviews
Responsabilidades:
- avaliacao bilateral
- consolidacao de reputacao
- moderacao basica

### notifications
Responsabilidades:
- notificacoes push
- notificacoes in-app
- eventos de aceite, convite, pagamento e lembretes

### admin
Responsabilidades:
- painel operacional
- aprovacao documental
- gestao de usuarios e instituicoes
- monitoramento de pagamentos e disputas

### audit
Responsabilidades:
- trilha de auditoria
- registro de acoes administrativas
- registro de eventos sensiveis

## 3. Fronteiras de Dominio

Separacoes importantes:

- `applications` trata intencao/interacao
- `engagements` trata contratacao fechada
- `payments` trata dinheiro e gateway
- `documents` trata compliance e validacao

Essas fronteiras evitam acoplamento excessivo e ajudam na evolucao futura.

## 4. Estrutura Sugerida de Pastas

```text
src/
  app.module.ts
  common/
  config/
  database/
  modules/
    auth/
    users/
    professionals/
    institutions/
    documents/
    availability/
    opportunities/
    matching/
    applications/
    engagements/
    payments/
    reviews/
    notifications/
    admin/
    audit/
```

## 5. Adaptadores Externos

Sugestao de providers/ports:

- storage provider
- payment provider
- push notification provider
- geocoding provider

Esses adaptadores devem ficar desacoplados do dominio para facilitar troca de fornecedor.

## 6. Jobs Assincronos com Redis

Jobs sugeridos:

- processar notificacoes
- revisar fila de documentos
- expirar convites e candidaturas
- lembretes de plantao
- conciliacao de pagamentos
- recalculo de ranking simples

## 7. API e Contratos

Para o MVP:

- REST como contrato principal
- versionamento por `/v1`
- OpenAPI/Swagger desde o inicio
- DTOs com validacao e serializacao claras

## 8. Regras Operacionais Minimas

- toda acao critica deve gerar auditoria
- modulo de pagamento nao deve confiar apenas em retorno do cliente mobile
- uploads devem passar por validacao de tipo e tamanho
- perfis nao aprovados nao entram no fluxo principal de contratacao
