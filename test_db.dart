
import 'package:supabase/supabase.dart';
import 'lib/app/env.dart';

void main() async {
  final client = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
  try {
    final res = await client.from('customers').select().limit(1);
    print('Customers fetch success');
  } catch (e) {
    print('Error: \');
  }
}

