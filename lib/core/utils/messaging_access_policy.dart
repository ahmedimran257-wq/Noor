/// Client-side presentation rules for Silarah messaging.
///
/// Supabase remains authoritative. These helpers only prevent the UI from
/// presenting a men's Premium gate to a confirmed female account.
abstract final class MessagingAccessPolicy {
  static String? normalizedGender(String? gender) {
    final normalized = gender?.trim().toLowerCase();
    return normalized == 'male' || normalized == 'female' ? normalized : null;
  }

  /// Only an explicitly female account receives free messaging. Unknown
  /// values fail closed instead of becoming a subscription bypass.
  static bool hasFreeMessaging(String? gender) =>
      normalizedGender(gender) == 'female';
}
