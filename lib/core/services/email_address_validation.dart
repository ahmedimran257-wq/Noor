/// Shared email validation for account entry points.
///
/// This is intentionally a denylist, not an allowlist: legitimate personal
/// and business domains remain supported while known disposable providers are
/// rejected. The same domains are seeded for the server-side Auth Hook.
enum EmailAddressError { missing, invalid, disposable }

class EmailAddressValidation {
  EmailAddressValidation._();

  static const temporaryEmailMessage =
      'Temporary or disposable email addresses are not allowed. Please use a real personal email address.';

  static const Set<String> _disposableDomains = {
    '10minutemail.com',
    '10minutemail.net',
    'dispostable.com',
    'emailondeck.com',
    'fakeinbox.com',
    'getnada.com',
    'grr.la',
    'guerrillamail.com',
    'guerrillamail.net',
    'guerrillamail.org',
    'harakirimail.com',
    'maildrop.cc',
    'mailinator.com',
    'mailinator.net',
    'minuteinbox.com',
    'moakt.com',
    'sharklasers.com',
    'spam4.me',
    'temp-mail.io',
    'temp-mail.org',
    'tempail.com',
    'tempmail.com',
    'throwawaymail.com',
    'trashmail.com',
    'yopmail.com',
    'yopmail.fr',
  };

  static String normalize(String value) => value.trim().toLowerCase();

  static EmailAddressError? validate(String value) {
    final email = normalize(value);
    if (email.isEmpty) return EmailAddressError.missing;

    final parts = email.split('@');
    if (parts.length != 2 ||
        parts.first.isEmpty ||
        parts.first.length > 64 ||
        !_isValidDomain(parts.last)) {
      return EmailAddressError.invalid;
    }

    if (isDisposableDomain(parts.last)) return EmailAddressError.disposable;
    return null;
  }

  static bool isDisposableDomain(String domain) {
    final normalizedDomain = domain.trim().toLowerCase();
    return _disposableDomains.any(
      (blocked) =>
          normalizedDomain == blocked || normalizedDomain.endsWith('.$blocked'),
    );
  }

  static bool _isValidDomain(String domain) {
    if (domain.length > 253 || !domain.contains('.')) return false;
    return RegExp(
      r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
    ).hasMatch(domain);
  }
}
