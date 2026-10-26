# Block Fit – release checklist

Everything still needed to go from this repo to Google Play, in order.

## 1. Replace placeholders

- [ ] **AdMob IDs** – create the app and 3 ad units (Banner, Interstitial,
      Rewarded) at https://apps.admob.com, then replace the test IDs in
      `lib/core/ad_config.dart` **and** the App ID in
      `android/app/src/main/AndroidManifest.xml`
      (`com.google.android.gms.ads.APPLICATION_ID`).
- [ ] **AdMob consent message** – AdMob → Privacy & messaging → create and
      publish a GDPR message for this app (otherwise no consent form is shown).
- [ ] **app-ads.txt** – add the line AdMob gives you to `app-ads.txt` on your
      developer website.
- [ ] **Privacy policy** – host `store/privacy_policy.html` at a public URL,
      then set `AppConfig.privacyPolicyUrl` (`lib/core/app_config.dart`) and
      the Play Console privacy policy field to that URL.
- [ ] **Icon and graphics** (optional but recommended) – replace the generated
      placeholders. Use Android Studio → File → New → Image Asset for the
      launcher icon, and replace `store/graphics/*.png`. To regenerate the
      placeholders, run `python3 tools/generate_icons.py`.
- [ ] **Sounds** (optional) – replace `assets/sounds/*.wav` (same names).

## 2. Create the upload key (once)

```sh
keytool -genkey -v -keystore ~/blockfit-upload.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
# edit android/key.properties with the passwords and keystore path
```

Back up the `.jks` file and its passwords somewhere safe. Both are git-ignored.
Enrol in **Play App Signing** when you create the app (the default), so
Google holds the app signing key and this is only your upload key.

## 3. Build the release App Bundle

```sh
cd ~/my_flutter_app
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`
R8 mapping file (upload it to Play Console → App bundle explorer → Downloads
so crash traces are readable): `build/app/outputs/mapping/release/mapping.txt`

If Gradle prints "key.properties not found: release build is DEBUG-signed",
step 2 isn't done yet. Play Console rejects debug-signed bundles.

To test the release build on a connected phone first:

```sh
flutter build apk --release
flutter install --release
```

## 4. Version for every upload

Bump `version:` in `pubspec.yaml` (for example `1.0.1+2`). The number after
`+` must increase with every upload. Keep `AppConfig.version` in sync.

## 5. Play Console

- [ ] Create the app (name: Block Fit, Game, Free).
- [ ] **In-app product**: Monetize → Products → In-app products → create a
      managed product with ID **`remove_ads`** (matches
      `AdConfig.removeAdsProductId`), set a price and activate it. Billing
      products can only be tested after a build with the billing library has
      been uploaded to a testing track.
- [ ] **License testers** (Setup → License testing): add your Google account
      to test the purchase without being charged.
- [ ] Store listing: copy from `store/listing.md`; graphics from
      `store/graphics/`; screenshots per `store/screenshots.md`.
- [ ] App content: Data safety (`store/data_safety.md`), Ads = Yes, Target
      audience 13+, Content rating questionnaire, Privacy policy URL.
- [ ] Upload the `.aab` to **Internal testing** first, install via the test
      link, check ads (test ads), consent, purchase/restore, then promote to
      Production. New personal developer accounts must run a **closed test
      with 12+ testers for 14 days** before Production access.

## 6. Technical notes

- **minSdk is 24 (Android 7.0), not 21.** This Flutter version and the AdMob
  plugin don't support anything lower. That still covers well over 95% of
  active devices.
- **targetSdk / compileSdk 36**, as Google Play requires for new apps and
  updates.
- The first Android build downloads Android SDK Platform 35 (one plugin
  compiles against it) plus the AdMob and Billing libraries. Run it on a
  good connection:
  `~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager "platforms;android-35"`.
- `ios/` and `macos/` exist only for local previews. They aren't part of the
  Android release, and can be deleted or kept.
