
import 'package:supabase/supabase.dart';
import 'lib/app/env.dart';

void main() async {
  final client = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
  try {
    final response = await client.rpc('get_table_schema', params: {'table_name': 'products'});
    print(response);
  } catch (e) {
    print('Failed to call rpc, error: \');
  }
}

