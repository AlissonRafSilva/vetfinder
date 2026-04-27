# VetFinder - Modelo de Dados Inicial

## 1. Visao Geral

O banco principal sera PostgreSQL com extensao PostGIS para suportar buscas por proximidade.

O modelo inicial foi pensado para:

- separar autenticacao de perfil
- tratar instituicoes e profissionais com regras distintas
- suportar validacao documental
- viabilizar busca geoespacial
- registrar contratacoes e pagamentos

## 2. Entidades Principais

### users
Representa a conta de acesso.

Campos sugeridos:
- id (uuid)
- email
- phone
- password_hash
- role (`veterinarian`, `intern`, `clinic`, `hospital`, `admin`)
- status (`pending_verification`, `active`, `suspended`, `rejected`)
- last_login_at
- created_at
- updated_at

### profiles
Dados base comuns de exibicao.

Campos sugeridos:
- id
- user_id
- full_name
- photo_url
- city
- state
- bio
- is_visible
- address_id
- location geography(Point, 4326)
- created_at
- updated_at

### veterinarian_profiles
Campos especificos de veterinarios.

Campos sugeridos:
- id
- user_id
- crmv_number
- crmv_state
- verification_status
- base_shift_rate
- years_experience
- emergency_care
- can_travel
- max_distance_km

### intern_profiles
Campos especificos de estagiarios.

Campos sugeridos:
- id
- user_id
- university_name
- course_period
- expected_graduation_date
- verification_status

### institutions
Clinicas e hospitais.

Campos sugeridos:
- id
- user_id
- institution_type (`clinic`, `hospital`)
- legal_name
- trade_name
- cnpj
- state_registration
- description
- contact_name
- contact_phone
- verification_status
- address_id
- location geography(Point, 4326)
- created_at
- updated_at

### addresses
Endereco estruturado e reutilizavel.

Campos sugeridos:
- id
- zip_code
- street
- number
- complement
- district
- city
- state
- country
- lat
- lng

### documents
Documentos e evidencias do fluxo de validacao.

Campos sugeridos:
- id
- owner_type (`user`, `institution`)
- owner_id
- document_type (`profile_photo`, `crmv_proof`, `enrollment_statement`, `cnpj_proof`, `identity_document`, `selfie`)
- file_url
- mime_type
- status (`pending`, `in_review`, `approved`, `rejected`, `expired`)
- rejection_reason
- reviewed_by
- reviewed_at
- expires_at
- created_at

### specialties
Especialidades profissionais e demandas.

Campos sugeridos:
- id
- name
- slug
- active

### professional_specialties
Relacao N:N entre profissional e especialidade.

Campos sugeridos:
- id
- user_id
- specialty_id

### availability_slots
Disponibilidade do profissional.

Campos sugeridos:
- id
- user_id
- availability_type (`recurring`, `specific_date`, `blocked`)
- weekday
- specific_date
- start_time
- end_time
- timezone
- created_at

### opportunities
Vagas/plantões publicados por instituicoes.

Campos sugeridos:
- id
- institution_id
- title
- description
- opportunity_type (`shift`, `coverage`, `temporary`, `internship`)
- specialty_id
- start_at
- end_at
- duration_hours
- gross_amount
- urgency_level (`low`, `medium`, `high`, `critical`)
- status (`draft`, `open`, `in_negotiation`, `filled`, `completed`, `cancelled`)
- address_id
- location geography(Point, 4326)
- requires_verified_profile
- created_at
- updated_at

### opportunity_applications
Candidaturas dos profissionais.

Campos sugeridos:
- id
- opportunity_id
- professional_user_id
- status (`applied`, `withdrawn`, `accepted`, `rejected`, `expired`)
- message
- applied_at
- responded_at

### opportunity_invites
Convites enviados pela instituicao.

Campos sugeridos:
- id
- opportunity_id
- professional_user_id
- status (`sent`, `accepted`, `declined`, `expired`, `cancelled`)
- message
- invited_at
- responded_at

### engagements
Representa o fechamento efetivo da oportunidade.

Campos sugeridos:
- id
- opportunity_id
- institution_id
- professional_user_id
- source_type (`application`, `invite`)
- source_id
- gross_amount
- platform_fee_amount
- net_amount
- status (`pending_payment`, `confirmed`, `in_progress`, `completed`, `cancelled`, `disputed`)
- confirmed_at
- completed_at
- cancelled_at

### payments
Pagamento principal processado pelo gateway.

Campos sugeridos:
- id
- engagement_id
- provider
- provider_payment_id
- status (`pending`, `authorized`, `paid`, `failed`, `refunded`, `partially_refunded`)
- gross_amount
- platform_fee_amount
- net_amount
- paid_at
- refunded_at
- created_at

### payment_splits
Detalhes do split/repasse.

Campos sugeridos:
- id
- payment_id
- recipient_type (`platform`, `professional`)
- recipient_id
- amount
- status (`pending`, `scheduled`, `transferred`, `failed`)
- transfer_reference
- processed_at

### reviews
Avaliacao bilateral apos conclusao.

Campos sugeridos:
- id
- engagement_id
- reviewer_user_id
- reviewee_user_id
- rating
- comment
- created_at

### notifications
Notificacoes no app.

Campos sugeridos:
- id
- user_id
- type
- title
- body
- data_json
- sent_at
- read_at

### audit_logs
Trilha de auditoria.

Campos sugeridos:
- id
- actor_user_id
- actor_type
- action
- entity_type
- entity_id
- metadata_json
- created_at

## 3. Regras de Modelagem Importantes

- `users` guarda autenticacao e papel principal.
- `profiles` guarda dados de exibicao comuns.
- `veterinarian_profiles`, `intern_profiles` e `institutions` isolam regras especificas.
- `documents` deve suportar workflow administrativo.
- `opportunities` precisa armazenar geolocalizacao propria, sem depender apenas do endereco textual.
- `engagements` separa negociacao de vaga do contrato efetivo.
- `payments` e `payment_splits` devem refletir o fluxo do gateway, nao apenas um calculo interno.

## 4. Uso de PostGIS

Recomendacoes:

- usar `geography(Point, 4326)` para consultas por distancia em metros
- indexar localizacao com `GIST`
- manter latitude/longitude tambem como apoio operacional, se necessario

Exemplos de uso:

- profissionais em raio de 20 km
- oportunidades proximas do usuario
- ordenacao por menor distancia

## 5. Estados Criticos do Sistema

### Verificacao de conta
- pending
- in_review
- approved
- rejected

### Oportunidade
- draft
- open
- in_negotiation
- filled
- completed
- cancelled

### Contratacao
- pending_payment
- confirmed
- in_progress
- completed
- cancelled
- disputed

### Pagamento
- pending
- authorized
- paid
- failed
- refunded

## 6. Observacoes para o MVP

- manter soft delete apenas onde realmente for necessario
- nao complicar com heranca excessiva nas tabelas
- preparar o modelo para operacao manual parcial no inicio
- deixar `audit_logs` desde o primeiro dia
