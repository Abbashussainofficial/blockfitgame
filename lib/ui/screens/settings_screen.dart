import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_theme.dart';
import '../../core/strings.dart';
import '../../services/link_service.dart';
import '../../services/purchase_service.dart';
import '../providers/monetization_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

/// Sound, vibration, Remove Ads / restore, privacy, links and About.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  StreamSubscription<PurchaseMessage>? _purchaseMessages;
  late final Future<bool> _privacyRequired = ref
      .read(consentServiceProvider)
      .privacyOptionsRequired();

  @override
  void initState() {
    super.initState();
    _purchaseMessages = ref.read(purchaseServiceProvider).messages.listen((m) {
      if (!mounted) return;
      showToast(context, switch (m) {
        PurchaseMessage.purchased => AppStrings.purchaseDone,
        PurchaseMessage.restored => AppStrings.purchaseRestored,
        PurchaseMessage.nothingToRestore => AppStrings.nothingToRestore,
        PurchaseMessage.failed => AppStrings.purchaseFailed,
        PurchaseMessage.unavailable => AppStrings.storeUnavailable,
      });
    });
  }

  @override
  void dispose() {
    _purchaseMessages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(gameThemeProvider);
    final money = ref.watch(monetizationProvider);
    final purchases = ref.read(purchaseServiceProvider);
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    Future<void> openLink(Future<bool> Function() open) async {
      if (!await open() && context.mounted) {
        showToast(context, AppStrings.linkFailed);
      }
    }

    return ThemedScaffold(
      theme: theme,
      title: AppStrings.settings,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            theme: theme,
            children: [
              _switch(
                theme,
                icon: Icons.volume_up_rounded,
                title: AppStrings.sound,
                subtitle: AppStrings.soundSubtitle,
                value: settings.soundOn,
                onChanged: ctrl.setSound,
              ),
              _switch(
                theme,
                icon: Icons.vibration_rounded,
                title: AppStrings.vibration,
                subtitle: AppStrings.vibrationSubtitle,
                value: settings.vibrationOn,
                onChanged: ctrl.setVibration,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            theme: theme,
            children: [
              _link(
                theme,
                icon: Icons.block_rounded,
                title: AppStrings.removeAds,
                subtitle: money.adsRemoved
                    ? AppStrings.adsRemoved
                    : AppStrings.removeAdsSubtitle(money.price),
                trailing: money.adsRemoved
                    ? Icons.check_circle_rounded
                    : money.purchasePending
                    ? Icons.hourglass_top_rounded
                    : Icons.shopping_bag_rounded,
                onTap: money.adsRemoved || money.purchasePending
                    ? null
                    : purchases.buyRemoveAds,
              ),
              _link(
                theme,
                icon: Icons.restore_rounded,
                title: AppStrings.restorePurchases,
                trailing: Icons.chevron_right_rounded,
                onTap: purchases.restore,
              ),
              FutureBuilder<bool>(
                future: _privacyRequired,
                builder: (context, snap) => snap.data == true
                    ? _link(
                        theme,
                        icon: Icons.shield_rounded,
                        title: AppStrings.privacyOptions,
                        subtitle: AppStrings.privacyOptionsSubtitle,
                        trailing: Icons.chevron_right_rounded,
                        onTap: ref
                            .read(consentServiceProvider)
                            .showPrivacyOptions,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            theme: theme,
            children: [
              _link(
                theme,
                icon: Icons.star_rounded,
                title: AppStrings.rateApp,
                subtitle: AppStrings.rateAppSubtitle,
                onTap: () => openLink(LinkService.openStoreListing),
              ),
              _link(
                theme,
                icon: Icons.privacy_tip_rounded,
                title: AppStrings.privacyPolicy,
                onTap: () => openLink(LinkService.openPrivacyPolicy),
              ),
              _link(
                theme,
                icon: Icons.info_rounded,
                title: AppStrings.about,
                trailing: Icons.chevron_right_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _switch(
    GameTheme theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile(
    secondary: Icon(icon, color: theme.accent),
    title: Text(title, style: _titleStyle(theme)),
    subtitle: Text(subtitle, style: TextStyle(color: theme.textSecondary)),
    value: value,
    onChanged: onChanged,
    activeThumbColor: theme.boardColor,
    activeTrackColor: theme.accent,
  );

  Widget _link(
    GameTheme theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    IconData trailing = Icons.open_in_new_rounded,
    required VoidCallback? onTap,
  }) => ListTile(
    leading: Icon(icon, color: theme.accent),
    title: Text(title, style: _titleStyle(theme)),
    subtitle: subtitle == null
        ? null
        : Text(subtitle, style: TextStyle(color: theme.textSecondary)),
    trailing: Icon(trailing, color: theme.textSecondary),
    onTap: onTap,
  );

  TextStyle _titleStyle(GameTheme theme) => TextStyle(
    color: theme.textPrimary,
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );
}

/// Rounded card grouping several settings rows.
class _Section extends StatelessWidget {
  const _Section({required this.theme, required this.children});

  final GameTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: theme.boardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: theme.emptyCellColor, width: 2),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );
}
