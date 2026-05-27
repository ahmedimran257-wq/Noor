// lib/core/utils/content_filter.dart
// ============================================================
// NOOR — Content Filter (Shared)
// Detects and redacts contact information, social media handles,
// external links, and phone numbers from user-generated text.
//
// Used in:
//   • AboutYourselfScreen — bio validation
//   • ChatCubit — real-time message filtering (T2)
//   • InterestsCubit — interest note validation (D1)
// ============================================================

class ContentFilter {
  ContentFilter._();

  // ── Patterns ──────────────────────────────────────────────

  static final _phone = RegExp(r'(\+?\d[\d\s\-\.]{6,}\d)');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final _url = RegExp(r'(https?://|www\.)\S+');
  static final _social = RegExp(
    r'(@[\w.]+|(?:instagram|insta|snap|snapchat|whatsapp|telegram|'
    r'facebook|fb|twitter|tiktok|linkedin)[\s.:/@]*[\w.]+)',
    caseSensitive: false,
  );

  // ── Validation (returns error message or null) ────────────

  /// Returns a human-readable error message if [text] contains
  /// prohibited contact info, or null if the text is clean.
  static String? validate(String text) {
    if (_phone.hasMatch(text)) {
      return 'Phone numbers cannot be shared here.';
    }
    if (_email.hasMatch(text)) {
      return 'Email addresses cannot be shared here.';
    }
    if (_url.hasMatch(text)) {
      return 'External links cannot be shared here.';
    }
    if (_social.hasMatch(text)) {
      return 'Social media handles cannot be shared here.';
    }
    return null;
  }

  /// Returns true if [text] contains any prohibited content.
  static bool hasViolation(String text) => validate(text) != null;

  // ── Redaction (replaces violations inline) ────────────────

  /// Replaces all detected contact info with `[removed]`.
  /// Safe to call on clean text (no-op).
  static String redact(String text) {
    var result = text;
    result = result.replaceAll(_phone, '[contact info removed]');
    result = result.replaceAll(_email, '[contact info removed]');
    result = result.replaceAll(_url, '[link removed]');
    result = result.replaceAll(_social, '[contact info removed]');
    return result;
  }
}
