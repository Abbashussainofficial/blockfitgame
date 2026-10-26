/// All user-facing text. Widgets must read strings from here, never inline.
abstract final class AppStrings {
  static const String appName = 'Block Fit';
  static const String tagline = 'Fit the blocks. Clear the lines.';
  static const String companyName = 'Adivantech (Pvt) Ltd.';
  static const String loading = 'Loading…';

  // Home.
  static const String play = 'Play';
  static const String newGame = 'New Game';
  static const String continueGame = 'Continue';
  static const String themes = 'Themes';
  static const String settings = 'Settings';
  static const String highScore = 'High Score';

  // Game screen.
  static const String score = 'SCORE';
  static const String best = 'BEST';
  static const String undo = 'Undo';
  static const String pause = 'Pause';
  static const String newBest = 'NEW BEST!';
  static String combo(int streak) => 'COMBO x$streak!';
  static String linesCleared(int lines) => '$lines LINES!';

  // Pause.
  static const String paused = 'Paused';
  static const String resume = 'Resume';
  static const String restart = 'Restart';

  // Game over.
  static const String gameOver = 'Game Over';
  static const String noMovesLeft = 'No moves left';
  static const String playAgain = 'Play Again';
  static const String home = 'Home';
  static const String revive = 'Revive';
  static const String reviveHint = 'Watch a short ad to clear the centre';

  // Ads.
  static const String adNotReady = 'No ad available right now. Try again soon.';
  static const String outOfUndos = 'Out of undos';
  static const String watchAdForUndo = 'Watch a short ad to get 1 more undo?';
  static const String watchAd = 'Watch Ad';
  static const String cancel = 'Cancel';

  // Purchases & privacy.
  static const String removeAds = 'Remove Ads';
  static String removeAdsSubtitle(String? price) => price == null
      ? 'No banners or pop-up ads'
      : 'No banners or pop-up ads · $price';
  static const String adsRemoved = 'Ads removed. Thank you!';
  static const String restorePurchases = 'Restore Purchases';
  static const String purchaseDone = 'Ads removed. Thanks for your support!';
  static const String purchaseRestored = 'Purchase restored';
  static const String nothingToRestore = 'No previous purchase found';
  static const String purchaseFailed = 'Purchase failed. Please try again.';
  static const String storeUnavailable = 'Store not available on this device';
  static const String privacyOptions = 'Privacy Options';
  static const String privacyOptionsSubtitle = 'Change your ad consent';

  // Themes.
  static const String selected = 'Selected';
  static String unlockAt(int score) => 'Reach $score to unlock';
  static const String themeLocked = 'Keep playing to unlock this theme';

  // Settings.
  static const String sound = 'Sound';
  static const String soundSubtitle = 'Sound effects';
  static const String vibration = 'Vibration';
  static const String vibrationSubtitle = 'Haptic feedback';
  static const String privacyPolicy = 'Privacy Policy';
  static const String rateApp = 'Rate App';
  static const String rateAppSubtitle = 'Enjoying Block Fit? Leave a review';
  static const String about = 'About';
  static const String linkFailed = 'Could not open the link';

  // About.
  static const String builtBy = 'Built and Designed by';
  static const String contactUs = 'Contact us';
  static String version(String v) => 'Version $v';
  static const String emailSubject = 'Block Fit feedback';
}
