part of '../settings_screen.dart';

extension _SettingsMembershipTabExt on _SettingsScreenState {
  Widget _buildMembership(
    BuildContext ctx,
    SettingsProvider prov,
    AppSettings s,
    Color ac,
  ) {
    final hasBgMedia = AppMediaHelper.hasMedia(s.bgMediaPath);
    final txt = hasBgMedia ? Colors.white : s.textColor;
    final sub = hasBgMedia ? Colors.white70 : s.textDisabledColor;
    final cardBg = hasBgMedia
        ? Colors.black.withValues(alpha: 0.45)
        : s.surfaceColor.withValues(alpha: 0.85);

    return Consumer<MonetizationProvider>(
      builder: (context, monetization, _) {
        final bool isPro = monetization.isPro;
        final bool isAdFree = monetization.isAdFree;

        final String currentTierLabel = isPro
            ? AppTranslations.getText('tier_pro')
            : (isAdFree
                ? AppTranslations.getText('tier_ad_free')
                : AppTranslations.getText('tier_free'));

        final Color tierColor = isPro
            ? Colors.amber
            : (isAdFree ? ac : Colors.white70);

        final IconData tierIcon = isPro
            ? Icons.workspace_premium
            : (isAdFree ? Icons.block : Icons.person_outline);

        // KRİTİK UI KURALI (Alt Paket Engelleme):
        // isPro == true -> Ad-Free devre dışı + "PRO Kapsamında", PRO devre dışı + "Mevcut Planınız"
        // sadece isAdFree == true -> Ad-Free devre dışı + "Mevcut Planınız", PRO tıklanabilir
        final String adFreeButtonText = isPro
            ? AppTranslations.getText('btn_included_in_pro')
            : (isAdFree
                ? AppTranslations.getText('btn_current_plan')
                : AppTranslations.getText('btn_upgrade_ad_free'));

        final VoidCallback? adFreeOnPressed =
            (isPro || isAdFree || monetization.isLoading)
                ? null
                : () => monetization.buyAdFree();

        final String proButtonText = isPro
            ? AppTranslations.getText('btn_current_plan')
            : AppTranslations.getText('btn_upgrade_pro');

        final VoidCallback? proOnPressed =
            (isPro || monetization.isLoading)
                ? null
                : () => monetization.buyPro();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            settingsHeader(AppTranslations.getText('membership_title')),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tierColor.withValues(alpha: 0.55),
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: tierColor.withValues(alpha: 0.18),
                    child: Icon(tierIcon, color: tierColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.getText('membership_current_status'),
                          style: TextStyle(color: sub, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentTierLabel,
                          style: TextStyle(
                            color: tierColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (monetization.isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: ac,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final adFreeCard = _buildPlanCard(
                  title: AppTranslations.getText('plan_ad_free_title'),
                  description: AppTranslations.getText('plan_ad_free_desc'),
                  price: monetization.adFreeProduct?.price,
                  accent: ac,
                  cardBg: cardBg,
                  txt: txt,
                  sub: sub,
                  buttonLabel: adFreeButtonText,
                  onPressed: adFreeOnPressed,
                  isDisabledAsIncluded: isPro,
                );
                final proCard = _buildPlanCard(
                  title: AppTranslations.getText('plan_pro_title'),
                  description: AppTranslations.getText('plan_pro_desc'),
                  price: monetization.proProduct?.price,
                  accent: Colors.amber,
                  cardBg: cardBg,
                  txt: txt,
                  sub: sub,
                  buttonLabel: proButtonText,
                  onPressed: proOnPressed,
                );

                if (constraints.maxWidth >= 480) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: adFreeCard),
                      const SizedBox(width: 12),
                      Expanded(child: proCard),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    adFreeCard,
                    const SizedBox(height: 12),
                    proCard,
                  ],
                );
              },
            ),
            if (monetization.statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                monetization.statusMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amberAccent.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: monetization.isLoading
                    ? null
                    : () => monetization.restorePurchases(),
                child: Text(
                  AppTranslations.getText('btn_restore_purchases'),
                  style: TextStyle(
                    color: sub,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String description,
    required Color accent,
    required Color cardBg,
    required Color txt,
    required Color sub,
    required String buttonLabel,
    required VoidCallback? onPressed,
    String? price,
    bool isDisabledAsIncluded = false,
  }) {
    final bool disabled = onPressed == null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: disabled
              ? Colors.grey.withValues(alpha: 0.35)
              : accent.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: txt,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (price != null)
                Text(
                  price,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: sub, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey.shade800,
                disabledForegroundColor: isDisabledAsIncluded
                    ? Colors.grey.shade400
                    : Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                buttonLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

