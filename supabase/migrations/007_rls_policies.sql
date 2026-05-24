
-- 007_rls_policies.sql
-- Add INSERT, UPDATE, DELETE policies for products, sales, sale_items, stock_movements
-- We allow all authenticated users to manage these tables.

-- PRODUCTS
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.products;
CREATE POLICY "Enable insert for authenticated users" ON public.products FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.products;
CREATE POLICY "Enable update for authenticated users" ON public.products FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.products;
CREATE POLICY "Enable delete for authenticated users" ON public.products FOR DELETE TO authenticated USING (true);

-- SALES
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.sales;
CREATE POLICY "Enable insert for authenticated users" ON public.sales FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.sales;
CREATE POLICY "Enable update for authenticated users" ON public.sales FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.sales;
CREATE POLICY "Enable delete for authenticated users" ON public.sales FOR DELETE TO authenticated USING (true);

-- SALE_ITEMS
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.sale_items;
CREATE POLICY "Enable insert for authenticated users" ON public.sale_items FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.sale_items;
CREATE POLICY "Enable update for authenticated users" ON public.sale_items FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.sale_items;
CREATE POLICY "Enable delete for authenticated users" ON public.sale_items FOR DELETE TO authenticated USING (true);

-- STOCK_MOVEMENTS
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.stock_movements;
CREATE POLICY "Enable insert for authenticated users" ON public.stock_movements FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.stock_movements;
CREATE POLICY "Enable update for authenticated users" ON public.stock_movements FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.stock_movements;
CREATE POLICY "Enable delete for authenticated users" ON public.stock_movements FOR DELETE TO authenticated USING (true);

