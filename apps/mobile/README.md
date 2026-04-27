# VetFinder Mobile

Base inicial manual do app Flutter do VetFinder.

## Estado atual

O SDK do Flutter nao estava disponivel no PATH do ambiente durante a criacao desta base, entao a estrutura foi montada manualmente.

Ja estao prontos:

- `pubspec.yaml`
- estrutura de `lib/`
- tema da aplicacao
- shell principal com navegacao
- telas iniciais de autenticacao, oportunidades, agenda e perfil

## Estrutura

```text
apps/mobile/
  lib/
    app/
    core/
    features/
```

## Proximo passo quando o Flutter estiver configurado

1. Rodar `flutter create .`
2. Conferir se o comando nao sobrescreveu os arquivos de `lib/`
3. Rodar `flutter pub get`
4. Rodar `flutter run`

## Modulos iniciais recomendados

- auth
- onboarding
- opportunities
- applications
- engagements
- payments
- profile
- schedule
