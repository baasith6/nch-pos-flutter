-- ============================================================
-- Migration 005: Sales, Quotations, Returns & Ledgers
-- ============================================================

-- 1. Refactor Sales and Sale Items
ALTER TABLE public.sales
ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES public.customers(id),
ADD COLUMN IF NOT EXISTS amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
ADD COLUMN IF NOT EXISTS balance_due NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (balance_due >= 0),
ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'Paid' CHECK (payment_status IN ('Paid', 'Partially Paid', 'Unpaid')),
ADD COLUMN IF NOT EXISTS sale_status TEXT NOT NULL DEFAULT 'Completed' CHECK (sale_status IN ('Completed', 'Cancelled', 'Refunded')),
ADD COLUMN IF NOT EXISTS stock_conflict BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS conflict_reason TEXT,
ADD COLUMN IF NOT EXISTS synced_from_offline BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

DO $$
BEGIN
  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='sales' and column_name='status') THEN
    UPDATE public.sales SET sale_status = status;
    ALTER TABLE public.sales DROP COLUMN status;
  END IF;
END $$;

ALTER TABLE public.sale_items
ADD COLUMN IF NOT EXISTS product_unit_id UUID REFERENCES public.product_units(id),
ADD COLUMN IF NOT EXISTS base_quantity_multiplier_snapshot INTEGER NOT NULL DEFAULT 1 CHECK (base_quantity_multiplier_snapshot > 0),
ADD COLUMN IF NOT EXISTS quantity_base INTEGER NOT NULL DEFAULT 0 CHECK (quantity_base >= 0);

UPDATE public.sale_items SET quantity_base = quantity WHERE quantity_base = 0;

-- 2. Customer Payments & Allocations
CREATE TABLE IF NOT EXISTS public.customer_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.customers(id),
    payment_method_id UUID NOT NULL REFERENCES public.payment_methods(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.customer_payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_payment_id UUID NOT NULL REFERENCES public.customer_payments(id) ON DELETE CASCADE,
    sale_id UUID NOT NULL REFERENCES public.sales(id),
    allocated_amount NUMERIC(12,2) NOT NULL CHECK (allocated_amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Split Payments for Sales at Checkout
CREATE TABLE IF NOT EXISTS public.sale_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    payment_method_id UUID NOT NULL REFERENCES public.payment_methods(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- 3. Quotations
CREATE TABLE IF NOT EXISTS public.quotations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.customers(id),
    invoice_no TEXT UNIQUE NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    discount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    grand_total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (grand_total >= 0),
    status TEXT NOT NULL DEFAULT 'Draft' CHECK (status IN ('Draft', 'Sent', 'Accepted', 'Converted', 'Rejected')),
    expiry_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.quotation_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quotation_id UUID NOT NULL REFERENCES public.quotations(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    product_unit_id UUID NOT NULL REFERENCES public.product_units(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    base_quantity_multiplier_snapshot INTEGER NOT NULL CHECK (base_quantity_multiplier_snapshot > 0),
    quantity_base INTEGER NOT NULL CHECK (quantity_base > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    discount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    line_total NUMERIC(12,2) NOT NULL CHECK (line_total >= 0)
);

-- 4. Customer Ledger View
CREATE OR REPLACE VIEW public.customer_ledger_view AS
SELECT 
    c.id AS customer_id,
    c.name,
    COALESCE(s.total_invoiced, 0) AS invoice_total,
    COALESCE(cp.total_paid, 0) AS payment_total,
    (COALESCE(s.total_invoiced, 0) - COALESCE(cp.total_paid, 0)) AS balance
FROM public.customers c
LEFT JOIN (
    SELECT customer_id, SUM(grand_total) as total_invoiced 
    FROM public.sales 
    WHERE sale_status != 'Cancelled' AND sale_status != 'Refunded'
    GROUP BY customer_id
) s ON s.customer_id = c.id
LEFT JOIN (
    -- Customer payments can come from sale checkouts directly AND standalone payments
    SELECT customer_id, SUM(amount) as total_paid 
    FROM (
        -- Payments specifically logged as customer_payments
        SELECT customer_id, amount FROM public.customer_payments
        UNION ALL
        -- Payments made at point of sale for a specific customer
        SELECT s.customer_id, sp.amount
        FROM public.sale_payments sp
        JOIN public.sales s ON s.id = sp.sale_id
        WHERE s.customer_id IS NOT NULL AND s.sale_status != 'Cancelled' AND s.sale_status != 'Refunded'
    ) combined_payments
    GROUP BY customer_id
) cp ON cp.customer_id = c.id;

-- 5. RPC: create_sale() (Idempotent UUID sync, allows negative stock for offline)
DROP FUNCTION IF EXISTS public.create_sale(jsonb, text, numeric);
DROP FUNCTION IF EXISTS public.create_sale(jsonb, text, numeric, numeric);

CREATE OR REPLACE FUNCTION public.create_sale(
    p_sale_id UUID,          
    p_customer_id UUID,      
    p_items JSONB,           
    p_payments JSONB,        
    p_subtotal NUMERIC,
    p_discount NUMERIC,
    p_tax_amount NUMERIC,
    p_grand_total NUMERIC,
    p_synced_from_offline BOOLEAN,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_existing_sale RECORD;
    v_invoice_no TEXT;
    v_date_part TEXT;
    v_seq INTEGER;
    v_item JSONB;
    v_payment JSONB;
    v_product RECORD;
    v_pu RECORD;
    v_stock_before INTEGER;
    v_stock_after INTEGER;
    v_stock_conflict BOOLEAN := false;
    v_conflict_reason TEXT := NULL;
    v_total_paid NUMERIC := 0;
    v_payment_status TEXT;
    v_balance_due NUMERIC;
BEGIN
    -- 1. Idempotency Check
    SELECT * INTO v_existing_sale FROM public.sales WHERE id = p_sale_id;
    IF FOUND THEN
        RETURN jsonb_build_object('success', true, 'sale_id', p_sale_id, 'message', 'Already synced');
    END IF;

    -- 2. Generate invoice number
    v_date_part := TO_CHAR(NOW(), 'YYYYMMDD');
    SELECT COUNT(*) + 1 INTO v_seq FROM public.sales WHERE invoice_no LIKE 'INV-' || v_date_part || '-%';
    v_invoice_no := 'INV-' || v_date_part || '-' || LPAD(v_seq::TEXT, 4, '0');

    -- Calculate total paid and payment status
    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments) LOOP
        v_total_paid := v_total_paid + (v_payment->>'amount')::NUMERIC;
    END LOOP;
    
    v_balance_due := p_grand_total - v_total_paid;
    IF v_balance_due <= 0 THEN
        v_payment_status := 'Paid';
        v_balance_due := 0;
    ELSIF v_total_paid > 0 THEN
        v_payment_status := 'Partially Paid';
    ELSE
        v_payment_status := 'Unpaid';
    END IF;

    -- 3. Pre-flight Check: Stock validation
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT * INTO v_product FROM public.products WHERE id = (v_item->>'product_id')::UUID FOR UPDATE;
        SELECT * INTO v_pu FROM public.product_units WHERE id = (v_item->>'product_unit_id')::UUID;
        
        v_stock_after := v_product.base_stock_quantity - ((v_item->>'quantity')::INTEGER * v_pu.base_quantity_multiplier);
        
        IF v_stock_after < 0 THEN
            IF p_synced_from_offline THEN
                v_stock_conflict := true;
                v_conflict_reason := COALESCE(v_conflict_reason || ', ', '') || 'Negative stock for ' || v_product.name;
            ELSE
                RAISE EXCEPTION 'insufficient_stock: Insufficient stock for product %', v_product.name;
            END IF;
        END IF;
    END LOOP;

    -- 4. Insert Sales Row FIRST
    INSERT INTO public.sales (
        id, invoice_no, customer_id, subtotal, discount, tax_amount, grand_total,
        amount_paid, balance_due, payment_status, sale_status, 
        stock_conflict, conflict_reason, synced_from_offline, created_by, staff_id
    ) VALUES (
        p_sale_id, v_invoice_no, p_customer_id, p_subtotal, p_discount, p_tax_amount, p_grand_total,
        v_total_paid, v_balance_due, v_payment_status, 'Completed',
        v_stock_conflict, v_conflict_reason, p_synced_from_offline, p_user_id, p_user_id
    );

    -- 5. Insert Payments
    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments) LOOP
        INSERT INTO public.sale_payments (sale_id, payment_method_id, amount, created_by)
        VALUES (p_sale_id, (v_payment->>'payment_method_id')::UUID, (v_payment->>'amount')::NUMERIC, p_user_id);
    END LOOP;

    -- 6. Insert Items & Process Stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT * INTO v_product FROM public.products WHERE id = (v_item->>'product_id')::UUID;
        SELECT * INTO v_pu FROM public.product_units WHERE id = (v_item->>'product_unit_id')::UUID;
        
        v_stock_before := v_product.base_stock_quantity;
        v_stock_after := v_stock_before - ((v_item->>'quantity')::INTEGER * v_pu.base_quantity_multiplier);

        UPDATE public.products 
        SET base_stock_quantity = v_stock_after, updated_at = NOW() 
        WHERE id = v_product.id;

        INSERT INTO public.sale_items (
            sale_id, product_id, product_name, product_unit_id, quantity, 
            base_quantity_multiplier_snapshot, quantity_base, unit_price, discount, line_total
        ) VALUES (
            p_sale_id, v_product.id, v_product.name, v_pu.id, (v_item->>'quantity')::INTEGER,
            v_pu.base_quantity_multiplier, ((v_item->>'quantity')::INTEGER * v_pu.base_quantity_multiplier),
            (v_item->>'unit_price')::NUMERIC, (v_item->>'discount')::NUMERIC, (v_item->>'line_total')::NUMERIC
        );

        INSERT INTO public.stock_movements (
            product_id, movement_type, reference_type, reference_id,
            qty_change_base, stock_before_base, stock_after_base,
            cost_price_snapshot, created_by
        ) VALUES (
            v_product.id, 'Sale', 'SALE', p_sale_id,
            -((v_item->>'quantity')::INTEGER * v_pu.base_quantity_multiplier), v_stock_before, v_stock_after,
            v_product.cost_price, p_user_id
        );
    END LOOP;

    RETURN jsonb_build_object('success', true, 'sale_id', p_sale_id, 'invoice_no', v_invoice_no);
END;
$$;

-- 6. RPC: cancel_sale() (Stock reversal, ledger update)
CREATE OR REPLACE FUNCTION public.cancel_sale(
    p_sale_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale RECORD;
    v_item RECORD;
    v_product RECORD;
    v_stock_before INTEGER;
    v_stock_after INTEGER;
BEGIN
    SELECT * INTO v_sale FROM public.sales WHERE id = p_sale_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'sale_not_found: Sale % not found', p_sale_id;
    END IF;
    IF v_sale.sale_status = 'Cancelled' THEN
        RAISE EXCEPTION 'sale_already_cancelled: Sale % is already cancelled', p_sale_id;
    END IF;

    -- Update Sale Status
    UPDATE public.sales SET sale_status = 'Cancelled', updated_at = NOW() WHERE id = p_sale_id;

    -- Reverse Stock
    FOR v_item IN SELECT * FROM public.sale_items WHERE sale_id = p_sale_id LOOP
        SELECT * INTO v_product FROM public.products WHERE id = v_item.product_id FOR UPDATE;
        
        v_stock_before := v_product.base_stock_quantity;
        v_stock_after := v_stock_before + v_item.quantity_base;

        UPDATE public.products SET base_stock_quantity = v_stock_after, updated_at = NOW() WHERE id = v_product.id;

        INSERT INTO public.stock_movements (
            product_id, movement_type, reference_type, reference_id,
            qty_change_base, stock_before_base, stock_after_base,
            cost_price_snapshot, created_by
        ) VALUES (
            v_product.id, 'Return', 'CANCEL_SALE', p_sale_id,
            v_item.quantity_base, v_stock_before, v_stock_after,
            v_product.cost_price, p_user_id
        );
    END LOOP;

    RETURN jsonb_build_object('success', true, 'sale_id', p_sale_id);
END;
$$;

-- 7. Triggers for timestamps
DROP TRIGGER IF EXISTS set_timestamp ON public.sales;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.sales FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.customer_payments;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.customer_payments FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.quotations;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.quotations FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

-- 8. Enable RLS and Restrict Access
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON public.products;
CREATE POLICY "Enable read access for all authenticated users" ON public.products FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON public.sales;
CREATE POLICY "Enable read access for all authenticated users" ON public.sales FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON public.sale_items;
CREATE POLICY "Enable read access for all authenticated users" ON public.sale_items FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON public.stock_movements;
CREATE POLICY "Enable read access for all authenticated users" ON public.stock_movements FOR SELECT TO authenticated USING (true);
