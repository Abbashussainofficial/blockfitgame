import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/strings.dart';

/// Opens external links (browser, Play Store, email). Every method returns
/// `false` instead of throwing, so callers can just show a short message.
abstract final class LinkService {
  static Future<bool> openPrivacyPolicy() =>
      _open(Uri.parse(AppConfig.privacyPolicyUrl));

  /// Tries the Play Store app first, then the web listing.
  static Future<bool> openStoreListing() async =>
      await _open(Uri.parse(AppConfig.playStoreMarketUrl)) ||
      await _open(Uri.parse(AppConfig.playStoreWebUrl));

  static Future<bool> emailSupport() => _open(
    Uri(
      scheme: 'mailto',
      path: AppConfig.contactEmail,
      query: 'subject=${Uri.encodeComponent(AppStrings.emailSubject)}',
    ),
  );

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $uri: $e');
      return false;
    }
  }
}
