# VetFinder - Arquitetura Inicial do MVP

## 1. Objetivo

O VetFinder sera um marketplace mobile para conectar veterinarios volantes, estagiarios, clinicas e hospitais veterinarios em oportunidades de plantao, cobertura e trabalho temporario.

O MVP precisa priorizar:

- velocidade de publicacao e fechamento de vagas
- confianca na validacao dos perfis
- geolocalizacao e disponibilidade
- pagamento com retencao da taxa da plataforma
- operacao simples o suficiente para ser lancada e validada rapidamente

## 2. Stack Definida

### Mobile
- Flutter

### Backend
- NestJS
- TypeScript

### Dados
- PostgreSQL
- PostGIS
- Redis

### Arquivos
- Storage para documentos e imagens de perfil

### Pagamentos
- Gateway com suporte a marketplace/split, validado com apoio juridico e contabil

## 3. Estrategia de Arquitetura

Para o MVP, a recomendacao e usar um monolito modular.

Isso significa:

- uma unica aplicacao backend
- modulos de dominio bem separados
- banco relacional centralizado
- filas assicronas para notificacoes, validacoes e pagamentos

Essa abordagem reduz custo e complexidade, acelera entrega e facilita evolucao futura para servicos separados se o volume justificar.

## 4. Componentes Principais

### App Mobile Flutter
- onboarding e autenticacao
- perfis por tipo de usuario
- busca de oportunidades e profissionais
- agenda/disponibilidade
- candidaturas e convites
- historico, pagamentos e notificacoes

### API Backend NestJS
- autenticacao e autorizacao
- gestao de perfis
- validacao documental
- gestao de oportunidades
- busca geoespacial
- contratacao
- pagamentos
- reputacao
- notificacoes
- administracao operacional

### Banco PostgreSQL + PostGIS
- persistencia relacional
- filtros por geolocalizacao
- ordenacao por proximidade
- suporte a consultas por raio/distancia

### Redis
- filas
- cache de consultas quentes
- controle de jobs assincromos
- rate limiting e eventos temporarios, se necessario

### Storage
- fotos de perfil
- comprovantes de CRMV
- declaracoes de matricula
- documentos institucionais

### Painel Administrativo Web
- aprovacao documental
- suporte operacional
- monitoramento de pagamentos
- moderacao e analise de problemas

## 5. Principios de Projeto

- API orientada a dominio, nao apenas CRUD
- validacao documental tratada como fluxo operacional
- geolocalizacao como capacidade central do sistema
- trilha de auditoria para eventos sensiveis
- seguranca e confianca desde o MVP
- observabilidade minima desde o inicio

## 6. Fluxos Criticos

### Fluxo 1: profissional entra na plataforma
1. Usuario escolhe perfil.
2. Realiza cadastro.
3. Envia documentos.
4. Aguarda aprovacao.
5. Completa agenda e preferencias.
6. Passa a receber oportunidades compativeis.

### Fluxo 2: instituicao fecha um plantao urgente
1. Instituicao valida cadastro.
2. Publica oportunidade.
3. Recebe candidaturas ou busca profissionais.
4. Seleciona profissional.
5. Confirma contratacao.
6. Pagamento e processado.
7. Plantao e concluido.
8. Ambas as partes avaliam a experiencia.

## 7. Modulos Recomendados do Backend

- auth
- users
- professionals
- institutions
- documents
- specialties
- availability
- opportunities
- matching
- applications
- engagements
- payments
- reviews
- notifications
- admin
- audit

## 8. Padroes Tecnicos Recomendados

- NestJS com arquitetura modular por dominio
- DTOs + validacao com class-validator
- Prisma ou TypeORM para acesso a dados
- JWT com refresh token
- fila com BullMQ sobre Redis
- storage abstraido por provider
- eventos de dominio ou eventos de aplicacao para acoes assincronas

## 9. Seguranca e Compliance

O MVP deve incluir, no minimo:

- hash forte de senha
- controle de acesso por perfil
- assinatura de URLs privadas para documentos sensiveis
- criptografia em transito
- logs de operacoes administrativas
- politicas de retencao de documentos
- mascaramento de dados sensiveis onde fizer sentido

## 10. Evolucao Esperada

Quando o produto ganhar tracao, os modulos com maior chance de extraçao futura sao:

- matching/busca
- pagamentos
- notificacoes
- verificacao documental

No inicio, todos permanecem dentro do monolito modular.
