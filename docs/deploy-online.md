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

## 5. Storage privado de documentos

O backend aceita qualquer storage compativel com a API S3. O bucket deve ser
privado; o aplicativo recebe URLs assinadas que expiram em dois minutos.

Configure primeiro todas as variaveis abaixo no Render:

```text
STORAGE_BUCKET=nome-do-bucket-privado
S3_ENDPOINT=https://endpoint-s3-do-provedor
S3_REGION=auto
S3_ACCESS_KEY_ID=chave-de-acesso
S3_SECRET_ACCESS_KEY=chave-secreta
S3_FORCE_PATH_STYLE=false
```

Para Cloudflare R2, use o endpoint S3 fornecido no painel e mantenha a regiao
como `auto`. Para AWS S3, deixe `S3_ENDPOINT` vazio e informe a regiao real do
bucket, por exemplo `sa-east-1`.

Para Supabase Storage, copie endpoint e regiao em
`Storage > Configuration > S3`. Nesse provedor, use obrigatoriamente:

```text
S3_FORCE_PATH_STYLE=true
```

Somente depois de salvar essas variaveis altere:

```text
STORAGE_DRIVER=s3
```

Faca um novo deploy e valide o envio e a abertura de um documento pelo painel
administrativo. Voltar `STORAGE_DRIVER` para `local` funciona apenas para
desenvolvimento e nao recupera arquivos remotos ou arquivos apagados pelo
Render.

## 6. Observacoes importantes

- O storage local em Render e temporario. Nao envie documentos reais enquanto
  `STORAGE_DRIVER=local`.
- Arquivos locais enviados antes da migracao nao sao copiados automaticamente
  para o bucket privado.
- Antes de producao real, rotacione a senha do Neon compartilhada durante os
  testes.
- O Asaas deve ser integrado somente depois que a API tiver URL publica estavel,
  porque webhooks precisam chamar a API online.
