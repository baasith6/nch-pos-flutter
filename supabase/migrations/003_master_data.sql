-- ============================================================
-- Migration 003: Master Data Foundation (Hardware Retail POS)
-- ============================================================

-- 1. Core Lookups
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    short_code TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Note: payment_methods was created in 002. Adding auditing fields.
ALTER TABLE public.payment_methods
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 2. External Entities
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    credit_limit NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact_name TEXT,
    phone TEXT,
    credit_limit NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (credit_limit >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Products
-- We migrate the existing products table to the new structure.
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS sku TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES public.brands(id),
ADD COLUMN IF NOT EXISTS base_unit_id UUID REFERENCES public.units(id),
ADD COLUMN IF NOT EXISTS attributes JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS cost_price NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
ADD COLUMN IF NOT EXISTS selling_price_base NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (selling_price_base >= 0),
ADD COLUMN IF NOT EXISTS reorder_level_base INTEGER NOT NULL DEFAULT 0 CHECK (reorder_level_base >= 0),
ADD COLUMN IF NOT EXISTS barcode TEXT UNIQUE;

-- Rename stock_quantity to base_stock_quantity
ALTER TABLE public.products 
RENAME COLUMN stock_quantity TO base_stock_quantity;
ALTER TABLE public.products
ADD CONSTRAINT chk_base_stock_quantity CHECK (base_stock_quantity >= 0);

CREATE TABLE IF NOT EXISTS public.product_units (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES public.units(id),
    base_quantity_multiplier INTEGER NOT NULL CHECK (base_quantity_multiplier > 0),
    barcode TEXT UNIQUE,
    selling_price NUMERIC(12,2) NOT NULL CHECK (selling_price >= 0),
    is_default_sales_unit BOOLEAN NOT NULL DEFAULT false,
    is_default_purchase_unit BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Inventory Ledgers
CREATE TABLE IF NOT EXISTS public.stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id),
    movement_type TEXT NOT NULL CHECK (movement_type IN ('Sale', 'GRN', 'Return', 'Adjustment', 'Opening')),
    reference_type TEXT NOT NULL,
    reference_id UUID,
    qty_change_base INTEGER NOT NULL,
    stock_before_base INTEGER NOT NULL,
    stock_after_base INTEGER NOT NULL,
    cost_price_snapshot NUMERIC(12,2) NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_brand_id ON public.products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products(status);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id_created_at ON public.stock_movements(product_id, created_at);

-- 6. Trigger for updated_at
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp triggers to new master tables
DROP TRIGGER IF EXISTS set_timestamp ON public.categories;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.brands;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.brands FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.units;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.units FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.customers;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.suppliers;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.products;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.product_units;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.product_units FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
