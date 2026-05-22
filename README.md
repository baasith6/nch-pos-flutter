# FlutterPOS

A production-ready Point of Sale (POS) application built with Flutter (Riverpod) and Supabase, tailored for single-store retail environments (one admin, one staff).

## 🚀 Key Features Implemented

### 1. Sales & Checkout
* **Dynamic Checkout:** Cart manages products, quantities, line totals, bill discounts, and tax computation. 
* **Barcode Scanner:** Integrated `mobile_scanner` via a bottom sheet to instantly search and add products using the device camera.
* **Tax Handling:** Support for shop-wide tax percentage, correctly persisting to the database via custom Supabase RPCs.
* **Discount Validation:** Disallows discounts greater than the subtotal, clamping invalid inputs automatically.
* **Cash Tendered Validation:** Checkout is blocked if cash tendered is less than the grand total. Shows live change due.
* **Dynamic Payment Methods:** Payment types (Cash, Card, Bank Transfer, etc.) are fetched directly from the database and can be toggled by the Admin.
* **Hold / Park Sale:** Ability to "park" a current checkout session to memory and restore it later, allowing staff to serve other customers in the meantime.

### 2. Receipt Generation & Sharing
* **PDF Receipts:** Generates an 80mm thermal-printer optimized PDF receipt using the `pdf` package.
* **Print/Share:** Built-in sharing (WhatsApp, Email) and system print dialog functionality via the `printing` package.

### 3. Order Management
* **Cancel & Refund:** Admins have exclusive access to "Cancel Sale" and "Mark Refunded" buttons on the Sale Detail screen.
* **Status Tracking:** Sales are correctly tracked as `Completed`, `Cancelled`, or `Refunded`.

### 4. Inventory & Stock Management
* **Image Uploads:** Product creation/editing supports gallery image picking and uploading to Supabase Storage, with fallback placeholders.
* **Stock History Tracking:** A dedicated `Stock Adjustment History` screen visualizes stock movements (in/out) with color-coded arrows (green for additions, red for deductions) and staff tracking.

### 5. Reporting & Analytics
* **Date-Range Filtering:** Flexible date filtering (Today, This Week, This Month, Custom) available on the Reports screen.
* **Granular Reports:** Automatically cascades date filters down to Sales Summary, Product Sales, Staff Sales, Payment Methods, and Profit sheets.

### 6. Admin vs. Staff Roles
* **Role-based Access Control:** `Admin` users can access settings, payment methods, reports, and sale cancellations. `Staff` accounts are limited to the POS and basic history screens.

---

## 🛠 Tech Stack
* **Frontend:** Flutter (Dart)
* **State Management:** Riverpod (`flutter_riverpod`)
* **Backend:** Supabase (PostgreSQL, Authentication, Storage, Edge Functions)
* **Local Storage:** `shared_preferences`

---

## 📦 Database & Migrations

The application relies heavily on Supabase RPCs (Remote Procedure Calls) to ensure transactional atomicity during checkouts. 

### Custom RPCs
* `create_sale`: An atomic function that verifies active users, checks stock quantities, deducts stock, calculates final totals (including tax and discounts), and inserts into both `sales` and `sale_items` tables sequentially. 

*(Note: The `create_sale` function explicitly manages FK constraint ordering to prevent `23503` violations).*

### Necessary SQL Migrations
Ensure you have run the following migrations in your Supabase SQL Editor:
1. `supabase/migrations/001_add_tax_amount.sql` (Adds `tax_amount` and the 4-parameter `create_sale` RPC)
2. `supabase/migrations/002_create_payment_methods.sql` (Creates dynamic payment config table)

---

## 📱 Permissions Setup (For Build)

If building the APK or IPA, the following permissions are required in the native configuration:

**Android (`android/app/src/main/AndroidManifest.xml`)**
```xml
<!-- Required for network requests & Supabase connectivity -->
<uses-permission android:name="android.permission.INTERNET"/>
<!-- Required for mobile_scanner -->
<uses-permission android:name="android.permission.CAMERA"/>
<!-- Required for product image uploads -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

**iOS (`ios/Runner/Info.plist`)**
```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan product barcodes at checkout.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is used to upload product images.</string>
```
