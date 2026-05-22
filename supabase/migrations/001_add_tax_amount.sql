-- ============================================================
-- Migration: Add tax_amount support to create_sale RPC
-- Run this in the Supabase SQL Editor
-- ============================================================

-- 1. Add tax_amount column to sales table (nullable, default 0)
ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0;

-- 2. Replace create_sale() to accept and store tax_amount
CREATE OR REPLACE FUNCTION public.create_sale(
  items           JSONB,
  payment_method  TEXT,
  bill_discount   NUMERIC DEFAULT 0,
  tax_amount      NUMERIC DEFAULT 0
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

  -- 5. Create sale id
  v_sale_id := gen_random_uuid();

  -- 6. Process each item
  FOR v_item IN SELECT * FROM jsonb_array_elements(items) LOOP

    -- Fetch and lock product
    SELECT * INTO v_product FROM public.products
    WHERE id = (v_item->>'product_id')::UUID
      AND status = 'Active'
    FOR UPDATE;

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

  -- 7. Calculate grand total (subtotal - discount + tax)
  v_grand_total := v_subtotal - COALESCE(bill_discount, 0) + COALESCE(tax_amount, 0);
  IF v_grand_total < 0 THEN
    v_grand_total := 0;
  END IF;

  -- 8. Insert final sale record
  INSERT INTO public.sales (
    id, invoice_no, staff_id, subtotal, discount, tax_amount, grand_total, payment_method, status
  ) VALUES (
    v_sale_id, v_invoice_no, v_user_id,
    v_subtotal,
    COALESCE(bill_discount, 0),
    COALESCE(tax_amount, 0),
    v_grand_total,
    payment_method,
    'Completed'
  );

  -- 9. Return receipt data
  RETURN jsonb_build_object(
    'sale_id',        v_sale_id,
    'invoice_no',     v_invoice_no,
    'staff_name',     v_profile.full_name,
    'subtotal',       v_subtotal,
    'discount',       COALESCE(bill_discount, 0),
    'tax_amount',     COALESCE(tax_amount, 0),
    'grand_total',    v_grand_total,
    'payment_method', payment_method,
    'status',         'Completed',
    'created_at',     NOW(),
    'items',          v_result_items
  );

END;
$$;
