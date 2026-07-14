import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/email_address_validation.dart';

void main() {
  group('EmailAddressValidation', () {
    test('normalizes real personal and business email addresses', () {
      expect(
        EmailAddressValidation.normalize('  Person@Example.COM '),
        'person@example.com',
      );
      expect(EmailAddressValidation.validate('person@gmail.com'), isNull);
      expect(EmailAddressValidation.validate('member@familybusiness.co.in'),
          isNull);
    });

    test('rejects missing and malformed email addresses', () {
      expect(
        EmailAddressValidation.validate(''),
        EmailAddressError.missing,
      );
      expect(
        EmailAddressValidation.validate('not-an-email'),
        EmailAddressError.invalid,
      );
    });

    test('rejects known disposable domains and their subdomains', () {
      expect(
        EmailAddressValidation.validate('member@mailinator.com'),
        EmailAddressError.disposable,
      );
      expect(
        EmailAddressValidation.validate('member@inbox.guerrillamail.com'),
        EmailAddressError.disposable,
      );
      expect(
        EmailAddressValidation.validate('member@10minutemail.com'),
        EmailAddressError.disposable,
      );
    });
  });
}
