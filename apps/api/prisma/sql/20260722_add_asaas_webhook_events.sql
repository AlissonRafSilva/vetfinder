DO $$
BEGIN
  CREATE TYPE "AsaasWebhookProcessingStatus" AS ENUM (
    'RECEIVED',
    'PROCESSED',
    'IGNORED',
    'FAILED'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "asaas_webhook_events" (
  "id" UUID NOT NULL,
  "asaas_event_id" TEXT NOT NULL,
  "event_type" TEXT NOT NULL,
  "asaas_account_id" TEXT,
  "provider_payment_id" TEXT,
  "processing_status" "AsaasWebhookProcessingStatus" NOT NULL DEFAULT 'RECEIVED',
  "received_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "processed_at" TIMESTAMP(3),
  CONSTRAINT "asaas_webhook_events_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "asaas_webhook_events_asaas_event_id_key"
  ON "asaas_webhook_events"("asaas_event_id");

CREATE INDEX IF NOT EXISTS "asaas_webhook_events_event_type_received_at_idx"
  ON "asaas_webhook_events"("event_type", "received_at");

CREATE INDEX IF NOT EXISTS "asaas_webhook_events_processing_status_idx"
  ON "asaas_webhook_events"("processing_status");
