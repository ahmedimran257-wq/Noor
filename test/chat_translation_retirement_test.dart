import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat translation is removed and legacy calls fail closed', () {
    final chat = File(
      'lib/features/home/screens/chat_screen.dart',
    ).readAsStringSync();
    final cubit = File(
      'lib/core/cubits/chat/chat_cubit.dart',
    ).readAsStringSync();
    final endpoint = File(
      'supabase/functions/translate-message/index.ts',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/259_guardian_access_lifecycle_and_retire_translation.sql',
    ).readAsStringSync();

    expect(chat, isNot(contains('onTranslate')));
    expect(chat, isNot(contains('_translateWithPrivacyNotice')));
    expect(cubit, isNot(contains('TranslationService')));
    expect(endpoint, contains('chat_translation_removed'));
    expect(endpoint, isNot(contains('MYMEMORY')));
    expect(endpoint, isNot(contains("from('messages')")));
    expect(migration,
        contains('REVOKE ALL ON FUNCTION public.store_message_translation'));
    expect(migration, contains("SET translations = '{}'::jsonb"));
  });
}
