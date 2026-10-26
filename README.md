# Block Fit

An offline 8x8 block puzzle for Android by Adivantech (Pvt) Ltd.
Package: `com.adivantech.blockfit` · Version 1.0.0+1 · minSdk 24 · targetSdk 36

## Layout

- `lib/core` – constants, strings, themes, app / ad config
- `lib/models` – immutable data (board, pieces, game state, settings)
- `lib/game` – pure-Dart rules: placement, line clears, scoring, piece generation
- `lib/ui` – screens, widgets, Riverpod providers
- `lib/services` – storage, audio, haptics, ads, consent, purchases, links
- `assets/` – bundled font (Nunito, OFL) and placeholder sounds
- `tools/` – scripts that regenerate the placeholder sounds and icons
- `store/` – Play listing text, privacy policy, data safety, screenshots, release checklist

## Develop

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d macos   # desktop preview (no ads / billing)
```

## Release

See `store/RELEASE_CHECKLIST.md`. In short:

```sh
cp android/key.properties.example android/key.properties   # then fill it in
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

Before publishing, replace the test AdMob IDs in `lib/core/ad_config.dart` and
`AndroidManifest.xml`, and host `store/privacy_policy.html`.
