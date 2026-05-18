# Deploy VetFinder

Este documento lista o caminho para sair do ambiente local e preparar o MVP para
um ambiente online de demonstracao ou homologacao.

## 1. Decisoes Antes Do Deploy

- Definir dominio da API.
- Definir ambiente: demo, homologacao ou producao.
- Definir onde rodara o PostgreSQL com PostGIS.
- Definir storage real para documentos.
- Definir gateway de pagamento e responsavel juridico.
- Definir politica minima de privacidade/LGPD.

## 2. Variaveis Da API

Baseie o ambiente em `apps/api/.env.example`.

Obrigatorias:

- `PORT`
- `NODE_ENV`
- `DATABASE_URL`
- `REDIS_URL`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `STORAGE_DRIVER`
- `STORAGE_BUCKET`
- `PAYMENT_PROVIDER`
- `PLATFORM_FEE_RATE`

Em producao:

- usar segredos JWT fortes;
- nao reutilizar credenciais locais;
- nao expor banco publicamente sem controle de rede;
- preferir storage externo para documentos.

## 3. Banco De Dados

Para deploy inicial:

```powershell
npm run prisma:generate --workspace apps/api
npm run prisma:deploy --workspace apps/api
```

Se o ambiente ainda nao usa migrations formais, alinhar antes:

```powershell
npm run prisma:push --workspace apps/api
```

Para producao real, preferir migrations versionadas.

## 4. Build Da API

```powershell
npm run build:api
```

Comando de execucao:

```powershell
npm run start:prod --workspace apps/api
```

Health check:

```text
/v1/health
```

## 5. Mobile

Antes de gerar build:

```powershell
cd apps/mobile
flutter analyze
```

Android:

```powershell
flutter build apk
```

Futuro recomendado:

- configurar `applicationId`;
- configurar icones/splash;
- configurar permissao de localizacao;
- configurar assinatura Android;
- criar flavor `dev`, `staging` e `prod`;
- configurar URL da API por ambiente.

## 6. Checklist De Producao

- CORS restrito ao dominio do app/admin.
- Rate limit em login e rotas sensiveis.
- Logs estruturados.
- Backups do banco.
- Monitoramento de API.
- Storage privado para documentos.
- Politica de retencao de documentos.
- Revisao LGPD.
- Termos de uso.
- Gateway real com split homologado.
- Webhooks de pagamento com assinatura validada.
- Conta bancaria/recebedores validados.

## 7. Status Atual

O projeto esta adequado para demonstracao funcional e evolucao para homologacao.
Ainda nao deve ser tratado como producao financeira real ate a escolha e
homologacao do gateway de pagamento.
