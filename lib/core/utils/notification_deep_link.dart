/// Converts server-owned Silarah notification links into authenticated routes.
///
/// Push notifications and Supabase Realtime notifications deliberately share
/// this resolver so their tap behavior cannot diverge.
String? notificationPathFromDeepLink(String? deepLink) {
  final link = deepLink?.trim();
  if (link == null || link.isEmpty) return null;
  if (link.startsWith('/')) return link;

  final uri = Uri.tryParse(link);
  if (uri == null || !{'silarah', 'mithaq'}.contains(uri.scheme)) return null;

  final host = uri.host;
  final path = uri.path;
  if (host == 'chat') {
    final id = path.replaceFirst('/', '');
    return id.isEmpty ? '/home?tab=2' : '/chat/$id';
  }
  if (host == 'profile' || path.startsWith('/profile')) {
    return '/home?tab=3';
  }
  if (host == 'notifications') return '/notifications';
  if (host == 'verify') return '/badge-verification';
  if (host == 'verify-identity') return '/verify';
  if (host == 'photos') return '/edit-profile?section=photos';
  if (host == 'complete-profile') return '/edit-profile';
  if (host == 'support' || host == 'help-support') return '/help-support';
  return null;
}
