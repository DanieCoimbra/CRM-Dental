-- Migration: 20260907000002_enable_rls_all_tables.sql
-- Description: Habilita Row Level Security (RLS) e políticas de segurança para todas as tabelas públicas (LGPD / HIPAA / Supabase Security Advisor)

-- 1. Índices adicionais para performance e isolamento multi-tenant
CREATE INDEX IF NOT EXISTS idx_patient_files_clinic ON public.patient_files(clinic_id);
CREATE INDEX IF NOT EXISTS idx_patient_files_patient ON public.patient_files(patient_id);
CREATE INDEX IF NOT EXISTS idx_shift_assignments_clinic ON public.shift_assignments(clinic_id);
CREATE INDEX IF NOT EXISTS idx_settings_clinic ON public.settings(clinic_id);
CREATE INDEX IF NOT EXISTS idx_waitlists_clinic ON public.waitlists(clinic_id);
CREATE INDEX IF NOT EXISTS idx_teeth_status_clinic ON public.teeth_status(clinic_id);
CREATE INDEX IF NOT EXISTS idx_teeth_history_clinic ON public.teeth_history(clinic_id);
CREATE INDEX IF NOT EXISTS idx_clinic_installments_clinic ON public.clinic_installments(clinic_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_clinic ON public.inventory_items(clinic_id);
CREATE INDEX IF NOT EXISTS idx_inventory_transactions_clinic ON public.inventory_transactions(clinic_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_clinic ON public.subscriptions(clinic_id);

-- 2. Habilitação de RLS em todas as tabelas públicas
ALTER TABLE IF EXISTS public.teeth_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.patient_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.shift_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.waitlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.teeth_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.teeth_statuses ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.clinic_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.procedure_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.affiliates ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.used_checkout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.referral_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.appointment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.procedures ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.budget_items ENABLE ROW LEVEL SECURITY;

-- 3. Políticas de acesso seguro para o Backend Service (postgres e service_role)
-- PostgREST (anon / authenticated públicos) não possui políticas permissivas, bloqueando acessos não autorizados via API pública

DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'teeth_history',
        'patient_files',
        'shift_assignments',
        'settings',
        'waitlists',
        'teeth_status',
        'teeth_statuses',
        'clinic_installments',
        'inventory_items',
        'inventory_transactions',
        'procedure_materials',
        'affiliates',
        'coupons',
        'used_checkout_sessions',
        'referral_partners',
        'promo_codes',
        'subscriptions',
        'roles',
        'rooms',
        'appointment_types',
        'procedures',
        'budgets',
        'budget_items'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        IF EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            EXECUTE format('DROP POLICY IF EXISTS "Allow Full Access to Backend Service" ON public.%I;', tbl);
            EXECUTE format('CREATE POLICY "Allow Full Access to Backend Service" ON public.%I FOR ALL TO postgres, service_role USING (true) WITH CHECK (true);', tbl);
        END IF;
    END LOOP;
END $$;
