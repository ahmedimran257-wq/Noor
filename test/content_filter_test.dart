import 'package:flutter_test/flutter_test.dart';
import 'package:mithaq/core/utils/content_filter.dart';

void main() {
  group('ContentFilter Tests', () {
    test('Clean text passes validation', () {
      expect(ContentFilter.hasViolation('Hello, I am looking for a partner.'), isFalse);
      expect(ContentFilter.validate('Hello, I am looking for a partner.'), isNull);
    });

    test('Standard phone numbers fail validation', () {
      expect(ContentFilter.hasViolation('My number is +1234567890'), isTrue);
      expect(ContentFilter.hasViolation('Call me at 07123456789'), isTrue);
    });

    test('Dot-separated phone numbers fail validation (A3.1)', () {
      expect(ContentFilter.hasViolation('Reach me at 555.123.4567'), isTrue);
      expect(ContentFilter.validate('Reach me at 555.123.4567'), equals('Phone numbers cannot be shared here.'));
    });

    test('Short phone numbers fail validation (A3.1)', () {
      expect(ContentFilter.hasViolation('call me 555 1234'), isTrue);
      expect(ContentFilter.validate('call me 555 1234'), equals('Phone numbers cannot be shared here.'));
    });

    test('Redaction replaces phone numbers correctly', () {
      const text = 'My number is 555.123.4567 and my friend is at 555 1234';
      final redacted = ContentFilter.redact(text);
      expect(redacted, contains('[contact info removed]'));
      expect(redacted.contains('555.123.4567'), isFalse);
      expect(redacted.contains('555 1234'), isFalse);
    });
  });
}
