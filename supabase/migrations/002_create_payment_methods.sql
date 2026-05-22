-- ============================================================
-- Migration: Create payment_methods table for dynamic payment config
-- Run this in the Supabase SQL Editor
-- ============================================================

-- Create the payment_methods table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name   TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default methods (idempotent)
INSERT INTO public.payment_methods (name, status)
VALUES
  ('Cash',          'Active'),
  ('Card',          'Active'),
  ('Bank Transfer', 'Active')
ON CONFLICT (name) DO NOTHING;

-- Enable Row Level Security
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read active methods
CREATE POLICY "payment_methods_read"
  ON public.payment_methods
  FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert/update (adjust as needed based on your admin role check)
CREATE POLICY "payment_methods_admin_write"
  ON public.payment_methods
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );
