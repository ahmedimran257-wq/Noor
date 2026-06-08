import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  print('Setting up mock SharedPreferences...');
  SharedPreferences.setMockInitialValues({});
  
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://wmkoeahcqfbigglhsxaa.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indta29lYWhjcWZiaWdnbGhzeGFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5MTkyNjgsImV4cCI6MjA5MTQ5NTI2OH0.aTZHHcLsrOv5m0xtA8Xlb9G7M7JNs_1YiST49C6PlP8',
  );
  final client = Supabase.instance.client;
  print('Supabase initialized.');
  
  try {
    print('1. Querying users.messaging_suspended_until...');
    final response = await client.from('users').select('messaging_suspended_until').limit(1);
    print('Success: $response');
  } catch (e) {
    print('Error: $e');
  }

  try {
    print('2. Querying profiles.onboarding_step...');
    final response = await client.from('profiles').select('onboarding_step, guardian_mode, gender').limit(1);
    print('Success: $response');
  } catch (e) {
    print('Error: $e');
  }
}
