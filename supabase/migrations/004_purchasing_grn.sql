-- ============================================================
-- Migration 004: Purchasing & GRN (Hardware Retail POS)
-- ============================================================

-- 1. Purchase Orders
CREATE TABLE IF NOT EXISTS public.purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id),
    po_no TEXT UNIQUE NOT NULL,
    po_status TEXT NOT NULL CHECK (po_status IN ('Draft', 'Ordered', 'Cancelled')),
    receiving_status TEXT NOT NULL DEFAULT 'Pending' CHECK (receiving_status IN ('Pending', 'Partially Received', 'Fully Received')),
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    tax NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
    grand_total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (grand_total >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    product_unit_id UUID NOT NULL REFERENCES public.product_units(id),
    ordered_qty INTEGER NOT NULL CHECK (ordered_qty > 0),
    ordered_qty_base INTEGER NOT NULL CHECK (ordered_qty_base > 0),
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),
    unit_cost_base NUMERIC(12,2) NOT NULL CHECK (unit_cost_base >= 0),
    line_total NUMERIC(12,2) NOT NULL CHECK (line_total >= 0)
);

-- 2. Goods Received Notes (GRN)
CREATE TABLE IF NOT EXISTS public.goods_received_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    purchase_order_id UUID NOT NULL REFERENCES public.purchase_orders(id),
    grn_no TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('Draft', 'Posted', 'Cancelled')),
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.goods_received_note_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    grn_id UUID NOT NULL REFERENCES public.goods_received_notes(id) ON DELETE CASCADE,
    purchase_order_item_id UUID NOT NULL REFERENCES public.purchase_order_items(id),
    product_id UUID NOT NULL REFERENCES public.products(id),
    product_unit_id UUID NOT NULL REFERENCES public.product_units(id),
    received_qty INTEGER NOT NULL CHECK (received_qty > 0),
    received_qty_base INTEGER NOT NULL CHECK (received_qty_base > 0),
    unit_cost NUMERIC(12,2) NOT NULL CHECK (unit_cost >= 0),
    unit_cost_base NUMERIC(12,2) NOT NULL CHECK (unit_cost_base >= 0)
);

-- 3. Supplier Payments & Allocations
CREATE TABLE IF NOT EXISTS public.supplier_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id),
    payment_method_id UUID NOT NULL REFERENCES public.payment_methods(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.supplier_payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_payment_id UUID NOT NULL REFERENCES public.supplier_payments(id) ON DELETE CASCADE,
    purchase_order_id UUID NOT NULL REFERENCES public.purchase_orders(id),
    allocated_amount NUMERIC(12,2) NOT NULL CHECK (allocated_amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Supplier Ledger View
CREATE OR REPLACE VIEW public.supplier_ledger_view AS
SELECT 
    s.id AS supplier_id,
    s.name,
    COALESCE(po.total_invoiced, 0) AS invoice_total,
    COALESCE(sp.total_paid, 0) AS payment_total,
    (COALESCE(po.total_invoiced, 0) - COALESCE(sp.total_paid, 0)) AS balance
FROM public.suppliers s
LEFT JOIN (
    SELECT supplier_id, SUM(grand_total) as total_invoiced 
    FROM public.purchase_orders 
    WHERE po_status != 'Cancelled'
    GROUP BY supplier_id
) po ON po.supplier_id = s.id
LEFT JOIN (
    SELECT supplier_id, SUM(amount) as total_paid 
    FROM public.supplier_payments 
    GROUP BY supplier_id
) sp ON sp.supplier_id = s.id;

-- 5. RPC: Receive GRN (Handles Transactional WAC)
-- This function marks a GRN as 'Posted', calculates WAC, updates stock, and logs stock_movements.
CREATE OR REPLACE FUNCTION public.receive_grn(
    p_grn_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_grn RECORD;
    v_item RECORD;
    v_product RECORD;
    v_new_cost NUMERIC(12,2);
    v_stock_before INTEGER;
    v_stock_after INTEGER;
    v_total_ordered INTEGER;
    v_total_received INTEGER;
BEGIN
    -- 1. Fetch GRN
    SELECT * INTO v_grn FROM public.goods_received_notes WHERE id = p_grn_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'grn_not_found: GRN % not found', p_grn_id;
    END IF;
    IF v_grn.status = 'Posted' THEN
        RAISE EXCEPTION 'grn_already_posted: GRN % is already posted', p_grn_id;
    END IF;

    -- 2. Process Items
    FOR v_item IN 
        SELECT gi.*, pi.ordered_qty_base
        FROM public.goods_received_note_items gi
        JOIN public.purchase_order_items pi ON pi.id = gi.purchase_order_item_id
        WHERE gi.grn_id = p_grn_id
    LOOP
        -- Fetch current product state
        SELECT * INTO v_product FROM public.products WHERE id = v_item.product_id FOR UPDATE;
        
        v_stock_before := v_product.base_stock_quantity;
        v_stock_after := v_stock_before + v_item.received_qty_base;
        
        -- Calculate WAC (Weighted Average Cost)
        -- New Cost = ((Old Qty * Old Cost) + (Received Qty * Purchase Cost)) / (Old Qty + Received Qty)
        IF (v_stock_after) > 0 THEN
            v_new_cost := ((v_stock_before * v_product.cost_price) + (v_item.received_qty_base * v_item.unit_cost_base)) / v_stock_after;
        ELSE
            v_new_cost := v_item.unit_cost_base;
        END IF;

        -- Update Product
        UPDATE public.products 
        SET base_stock_quantity = v_stock_after,
            cost_price = v_new_cost,
            updated_at = NOW()
        WHERE id = v_product.id;

        -- Log Stock Movement
        INSERT INTO public.stock_movements (
            product_id, movement_type, reference_type, reference_id,
            qty_change_base, stock_before_base, stock_after_base,
            cost_price_snapshot, created_by
        ) VALUES (
            v_product.id, 'GRN', 'GRN', p_grn_id,
            v_item.received_qty_base, v_stock_before, v_stock_after,
            v_new_cost, p_user_id
        );
    END LOOP;

    -- 3. Mark GRN as Posted
    UPDATE public.goods_received_notes
    SET status = 'Posted',
        updated_at = NOW()
    WHERE id = p_grn_id;

    -- 4. Re-evaluate Purchase Order Receiving Status
    SELECT COALESCE(SUM(ordered_qty_base), 0) INTO v_total_ordered
    FROM public.purchase_order_items WHERE purchase_order_id = v_grn.purchase_order_id;
    
    SELECT COALESCE(SUM(gi.received_qty_base), 0) INTO v_total_received
    FROM public.goods_received_note_items gi
    JOIN public.goods_received_notes g ON g.id = gi.grn_id
    WHERE g.purchase_order_id = v_grn.purchase_order_id AND g.status = 'Posted';

    IF v_total_received >= v_total_ordered THEN
        UPDATE public.purchase_orders SET receiving_status = 'Fully Received', updated_at = NOW() WHERE id = v_grn.purchase_order_id;
    ELSIF v_total_received > 0 THEN
        UPDATE public.purchase_orders SET receiving_status = 'Partially Received', updated_at = NOW() WHERE id = v_grn.purchase_order_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'grn_id', p_grn_id);
END;
$$;

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON public.purchase_orders(supplier_id);
CREATE INDEX IF NOT EXISTS idx_goods_received_notes_purchase_order_id ON public.goods_received_notes(purchase_order_id);

-- Triggers for timestamps
DROP TRIGGER IF EXISTS set_timestamp ON public.purchase_orders;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.purchase_orders FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.goods_received_notes;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.goods_received_notes FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();

DROP TRIGGER IF EXISTS set_timestamp ON public.supplier_payments;
CREATE TRIGGER set_timestamp BEFORE UPDATE ON public.supplier_payments FOR EACH ROW EXECUTE FUNCTION trigger_set_timestamp();
