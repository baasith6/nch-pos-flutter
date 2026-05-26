
-- Fix create_sale RPC to handle base units properly where product_unit_id might refer to the base unit directly from units table instead of product_units table.
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
AS $$$
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
    v_multiplier INTEGER;
    v_pu_id UUID;
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
        IF NOT FOUND THEN
            v_stock_conflict := true;
            v_conflict_reason := COALESCE(v_conflict_reason || ', ', '') || 'Product not found: ' || (v_item->>'product_id');
            CONTINUE;
        END IF;

        IF (v_item->>'product_unit_id') IS NULL OR (v_item->>'product_unit_id') = '' OR (v_item->>'product_unit_id')::UUID = v_product.base_unit_id THEN
            v_multiplier := 1;
        ELSE
            SELECT * INTO v_pu FROM public.product_units WHERE id = (v_item->>'product_unit_id')::UUID;
            IF NOT FOUND THEN
                v_stock_conflict := true;
                v_conflict_reason := COALESCE(v_conflict_reason || ', ', '') || 'Product unit not found for ' || v_product.name;
                CONTINUE;
            END IF;
            v_multiplier := v_pu.base_quantity_multiplier;
        END IF;
        
        v_stock_after := COALESCE(v_product.base_stock_quantity, 0) - ((v_item->>'quantity')::INTEGER * v_multiplier);
        
        IF v_stock_after < 0 THEN
            IF p_synced_from_offline THEN
                v_stock_conflict := true;
                v_conflict_reason := COALESCE(v_conflict_reason || ', ', '') || 'Negative stock for ' || v_product.name;
            ELSE
                RAISE EXCEPTION 'insufficient_stock: Insufficient stock for product %', v_product.name;
            END IF;
        END IF;
    END LOOP;

    -- 4. Insert Sale
    INSERT INTO public.sales (
        id, invoice_no, customer_id, staff_id, subtotal, discount, tax_amount, grand_total, 
        amount_paid, balance_due, payment_status, sale_status, 
        stock_conflict, conflict_reason, synced_from_offline
    ) VALUES (
        p_sale_id, v_invoice_no, p_customer_id, p_user_id, p_subtotal, p_discount, p_tax_amount, p_grand_total,
        v_total_paid, v_balance_due, v_payment_status, 'Completed',
        v_stock_conflict, v_conflict_reason, p_synced_from_offline
    );

    -- 5. Insert Payments
    FOR v_payment IN SELECT * FROM jsonb_array_elements(p_payments) LOOP
        INSERT INTO public.sale_payments (sale_id, payment_method_id, amount)
        VALUES (
            p_sale_id, 
            (SELECT id FROM public.payment_methods WHERE name = (v_payment->>'payment_method_name') LIMIT 1),
            (v_payment->>'amount')::NUMERIC
        );
    END LOOP;

    -- 6. Insert Items & Process Stock
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT * INTO v_product FROM public.products WHERE id = (v_item->>'product_id')::UUID;
        
        IF (v_item->>'product_unit_id') IS NULL OR (v_item->>'product_unit_id') = '' OR (v_item->>'product_unit_id')::UUID = v_product.base_unit_id THEN
            v_multiplier := 1;
            v_pu_id := NULL;
        ELSE
            SELECT * INTO v_pu FROM public.product_units WHERE id = (v_item->>'product_unit_id')::UUID;
            v_multiplier := COALESCE(v_pu.base_quantity_multiplier, 1);
            v_pu_id := v_pu.id;
        END IF;
        
        v_stock_before := COALESCE(v_product.base_stock_quantity, 0);
        v_stock_after := v_stock_before - ((v_item->>'quantity')::INTEGER * v_multiplier);

        UPDATE public.products 
        SET base_stock_quantity = v_stock_after, updated_at = NOW() 
        WHERE id = v_product.id;

        INSERT INTO public.sale_items (
            sale_id, product_id, product_name, product_unit_id, quantity, 
            base_quantity_multiplier_snapshot, quantity_base, unit_price, discount, line_total
        ) VALUES (
            p_sale_id, v_product.id, v_product.name, v_pu_id, (v_item->>'quantity')::INTEGER,
            v_multiplier, ((v_item->>'quantity')::INTEGER * v_multiplier),
            (v_item->>'unit_price')::NUMERIC, (v_item->>'discount')::NUMERIC, (v_item->>'line_total')::NUMERIC
        );

        INSERT INTO public.stock_movements (
            product_id, movement_type, reference_type, reference_id,
            qty_change_base, stock_before_base, stock_after_base,
            cost_price_snapshot, created_by
        ) VALUES (
            v_product.id, 'Sale', 'SALE', p_sale_id,
            -((v_item->>'quantity')::INTEGER * v_multiplier), v_stock_before, v_stock_after,
            COALESCE(v_product.cost_price, 0), p_user_id
        );
    END LOOP;

    RETURN jsonb_build_object('success', true, 'sale_id', p_sale_id);
END;
$$$;

