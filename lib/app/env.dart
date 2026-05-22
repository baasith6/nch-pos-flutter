/// Environment configuration for Supabase.
/// NEVER place the service_role key here — it belongs only in Edge Functions.
class Env {
  Env._();

  static const String supabaseUrl = 'https://qhaqitrfkieseuksjuub.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFoYXFpdHJma2llc2V1a3NqdXViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI2MDgzNzEsImV4cCI6MjA4ODE4NDM3MX0.UOK7-eB4FXx2nE1IdZfhli7Ua9Q_xmL8QwFC_jyxdMU';
}
