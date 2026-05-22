-- ============================================================
-- Migration 006: Payment Processing RPCs
-- ============================================================

-- Process a customer payment and automatically allocate to oldest unpaid invoices
CREATE OR REPLACE FUNCTION public.process_customer_payment(
    p_customer_id UUID,
    p_payment_method_id UUID,
    p_amount NUMERIC,
    p_note TEXT,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payment_id UUID;
    v_remaining_amount NUMERIC := p_amount;
    v_sale RECORD;
    v_allocate_amount NUMERIC;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'invalid_amount: Payment amount must be greater than zero.';
    END IF;

    -- 1. Insert the payment record
    INSERT INTO public.customer_payments (customer_id, payment_method_id, amount, note, created_by)
    VALUES (p_customer_id, p_payment_method_id, p_amount, p_note, p_user_id)
    RETURNING id INTO v_payment_id;

    -- 2. Fetch all unpaid or partially paid sales for this customer, oldest first
    FOR v_sale IN 
        SELECT id, balance_due 
        FROM public.sales 
        WHERE customer_id = p_customer_id 
          AND balance_due > 0 
          AND sale_status = 'Completed'
        ORDER BY created_at ASC 
        FOR UPDATE
    LOOP
        IF v_remaining_amount <= 0 THEN
            EXIT;
        END IF;

        IF v_remaining_amount >= v_sale.balance_due THEN
            v_allocate_amount := v_sale.balance_due;
        ELSE
            v_allocate_amount := v_remaining_amount;
        END IF;

        -- Create allocation record
        INSERT INTO public.customer_payment_allocations (customer_payment_id, sale_id, allocated_amount)
        VALUES (v_payment_id, v_sale.id, v_allocate_amount);

        -- Update the sale's balances
        UPDATE public.sales
        SET 
            amount_paid = amount_paid + v_allocate_amount,
            balance_due = balance_due - v_allocate_amount,
            payment_status = CASE 
                WHEN (balance_due - v_allocate_amount) <= 0 THEN 'Paid'
                ELSE 'Partially Paid'
            END,
            updated_at = NOW()
        WHERE id = v_sale.id;

        v_remaining_amount := v_remaining_amount - v_allocate_amount;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'payment_id', v_payment_id, 'unallocated_amount', v_remaining_amount);
END;
$$;


-- Process a supplier payment and automatically allocate to oldest unpaid GRNs/Purchase Orders
CREATE OR REPLACE FUNCTION public.process_supplier_payment(
    p_supplier_id UUID,
    p_payment_method_id UUID,
    p_amount NUMERIC,
    p_note TEXT,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_payment_id UUID;
    v_remaining_amount NUMERIC := p_amount;
    v_po RECORD;
    v_allocate_amount NUMERIC;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'invalid_amount: Payment amount must be greater than zero.';
    END IF;

    -- 1. Insert the payment record
    INSERT INTO public.supplier_payments (supplier_id, payment_method_id, amount, note, created_by)
    VALUES (p_supplier_id, p_payment_method_id, p_amount, p_note, p_user_id)
    RETURNING id INTO v_payment_id;

    -- 2. Fetch all unpaid or partially paid purchase orders for this supplier, oldest first
    -- Assuming balance_due exists on purchase_orders. Let's check or use grand_total - paid.
    -- Wait, our purchase_orders table has `amount_paid` and `balance_due` from migration 004!
    FOR v_po IN 
        SELECT id, balance_due 
        FROM public.purchase_orders 
        WHERE supplier_id = p_supplier_id 
          AND balance_due > 0 
          AND status IN ('Received', 'Partially Received')
        ORDER BY created_at ASC 
        FOR UPDATE
    LOOP
        IF v_remaining_amount <= 0 THEN
            EXIT;
        END IF;

        IF v_remaining_amount >= v_po.balance_due THEN
            v_allocate_amount := v_po.balance_due;
        ELSE
            v_allocate_amount := v_remaining_amount;
        END IF;

        -- Create allocation record
        INSERT INTO public.supplier_payment_allocations (supplier_payment_id, purchase_order_id, allocated_amount)
        VALUES (v_payment_id, v_po.id, v_allocate_amount);

        -- Update the PO's balances
        UPDATE public.purchase_orders
        SET 
            amount_paid = amount_paid + v_allocate_amount,
            balance_due = balance_due - v_allocate_amount,
            payment_status = CASE 
                WHEN (balance_due - v_allocate_amount) <= 0 THEN 'Paid'
                ELSE 'Partially Paid'
            END,
            updated_at = NOW()
        WHERE id = v_po.id;

        v_remaining_amount := v_remaining_amount - v_allocate_amount;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'payment_id', v_payment_id, 'unallocated_amount', v_remaining_amount);
END;
$$;

-- Create a quotation
CREATE OR REPLACE FUNCTION public.create_quotation(
    p_customer_id UUID,
    p_subtotal NUMERIC,
    p_discount NUMERIC,
    p_tax_amount NUMERIC,
    p_grand_total NUMERIC,
    p_items JSONB,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quotation_id UUID;
    v_invoice_no TEXT;
    v_date_part TEXT;
    v_seq INTEGER;
    v_item RECORD;
    v_pu RECORD;
BEGIN
    -- Generate quotation number
    v_date_part := TO_CHAR(NOW(), 'YYYYMMDD');
    SELECT COUNT(*) + 1 INTO v_seq FROM public.quotations WHERE invoice_no LIKE 'QT-' || v_date_part || '-%';
    v_invoice_no := 'QT-' || v_date_part || '-' || LPAD(v_seq::TEXT, 4, '0');

    INSERT INTO public.quotations (
        customer_id, invoice_no, subtotal, discount, tax_amount, grand_total,
        status, created_by
    ) VALUES (
        p_customer_id, v_invoice_no, p_subtotal, p_discount, p_tax_amount, p_grand_total,
        'Draft', p_user_id
    ) RETURNING id INTO v_quotation_id;

    -- Insert Items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        SELECT * INTO v_pu FROM public.product_units WHERE id = (v_item->>'product_unit_id')::UUID;
        
        INSERT INTO public.quotation_items (
            quotation_id, product_id, product_unit_id, quantity, 
            base_quantity_multiplier_snapshot, quantity_base, unit_price, discount, line_total
        ) VALUES (
            v_quotation_id, (v_item->>'product_id')::UUID, v_pu.id, (v_item->>'quantity')::INTEGER,
            v_pu.base_quantity_multiplier, ((v_item->>'quantity')::INTEGER * v_pu.base_quantity_multiplier),
            (v_item->>'unit_price')::NUMERIC, (v_item->>'discount')::NUMERIC, (v_item->>'line_total')::NUMERIC
        );
    END LOOP;

    RETURN jsonb_build_object('success', true, 'quotation_id', v_quotation_id, 'invoice_no', v_invoice_no);
END;
$$;
