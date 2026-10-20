-- NestJS accesses these tables as their owner; browser clients use the API.
DO $migration$
DECLARE
  app_table text;
BEGIN
  FOREACH app_table IN ARRAY ARRAY[
    'addresses', 'users', 'asaas_accounts', 'asaas_webhook_events',
    'audit_logs', 'availability_slots', 'institutions', 'documents',
    'specialties', 'opportunities', 'engagements', 'intern_profiles',
    'notifications', 'opportunity_applications', 'opportunity_invites',
    'payments', 'payment_splits', 'professional_specialties', 'profiles',
    'reviews', 'veterinarian_profiles'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename = app_table
        AND tableowner = current_user
    ) THEN
      RAISE EXCEPTION 'Missing table or unexpected owner: public.%', app_table;
    END IF;

    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', app_table);
    EXECUTE format(
      'REVOKE ALL PRIVILEGES ON TABLE public.%I FROM PUBLIC, anon, authenticated',
      app_table
    );
  END LOOP;
END
$migration$;

REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
  FROM PUBLIC, anon, authenticated;

-- Prisma creates future tables with the same database role.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL PRIVILEGES ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL PRIVILEGES ON SEQUENCES FROM PUBLIC, anon, authenticated;
