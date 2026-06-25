// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  print('Setting up mock SharedPreferences...');
  SharedPreferences.setMockInitialValues({});
  
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://jukpscfxzwttgtxvrbmj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1a3BzY2Z4end0dGd0eHZyYm1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE0MDQxMDcsImV4cCI6MjA5Njk4MDEwN30.P-mn2v2_NYHg2g5twxCg_RMNG6wQwooQ2U1C6lvqCy0',
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
