
import 'package:supabase/supabase.dart';
import 'lib/app/env.dart';

void main() async {
  final client = SupabaseClient(Env.supabaseUrl, Env.supabaseAnonKey);
  try {
    final res = await client.rpc('execute_sql', params: {
      'query': 'SELECT column_name, is_nullable FROM information_schema.columns WHERE table_name = ''sales'';'
    });
    print(res);
  } catch (e) {
    print(e);
  }
}

