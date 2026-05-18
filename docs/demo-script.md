# Roteiro de Demonstração VetFinder

Este roteiro ajuda a apresentar o VetFinder de forma clara, mostrando o valor do
marketplace sem depender de improviso.

## Objetivo Da Demo

Mostrar como uma clinica ou hospital consegue resolver rapidamente uma demanda
de plantao, encontrando profissionais disponiveis, fechando a contratacao,
acompanhando pagamento sandbox, alertas e avaliacao.

## Preparacao

Antes de iniciar:

1. Subir Docker.
2. Subir API.
3. Rodar o app Flutter.
4. Confirmar que o health check responde.
5. Ter pelo menos uma conta institucional e uma conta profissional disponiveis.

Comandos principais:

```powershell
cd C:\Users\Alisson\Desktop\projetos\Vetfinder\apps\api
docker compose up -d
```

```powershell
cd C:\Users\Alisson\Desktop\projetos\Vetfinder
npm run dev:api
```

```powershell
cd C:\Users\Alisson\Desktop\projetos\Vetfinder\apps\mobile
flutter run -d chrome
```

## Contas Demo

Senha padrao:

```text
vetfinder123
```

Usuarios:

- `admin@vetfinder.app`
- `clinica.demo@vetfinder.app`
- `hospital.demo@vetfinder.app`
- `veterinario.demo@vetfinder.app`
- `estagiario.demo@vetfinder.app`

## Fluxo 1: Abertura

Tela: entrada do app.

O que mostrar:

- proposta do VetFinder;
- perfis atendidos;
- destaque para agenda, geolocalizacao, alertas e split sandbox.

Fala sugerida:

> O VetFinder conecta clinicas e hospitais com veterinarios volantes e
> estagiarios para cobrir demandas urgentes de plantao, usando agenda,
> localizacao, validacao cadastral e fluxo financeiro dentro do app.

## Fluxo 2: Login Como Clinica

1. Entrar com `clinica.demo@vetfinder.app`.
2. Abrir `Perfil`.
3. Mostrar dados institucionais e documentos.

O que explicar:

- a instituicao possui cadastro proprio;
- documentos/CNPJ aumentam confianca;
- a instituicao nao ve vagas de outras clinicas.

## Fluxo 3: Criar Ou Editar Vaga

1. Abrir `Minhas vagas`.
2. Clicar em `Nova vaga`.
3. Preencher:
   - titulo;
   - descricao;
   - tipo de vaga;
   - data e horario;
   - valor;
   - especialidade manual;
   - exigencia de perfil verificado, se quiser.
4. Salvar.
5. Se estiver em rascunho, publicar.

O que mostrar:

- a vaga fica vinculada somente a instituicao logada;
- a tela mostra status, candidatos, convites e botao atualizar;
- detalhes ficam recolhidos para nao poluir a tela.

Fala sugerida:

> A clinica publica uma necessidade real, como um plantao noturno de emergencia,
> e acompanha candidaturas e convites dentro da propria vaga.

## Fluxo 4: Buscar Profissionais Disponiveis

1. Abrir `Disponiveis`.
2. Usar `Usar minha localizacao atual`, se aplicavel.
3. Filtrar por:
   - tipo de profissional;
   - especialidade;
   - distancia;
   - perfil verificado.
4. Abrir perfil de um profissional.
5. Enviar convite.

O que explicar:

- busca por agenda disponivel;
- localizacao automatica;
- perfis completos ganham mais confianca;
- clinica pode convidar diretamente.

## Fluxo 5: Login Como Profissional

1. Sair da conta institucional.
2. Entrar como `veterinario.demo@vetfinder.app` ou `estagiario.demo@vetfinder.app`.
3. Abrir `Alertas`.
4. Ver convite recebido.
5. Abrir area de oportunidades/convites.
6. Aceitar ou recusar convite.

O que explicar:

- profissional recebe alertas;
- pode responder convite;
- profissionais e estagiarios veem oportunidades compativeis com o perfil.

## Fluxo 6: Fechar Plantao

1. Voltar para a conta da clinica.
2. Abrir `Minhas vagas`.
3. Abrir detalhes da vaga.
4. Ver convite aceito ou candidatura aceita.
5. Clicar em `Fechar plantao`.

O que explicar:

- o fechamento cria uma contratacao;
- a vaga deixa de ficar aberta;
- o plantao passa para `Contratacoes`.

## Fluxo 7: Pagamento Sandbox

1. Abrir `Contratacoes`.
2. Abrir o detalhe do plantao.
3. Clicar em `Gerar checkout sandbox`.
4. Mostrar:
   - status aguardando pagamento;
   - provedor `sandbox-split`;
   - valor bruto;
   - taxa VetFinder;
   - valor liquido do profissional;
   - status do provedor.
5. Clicar em `Abrir checkout sandbox`.
6. Explicar que a pagina externa e simulada.
7. Voltar e clicar em `Confirmar pagamento sandbox`.

O que explicar:

- o pagamento real ainda depende do gateway escolhido;
- a arquitetura ja separa provider, checkout e split;
- a confirmacao sandbox simula retorno de gateway/webhook.

Fala sugerida:

> Neste momento o fluxo financeiro esta em sandbox. A estrutura ja esta pronta
> para integrar um gateway com split, mas a escolha precisa passar pela parte
> juridica e pela instituicao que representara a operacao.

## Fluxo 8: Avaliacao

1. Depois do pagamento confirmado, abrir o detalhe do plantao.
2. Clicar em `Avaliar contraparte`.
3. Escolher nota.
4. Escrever comentario.
5. Salvar.

O que explicar:

- reputacao aumenta confianca do marketplace;
- clinica avalia profissional;
- profissional tambem avalia instituicao.

## Fluxo 9: Alertas

Mostrar a aba `Alertas` nos dois perfis.

Eventos demonstraveis:

- nova candidatura;
- convite recebido;
- convite aceito/recusado;
- candidatura aceita/recusada;
- plantao fechado.

O que explicar:

- alertas evitam que o usuario precise procurar mudancas manualmente;
- no futuro podem virar push notifications.

## Fluxo 10: Admin

1. Entrar como `admin@vetfinder.app`.
2. Mostrar documentos enviados.
3. Aprovar/reprovar documentos.

O que explicar:

- validacao aumenta confianca;
- no MVP a revisao e administrativa;
- no futuro pode haver integracao externa para CNPJ, CRMV e documentos.

## Pontos MVP / Sandbox

Deixar claro durante a apresentacao:

- pagamento real ainda nao esta conectado;
- checkout atual e sandbox;
- split real depende de gateway e contrato juridico;
- validacao de CRMV/CNPJ ainda e administrativa;
- notificacoes sao internas, nao push;
- deploy de producao ainda exige hardening.

## Fechamento Da Demo

Mensagem final sugerida:

> O VetFinder ja demonstra o ciclo principal do marketplace: instituicao publica
> demanda, encontra profissional, fecha plantao, acompanha pagamento, recebe
> alertas e registra reputacao. A proxima etapa e homologar pagamento real,
> fortalecer validacoes e preparar deploy.
