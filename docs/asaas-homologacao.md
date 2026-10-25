# Homologacao do split Pix

## Regra financeira

- A clinica paga o valor integral do profissional, a comissao VetFinder e a tarifa do Asaas.
- O profissional recebe 100% do valor solicitado. A clinica paga mais 3% desse valor para o VetFinder, alem da tarifa Asaas.
- A tarifa e consultada no simulador do Asaas; nao existe tarifa fixa no app.
- Exemplo: profissional solicita R$ 250 e recebe R$ 250. VetFinder recebe R$ 7,50. A clinica paga R$ 257,50 mais a tarifa simulada do Asaas.
- A API compara novamente o total aprovado antes de criar a cobranca. Se a tarifa mudar, exige nova confirmacao.
- Cobrancas antigas conservam a regra original; nao devem ser alteradas ou pagas novamente automaticamente.
- No contrato, `netAmount` e o valor integral do profissional, `platformFeeAmount` e a comissao adicional e `grossAmount` e a soma dos dois antes da tarifa Asaas. O campo legado `grossAmount` na requisicao de fechamento representa o valor solicitado pelo profissional; a API calcula a comissao, sem confiar no valor enviado pelo cliente.
- Na cotacao, `serviceAmount` e `professionalAmount` representam o valor do profissional, `subtotalAmount` inclui a comissao e `chargeAmount` inclui tambem a tarifa Asaas.

## Verificacoes locais

Na pasta `apps/api`:

```powershell
npm test
npm run build
node --require ts-node/register scripts/check-asaas-sandbox.cjs
```

Na pasta `apps/mobile`:

```powershell
flutter analyze
flutter test --no-pub
```

Os testes automatizados usam respostas simuladas. Eles nao comprovam liquidacao no Asaas.

## Credenciais

`apps/api/.env.asaas.local` e ignorado pelo Git. Usar somente a chave Sandbox nesse arquivo. Nao enviar a chave por chat, nao colocar no Flutter e nao incluir em logs.

O arquivo local nao configura o Render automaticamente. Depois de validar a chave,
atualizar ASAAS_API_KEY no painel do servico sem alterar o token do webhook.
Consultas de webhooks nao retornam authToken: verificar hasAuthToken.

O diagnostico mostra o caminho e a data de alteracao do arquivo e recusa Producao.
Faz apenas consultas e simulacoes: nao cria clientes, subcontas ou cobrancas.

## Verificacao real em 2026-10-24

- Chave local substituida e autenticada na API oficial Sandbox com HTTP 200.
- Conta principal aprovada e acesso a listagem de subcontas confirmado.
- Cotacao executada pelo AsaasService: subtotal 257,50, tarifa 1,99 e total 259,49.
  Este resultado nao deve ser usado como tarifa fixa no aplicativo.
- Webhook principal ativo, nao interrompido e com autenticacao configurada.
- PAYMENT_SPLIT_DONE acrescentado, preservando URL, token e eventos existentes.
- A rota de cotacao publicada retornava 404 antes da implantacao dos ajustes.
- Uma carteira aprovada no banco retornava 404 na conta Asaas: nao reutilizar esse
  cadastro ou pagamentos antigos na nova homologacao.
- Criacao, recebimento e liquidacao do split ainda precisam ser comprovados juntos.

O reinicio Sandbox reconcilia tentativas CREATE_FAILED sem ID externo antes de
avaliar splits pendentes. Somente uma consulta bem-sucedida que confirme ausencia
da cobranca permite liberar esses splits; falhas do gateway mantem o bloqueio.
O cadastro financeiro e bloqueado em transacao durante a reserva de uma nova
cobranca e durante o reinicio. Uma tentativa iniciada entre as duas operacoes
impede o reinicio, e um cadastro removido impede a criacao do Pix.
Registros identificados como Producao nao sao recuperados com credenciais Sandbox.

No Render, conferir `PAYMENT_PROVIDER`, `ASAAS_ENVIRONMENT`, `ASAAS_API_URL`, `ASAAS_API_KEY`, `ASAAS_WEBHOOK_TOKEN`, `ASAAS_WEBHOOK_URL` e `ASAAS_WEBHOOK_EMAIL`. Nao revogar uma chave em uso antes de validar a substituta e atualizar o servico.

## Implantacao coordenada

1. Validar a chave na API Sandbox e consultar uma simulacao sem criar cobranca.
2. Verificar o webhook da conta principal, responsavel pelas cobrancas, no endpoint `https://vetfinder-api.onrender.com/v1/payments/asaas/webhook`. Deve estar ativo e sem fila interrompida.
3. Incluir os eventos tratados pelo backend, especialmente `PAYMENT_CONFIRMED`, `PAYMENT_RECEIVED`, `PAYMENT_PARTIALLY_REFUNDED`, `PAYMENT_REFUNDED`, `PAYMENT_SPLIT_DONE`, `PAYMENT_SPLIT_CANCELLED` e os dois eventos de divergencia de split. Os eventos de situacao de conta continuam necessarios para o cadastro financeiro.
4. Publicar a API e gerar um APK atualizado. A nova criacao exige `expectedChargeAmount`; APKs antigos nao confirmam a tarifa adicional e nao devem criar cobrancas nessa versao.
5. Usar um contrato de teste novo com carteira aprovada. Confirmar no app o valor do plantao, a tarifa, o total, o valor profissional e a comissao antes de gerar o Pix.
6. Conferir no Asaas o valor total e o split fixo para a carteira correta. Simular o pagamento apenas no Sandbox.
7. Confirmar recebimento pelo webhook, contrato confirmado e repasse profissional concluido. Pagamento recebido e split liquidado sao estados diferentes.
8. Repetir atualizacoes e eventos duplicados, verificando que continuam existindo uma cobranca e um contrato. Testar tambem indisponibilidade temporaria, reinicio da API, vencimento, estorno e cancelamento do split.
9. Conciliar os valores no gateway com o registro no banco. Uma divergencia deve impedir novas tentativas de pagamento da mesma cobranca e exigir suporte, nao gerar outro Pix.

Nao considerar o split homologado antes de concluir o ciclo real no Sandbox. Nenhuma etapa deste roteiro autoriza pagamentos reais em producao.

## Referencias

- [Simulador de vendas](https://docs.asaas.com/reference/simulador-de-vendas)
- [Split de pagamentos](https://docs.asaas.com/docs/split-de-pagamentos)
- [Eventos de cobranca e split](https://docs.asaas.com/docs/webhook-para-cobrancas)
