import 'package:supabase/supabase.dart';
import 'lib/app/env.dart';

void main() async {
  final client = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
  try {
    print('Checking purchase_orders table...');
    await client.from('purchase_orders').select('id').limit(1);
    print('purchase_orders OK!');

    print('Checking products base_unit_id...');
    await client.from('products').select('base_unit_id').limit(1);
    print('products.base_unit_id OK!');

    print('Checking sales customer_id...');
    await client.from('sales').select('customer_id').limit(1);
    print('sales.customer_id OK!');

    print('Checking customer_payments table...');
    await client.from('customer_payments').select('id').limit(1);
    print('customer_payments OK!');

    print('Checking receive_grn RPC...');
    try {
      await client.rpc('receive_grn', params: {'p_grn_id': '00000000-0000-0000-0000-000000000000', 'p_user_id': '00000000-0000-0000-0000-000000000000'});
    } catch (e) {
      if (e.toString().contains('function receive_grn')) {
        print('RPC receive_grn MISSING!');
      } else {
        print('RPC receive_grn EXISTS (failed with expected UUID error): \$e');
      }
    }

    print('ALL CHECKS COMPLETED SUCCESSFULLY!');
  } catch (e) {
    print('ERROR: \$e');
  }
}
