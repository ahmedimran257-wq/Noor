import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gender integrity migration', () {
    late final String sql;

    setUpAll(() {
      sql = File('supabase/migrations/069_gender_integrity_lock.sql')
          .readAsStringSync();
    });

    test('backfills public users from existing profiles', () {
      expect(sql, contains('UPDATE public.users u'));
      expect(sql, contains('SET gender = p.gender'));
      expect(sql, contains('FROM public.profiles p'));
      expect(sql, contains('AND u.gender IS NULL'));
      expect(sql, contains("AND p.gender IN ('male', 'female')"));
    });

    test('blocks client-side gender changes after first set', () {
      expect(
        sql,
        contains(
          'CREATE OR REPLACE FUNCTION public.prevent_user_gender_change()',
        ),
      );
      expect(sql, contains('OLD.gender IS NOT NULL'));
      expect(sql, contains('NEW.gender IS DISTINCT FROM OLD.gender'));
      expect(sql, contains("auth.role() = 'service_role'"));
      expect(sql, contains("public.is_active_admin(ARRAY['super_admin'])"));
      expect(sql, contains('CREATE TRIGGER trg_prevent_user_gender_change'));
      expect(sql, contains('BEFORE UPDATE OF gender ON public.users'));
    });

    test('keeps profile gender enforced from public users safely', () {
      expect(
        sql,
        contains('CREATE OR REPLACE FUNCTION public.enforce_profile_gender()'),
      );
      expect(sql, contains('UPDATE public.users'));
      expect(sql, contains('SET gender = NEW.gender'));
      expect(sql, contains('WHERE id = NEW.user_id'));
      expect(sql, contains('AND gender IS NULL'));
      expect(sql, contains('NEW.gender := v_user_gender'));
    });
  });
}
