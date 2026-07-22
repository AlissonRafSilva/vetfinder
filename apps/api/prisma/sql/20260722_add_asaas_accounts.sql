DO $$
BEGIN
  CREATE TYPE "AsaasEnvironment" AS ENUM ('SANDBOX', 'PRODUCTION');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "AsaasAccountStatus" AS ENUM (
    'PENDING',
    'ACTIVE',
    'BLOCKED',
    'REJECTED'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "AsaasOnboardingStatus" AS ENUM (
    'NOT_STARTED',
    'PENDING_DATA',
    'PENDING_DOCUMENTS',
    'UNDER_REVIEW',
    'APPROVED',
    'REJECTED'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "asaas_accounts" (
  "id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "environment" "AsaasEnvironment" NOT NULL,
  "asaas_account_id" TEXT,
  "asaas_wallet_id" TEXT,
  "account_status" "AsaasAccountStatus" NOT NULL DEFAULT 'PENDING',
  "onboarding_status" "AsaasOnboardingStatus" NOT NULL DEFAULT 'NOT_STARTED',
  "last_synchronized_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "asaas_accounts_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "asaas_accounts_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "asaas_accounts_user_id_environment_key"
  ON "asaas_accounts"("user_id", "environment");

CREATE UNIQUE INDEX IF NOT EXISTS "asaas_accounts_environment_asaas_account_id_key"
  ON "asaas_accounts"("environment", "asaas_account_id");

CREATE UNIQUE INDEX IF NOT EXISTS "asaas_accounts_environment_asaas_wallet_id_key"
  ON "asaas_accounts"("environment", "asaas_wallet_id");

CREATE INDEX IF NOT EXISTS "asaas_accounts_account_status_onboarding_status_idx"
  ON "asaas_accounts"("account_status", "onboarding_status");
