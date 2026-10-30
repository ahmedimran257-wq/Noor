import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Unpinned, Supabase runs an edge function near the caller (Mumbai for
  // Indian members) while the database is in Tokyo, so every internal auth,
  // database and storage call crossed regions. Each invoke must pin.
  test('every edge function invoke runs in the database region', () {
    final offenders = <String>[];
    var invokes = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final calls = RegExp(r'functions\.invoke\(([^;]*?)\);', dotAll: true)
          .allMatches(source);
      for (final call in calls) {
        invokes++;
        if (!call
            .group(1)!
            .contains('region: SupabaseService.functionsRegion')) {
          offenders.add(file.path);
        }
      }
    }
    expect(invokes, greaterThan(0));
    expect(offenders, isEmpty);
  });

  test('builds name the region explicitly', () {
    final example = File('config/dart_defines.example.json').readAsStringSync();
    expect(example, contains('"SUPABASE_FUNCTIONS_REGION"'));
  });
}
