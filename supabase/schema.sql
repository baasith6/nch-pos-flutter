-- ============================================================
-- FlutterPOS — Complete Supabase Database Schema
-- Run this in the Supabase SQL Editor in order.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. EXTENSIONS
-- ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────
-- 2. TABLES
-- ─────────────────────────────────────────────────────────────

-- 2.1 profiles
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT NOT NULL,
  username    TEXT UNIQUE,
  phone       TEXT,
  role        TEXT NOT NULL CHECK (role IN ('Admin', 'Staff')) DEFAULT 'Staff',
  status      TEXT NOT NULL CHECK (status IN ('Active', 'Inactive')) DEFAULT 'Active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.2 categories
CREATE TABLE IF NOT EXISTS public.categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  status      TEXT NOT NULL CHECK (status IN ('Active', 'Inactive')) DEFAULT 'Active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.3 products
CREATE TABLE IF NOT EXISTS public.products (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id      UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  barcode          TEXT UNIQUE,
  selling_price    NUMERIC(12,2) NOT NULL CHECK (selling_price >= 0),
  cost_price       NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
  stock_quantity   INTEGER NOT NULL DEFAULT 0,
  reorder_level    INTEGER NOT NULL DEFAULT 0,
  image_url        TEXT,
  status           TEXT NOT NULL CHECK (status IN ('Active', 'Inactive')) DEFAULT 'Active',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.4 sales
CREATE TABLE IF NOT EXISTS public.sales (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_no      TEXT UNIQUE NOT NULL,
  staff_id        UUID NOT NULL REFERENCES public.profiles(id),
  subtotal        NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
  discount        NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
  grand_total     NUMERIC(12,2) NOT NULL CHECK (grand_total >= 0),
  payment_method  TEXT NOT NULL,
  status          TEXT NOT NULL CHECK (status IN ('Completed', 'Cancelled', 'Refunded')) DEFAULT 'Completed',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.5 sale_items
CREATE TABLE IF NOT EXISTS public.sale_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id       UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  product_id    UUID NOT NULL REFERENCES public.products(id),
  product_name  TEXT NOT NULL,  -- snapshot at time of sale
  quantity      INTEGER NOT NULL CHECK (quantity > 0),
  unit_price    NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  discount      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
  line_total    NUMERIC(12,2) NOT NULL CHECK (line_total >= 0)
);

-- 2.6 stock_adjustments
CREATE TABLE IF NOT EXISTS public.stock_adjustments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id    UUID NOT NULL REFERENCES public.products(id),
  old_quantity  INTEGER NOT NULL,
  new_quantity  INTEGER NOT NULL,
  reason        TEXT NOT NULL,
  adjusted_by   UUID NOT NULL REFERENCES public.profiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.7 shop_settings
CREATE TABLE IF NOT EXISTS public.shop_settings (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_name        TEXT NOT NULL DEFAULT 'My Shop',
  address          TEXT,
  phone            TEXT,
  email            TEXT,
  currency         TEXT NOT NULL DEFAULT 'LKR',
  receipt_footer   TEXT,
  tax_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
  tax_percentage   NUMERIC(5,2) NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2.8 payment_methods
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name    TEXT NOT NULL UNIQUE,
  status  TEXT NOT NULL CHECK (status IN ('Active', 'Inactive')) DEFAULT 'Active'
);

-- Seed default payment methods
INSERT INTO public.payment_methods (name) VALUES ('Cash'), ('Card'), ('Bank Transfer')
ON CONFLICT (name) DO NOTHING;

-- ─────────────────────────────────────────────────────────────
-- 3. STAFF-SAFE VIEW (no cost_price)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW public.product_public_view
WITH (security_invoker = true)
AS
SELECT
  id,
  category_id,
  name,
  barcode,
  selling_price,
  stock_quantity,
  reorder_level,
  image_url,
  status,
  created_at,
  updated_at
FROM public.products;

-- ─────────────────────────────────────────────────────────────
-- 4. HELPER FUNCTIONS (SECURITY DEFINER)
-- ─────────────────────────────────────────────────────────────

-- Returns the role of the currently authenticated user
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Returns true if the current user is Admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'Admin' AND status = 'Active'
  );
$$;

-- Returns true if the current user is Staff
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'Staff' AND status = 'Active'
  );
$$;

-- Returns true if current user is active (any role)
CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND status = 'Active'
  );
$$;

-- ─────────────────────────────────────────────────────────────
-- 5. ENABLE ROW LEVEL SECURITY
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_settings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods   ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 6. RLS POLICIES
-- ─────────────────────────────────────────────────────────────

-- profiles
CREATE POLICY "Admin: full access to profiles"
  ON public.profiles FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Staff: read own profile"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Staff: update own profile"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- categories
CREATE POLICY "Admin: full access to categories"
  ON public.categories FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Staff: read active categories"
  ON public.categories FOR SELECT
  USING (public.is_active_user() AND status = 'Active');

-- products (full table — Admin only)
CREATE POLICY "Admin: full access to products"
  ON public.products FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Staff can only SELECT active products (for POS — they use product_public_view)
CREATE POLICY "Staff: read active products"
  ON public.products FOR SELECT
  USING (public.is_active_user() AND status = 'Active');

-- sales
CREATE POLICY "Admin: full access to sales"
  ON public.sales FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Staff: read own sales"
  ON public.sales FOR SELECT
  USING (staff_id = auth.uid() AND public.is_active_user());

CREATE POLICY "Staff: insert own sales"
  ON public.sales FOR INSERT
  WITH CHECK (staff_id = auth.uid() AND public.is_active_user());

-- sale_items
CREATE POLICY "Admin: full access to sale_items"
  ON public.sale_items FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Staff: read own sale_items"
  ON public.sale_items FOR SELECT
  USING (
    public.is_active_user() AND
    sale_id IN (SELECT id FROM public.sales WHERE staff_id = auth.uid())
  );

CREATE POLICY "Staff: insert sale_items"
  ON public.sale_items FOR INSERT
  WITH CHECK (
    public.is_active_user() AND
    sale_id IN (SELECT id FROM public.sales WHERE staff_id = auth.uid())
  );

-- stock_adjustments
CREATE POLICY "Admin: full access to stock_adjustments"
  ON public.stock_adjustments FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Staff cannot write stock adjustments — only read their own
CREATE POLICY "Staff: no stock_adjustments access"
  ON public.stock_adjustments FOR SELECT
  USING (FALSE);

-- shop_settings
CREATE POLICY "Admin: full access to shop_settings"
  ON public.shop_settings FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "Staff: read shop_settings"
  ON public.shop_settings FOR SELECT
  USING (public.is_active_user());

-- payment_methods
CREATE POLICY "Active users: read payment_methods"
  ON public.payment_methods FOR SELECT
  USING (public.is_active_user());

CREATE POLICY "Admin: manage payment_methods"
  ON public.payment_methods FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─────────────────────────────────────────────────────────────
-- 7. create_sale() RPC — ATOMIC CHECKOUT TRANSACTION
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_sale(
  items           JSONB,
  payment_method  TEXT,
  bill_discount   NUMERIC DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id       UUID := auth.uid();
  v_profile       RECORD;
  v_sale_id       UUID;
  v_invoice_no    TEXT;
  v_subtotal      NUMERIC := 0;
  v_grand_total   NUMERIC;
  v_item          JSONB;
  v_product       RECORD;
  v_item_discount NUMERIC;
  v_line_total    NUMERIC;
  v_date_part     TEXT;
  v_seq           INTEGER;
  v_result_items  JSONB := '[]'::JSONB;
BEGIN

  -- 1. Verify user is active
  SELECT * INTO v_profile FROM public.profiles
  WHERE id = v_user_id AND status = 'Active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_inactive: Your account is inactive.';
  END IF;

  -- 2. Validate payment method is not empty
  IF payment_method IS NULL OR trim(payment_method) = '' THEN
    RAISE EXCEPTION 'invalid_payment_method: Payment method is required.';
  END IF;

  -- 3. Validate items array is not empty
  IF jsonb_array_length(items) = 0 THEN
    RAISE EXCEPTION 'empty_cart: No items in cart.';
  END IF;

  -- 4. Generate invoice number (atomic sequence per day)
  v_date_part := TO_CHAR(NOW(), 'YYYYMMDD');
  SELECT COUNT(*) + 1 INTO v_seq
  FROM public.sales
  WHERE invoice_no LIKE 'INV-' || v_date_part || '-%';
  v_invoice_no := 'INV-' || v_date_part || '-' || LPAD(v_seq::TEXT, 4, '0');

  -- 5. Create sale record (will be populated with totals after item processing)
  v_sale_id := gen_random_uuid();

  -- 6. Process each item
  FOR v_item IN SELECT * FROM jsonb_array_elements(items) LOOP

    -- Fetch and validate product
    SELECT * INTO v_product FROM public.products
    WHERE id = (v_item->>'product_id')::UUID
      AND status = 'Active'
    FOR UPDATE;  -- Lock row during transaction

    IF NOT FOUND THEN
      RAISE EXCEPTION 'product_not_found: Product % not found or inactive.', v_item->>'product_id';
    END IF;

    -- Check stock
    IF v_product.stock_quantity < (v_item->>'quantity')::INTEGER THEN
      RAISE EXCEPTION 'insufficient_stock: Insufficient stock for product: %', v_product.name;
    END IF;

    -- Calculate line total
    v_item_discount := COALESCE((v_item->>'discount')::NUMERIC, 0);
    v_line_total := (v_product.selling_price * (v_item->>'quantity')::INTEGER) - v_item_discount;
    v_subtotal := v_subtotal + v_line_total;

    -- Insert sale item
    INSERT INTO public.sale_items (
      sale_id, product_id, product_name,
      quantity, unit_price, discount, line_total
    ) VALUES (
      v_sale_id,
      v_product.id,
      v_product.name,
      (v_item->>'quantity')::INTEGER,
      v_product.selling_price,
      v_item_discount,
      v_line_total
    );

    -- Deduct stock
    UPDATE public.products
    SET stock_quantity = stock_quantity - (v_item->>'quantity')::INTEGER,
        updated_at = NOW()
    WHERE id = v_product.id;

    -- Build result items array
    v_result_items := v_result_items || jsonb_build_object(
      'product_name', v_product.name,
      'quantity', (v_item->>'quantity')::INTEGER,
      'unit_price', v_product.selling_price,
      'line_total', v_line_total
    );

  END LOOP;

  -- 7. Calculate grand total
  v_grand_total := v_subtotal - COALESCE(bill_discount, 0);
  IF v_grand_total < 0 THEN
    v_grand_total := 0;
  END IF;

  -- 8. Insert final sale record
  INSERT INTO public.sales (
    id, invoice_no, staff_id, subtotal, discount, grand_total, payment_method, status
  ) VALUES (
    v_sale_id, v_invoice_no, v_user_id,
    v_subtotal, COALESCE(bill_discount, 0), v_grand_total,
    payment_method, 'Completed'
  );

  -- 9. Return receipt data
  RETURN jsonb_build_object(
    'sale_id',        v_sale_id,
    'invoice_no',     v_invoice_no,
    'staff_name',     v_profile.full_name,
    'subtotal',       v_subtotal,
    'discount',       COALESCE(bill_discount, 0),
    'grand_total',    v_grand_total,
    'payment_method', payment_method,
    'status',         'Completed',
    'created_at',     NOW(),
    'items',          v_result_items
  );

END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 8. TRIGGERS — auto-update updated_at
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_categories_updated_at
  BEFORE UPDATE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER trg_shop_settings_updated_at
  BEFORE UPDATE ON public.shop_settings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ─────────────────────────────────────────────────────────────
-- 9. AUTO-CREATE PROFILE ON SIGNUP TRIGGER
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only insert if a profile doesn't already exist (Edge Fn creates it first)
  INSERT INTO public.profiles (id, full_name, role, status)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Unknown'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'Staff'),
    'Active'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- 10. STORAGE BUCKET
-- ─────────────────────────────────────────────────────────────
-- Run in Supabase Dashboard > Storage, or via this SQL:
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Allow Admin to upload
CREATE POLICY "Admin: upload product images"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

-- Allow all active users to view
CREATE POLICY "Active users: view product images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'product-images' AND public.is_active_user());

-- Allow Admin to delete/update
CREATE POLICY "Admin: manage product images"
  ON storage.objects FOR ALL
  USING (bucket_id = 'product-images' AND public.is_admin())
  WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

-- ─────────────────────────────────────────────────────────────
-- 11. SEED ADMIN USER (run AFTER creating user in Auth dashboard)
-- Replace 'YOUR_ADMIN_USER_UUID' with the actual UUID from Auth
-- ─────────────────────────────────────────────────────────────
-- INSERT INTO public.profiles (id, full_name, role, status)
-- VALUES ('YOUR_ADMIN_USER_UUID', 'Admin User', 'Admin', 'Active')
-- ON CONFLICT (id) DO UPDATE SET role = 'Admin', status = 'Active';
