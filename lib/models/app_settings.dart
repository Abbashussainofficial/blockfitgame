/// User preferences shown on the Settings and Themes screens.
class AppSettings {
  const AppSettings({
    required this.soundOn,
    required this.vibrationOn,
    required this.themeId,
  });

  final bool soundOn;
  final bool vibrationOn;
  final String themeId;

  AppSettings copyWith({bool? soundOn, bool? vibrationOn, String? themeId}) =>
      AppSettings(
        soundOn: soundOn ?? this.soundOn,
        vibrationOn: vibrationOn ?? this.vibrationOn,
        themeId: themeId ?? this.themeId,
      );
}
