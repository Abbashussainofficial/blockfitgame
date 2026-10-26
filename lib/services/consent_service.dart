import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/ad_config.dart';

/// GDPR / UMP consent (Google User Messaging Platform).
///
/// Configure the consent message itself in AdMob → Privacy & messaging.
/// Until it is published there, UMP reports "consent not required" and
/// ads are requested normally.
class ConsentService {
  /// Updates consent info and shows the consent form if the user must
  /// answer it (EEA / UK users). Returns whether ads may be requested.
  /// Never throws.
  Future<bool> gather() async {
    if (!AdConfig.monetizationSupported) return false;
    final done = Completer<void>();
    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode && AdConfig.debugForceEeaConsent
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              testIdentifiers: AdConfig.testDeviceIds,
            )
          : null,
    );
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () => ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) debugPrint('Consent form: ${error.message}');
          if (!done.isCompleted) done.complete();
        }),
        (error) {
          debugPrint('Consent info update failed: ${error.message}');
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      return await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('Consent error: $e');
      return false;
    }
  }

  /// Whether a "Privacy options" entry must be offered (EEA users must be
  /// able to change their choice later).
  Future<bool> privacyOptionsRequired() async {
    if (!AdConfig.monetizationSupported) return false;
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      debugPrint('Privacy options status failed: $e');
      return false;
    }
  }

  /// Re-opens the consent form so the user can change their choice.
  Future<void> showPrivacyOptions() async {
    if (!AdConfig.monetizationSupported) return;
    final done = Completer<void>();
    try {
      ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) debugPrint('Privacy options: ${error.message}');
        if (!done.isCompleted) done.complete();
      });
      await done.future;
    } catch (e) {
      debugPrint('Privacy options error: $e');
    }
  }
}
