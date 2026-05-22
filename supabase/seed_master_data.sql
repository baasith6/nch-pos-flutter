-- ============================================================
-- Seed Data: Master Data Foundation (Hardware Retail POS)
-- ============================================================

-- 1. Seed Units
INSERT INTO public.units (name, short_code) VALUES
('Piece', 'PCS'),
('Box', 'BOX'),
('Kilogram', 'KG'),
('Liter', 'L'),
('Meter', 'M'),
('Packet', 'PKT'),
('Roll', 'ROLL')
ON CONFLICT DO NOTHING;

-- 2. Seed Brands
INSERT INTO public.brands (name) VALUES
('Nippon Paint'),
('Dulux'),
('Bosch'),
('Makita'),
('Stanley'),
('Generic')
ON CONFLICT DO NOTHING;

-- 3. Seed Categories
INSERT INTO public.categories (name) VALUES
('Paints & Accessories'),
('Power Tools'),
('Hand Tools'),
('Plumbing & Pipes'),
('Electrical & Wiring'),
('Fasteners & Screws'),
('Safety Gear')
ON CONFLICT DO NOTHING;

-- 4. Default Customers and Suppliers
INSERT INTO public.customers (name, phone, credit_limit) VALUES
('Walk-in Customer', '0000000000', 0)
ON CONFLICT DO NOTHING;

INSERT INTO public.suppliers (name, contact_name, credit_limit) VALUES
('General Hardware Supplier', 'Admin', 0)
ON CONFLICT DO NOTHING;
