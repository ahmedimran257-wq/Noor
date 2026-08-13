import 'package:url_launcher/url_launcher.dart';

import '../legal/public_site_links.dart';

/// Opens store-owned subscription and refund controls.
///
/// Billing remains authoritative in Google Play; Silarah never pretends that
/// deleting an account or changing a phone number cancels a store purchase.
abstract final class BillingPortalService {
  static Future<bool> openGooglePlaySubscriptions() => launchUrl(
        PublicSiteLinks.googlePlaySubscriptions,
        mode: LaunchMode.externalApplication,
      );

  static Future<bool> openGooglePlayRefundRequest() => launchUrl(
        PublicSiteLinks.googlePlayRefundRequest,
        mode: LaunchMode.externalApplication,
      );
}
