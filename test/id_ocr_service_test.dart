import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/services/id_ocr_service.dart';

void main() {
  group('IdOcrService parsing', () {
    test('extracts labelled day-first dates of birth', () {
      final dob = IdOcrService.extractDobFromText('DOB: 14/06/1996');
      expect(dob, DateTime(1996, 6, 14));
    });

    test('extracts ISO dates and rejects invalid dates', () {
      expect(
        IdOcrService.extractDobFromText('Date of birth: 1998-02-01'),
        DateTime(1998, 2, 1),
      );
      expect(IdOcrService.extractDobFromText('DOB: 31/02/2001'), isNull);
    });

    test('calculates the adult threshold without uploading a document', () {
      expect(
          IdOcrService.ageOn(DateTime(2008, 6, 22),
              onDate: DateTime(2026, 6, 21)),
          17);
      expect(
          IdOcrService.ageOn(DateTime(2008, 6, 21),
              onDate: DateTime(2026, 6, 21)),
          18);
    });

    test('extracts an explicitly labelled name', () {
      expect(
        IdOcrService.extractNameFromText('Name: Aisha Rahman\nDOB: 01/01/1994'),
        'Aisha Rahman',
      );
    });
  });
}
