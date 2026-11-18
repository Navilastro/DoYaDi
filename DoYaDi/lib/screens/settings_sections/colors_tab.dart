part of '../settings_screen.dart';

extension _ColorsTabExtension on _SettingsScreenState {
  /// Özelleştirme (Tema, Font, Medya & Modlara Özel Görünüm) sekmesini oluşturur.
  Widget _buildColors(BuildContext ctx, SettingsProvider prov, AppSettings s) {
    return _ColorsTabContent(
      prov: prov,
      s: s,
      buildHeader: (t) => settingsHeader(t, s),
      buildColorPickerRow: (label, current, onChanged) =>
          buildColorRow(ctx, prov, s, label, current, onChanged),
      buildSwitchRow: ({
        required String title,
        String? subtitle,
        required bool value,
        required ValueChanged<bool> onChanged,
      }) =>
          settingsSwitchTile(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
        s: s,
      ),
    );
  }
}

class _ColorsTabContent extends StatefulWidget {
  final SettingsProvider prov;
  final AppSettings s;
  final Widget Function(String title) buildHeader;
  final Widget Function(
    String label,
    Color current,
    void Function(Color) onChanged,
  ) buildColorPickerRow;
  final Widget Function({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) buildSwitchRow;

  const _ColorsTabContent({
    required this.prov,
    required this.s,
    required this.buildHeader,
    required this.buildColorPickerRow,
    required this.buildSwitchRow,
  });

  @override
  State<_ColorsTabContent> createState() => _ColorsTabContentState();
}

class _ColorsTabContentState extends State<_ColorsTabContent> {
  static const List<String> _scopeOrder = [
    'general',
    'mode_0_1',
    'mode_2_3_4',
    'mode_5',
    'mode_6',
    'mode_7',
    'mode_8',
    'mode_9',
  ];

  /// Aktif flavor'ın izin verdiği modlara göre filtrelenmiş özelleştirme kapsamları.
  List<String> get _availableScopes {
    final modes = AppConfig.instance.allowedModes;
    return _scopeOrder.where((scope) {
      switch (scope) {
        case 'general':
          return true;
        case 'mode_0_1':
          return modes.contains(0) || modes.contains(1);
        case 'mode_2_3_4':
          return modes.contains(2) || modes.contains(3) || modes.contains(4);
        case 'mode_5':
          return modes.contains(5);
        case 'mode_6':
          return modes.contains(6);
        case 'mode_7':
          return modes.contains(7);
        case 'mode_8':
          return modes.contains(8);
        case 'mode_9':
          return modes.contains(9) || modes.contains(10);
        default:
          return false;
      }
    }).toList();
  }

  static const List<String> _fontOptions = [
    'Roboto',
    'sans-serif',
    'serif',
    'monospace',
    'sans-serif-condensed',
    'sans-serif-medium',
  ];

  String _selectedScope = 'general';

  AppSettings get _s => widget.s;
  SettingsProvider get _prov => widget.prov;
  bool get _hasBgMedia => AppMediaHelper.hasMedia(_s.bgMediaPath);
  Color get _cardTextColor => _hasBgMedia ? Colors.white : _s.textColor;
  Color get _cardSecondaryColor =>
      _hasBgMedia ? Colors.white70 : _s.textSecondaryColor;

  /// Seçili kapsam anahtarının kullanıcıya görünen etiketini döndürür.
  String _scopeLabel(String scope) {
    switch (scope) {
      case 'general':
        return AppTranslations.getText('scope_general_home_settings');
      case 'mode_0_1':
        return AppTranslations.getText('mode_0_1');
      case 'mode_2_3_4':
        return AppTranslations.getText('mode_2_3_4');
      case 'mode_5':
        return AppTranslations.getText('mode_5');
      case 'mode_6':
        return AppTranslations.getText('mode_6');
      case 'mode_7':
        return AppTranslations.getText('mode_7');
      case 'mode_8':
        return AppTranslations.getText('mode_8');
      case 'mode_9':
        return AppTranslations.getText('mode_9');
      default:
        return scope;
    }
  }

  /// İki rengin okunabilirlik/ton açısından uyumsuz olup olmadığını kontrol eder.
  bool _areColorsIncompatible(
    Color primary,
    Color candidate, {
    bool isSurfaceOrBg = false,
  }) {
    final double lumDiff =
        (primary.computeLuminance() - candidate.computeLuminance()).abs();
    final HSLColor hslP = HSLColor.fromColor(primary);
    final HSLColor hslC = HSLColor.fromColor(candidate);

    if (isSurfaceOrBg) {
      // Vurgu rengi arka planla neredeyse aynı parlaklıktaysa veya aşırı neon arka plansa uyumsuzdur.
      return lumDiff < 0.22 || hslC.saturation > 0.65;
    }

    final double rawHueDiff = (hslP.hue - hslC.hue).abs();
    final double hueDiff = rawHueDiff > 180 ? 360 - rawHueDiff : rawHueDiff;
    final double bgLumDiff =
        (candidate.computeLuminance() - _s.backgroundColor.computeLuminance())
            .abs();

    // Aynı tona çok yakın kirli kayma veya arka planda görünmez düşük kontrast.
    final bool muddyNearHue = hueDiff > 12 && hueDiff < 32 && lumDiff < 0.15;
    final bool invisibleOnBg = bgLumDiff < 0.14;
    return muddyNearHue || invisibleOnBg;
  }

  /// Ana renk (`detailColor`) temel alınarak uyumlu tema paleti üretir.
  void _applyColorHarmony(AppSettings s, {bool? preferLightBg}) {
    final HSLColor primaryHsl = HSLColor.fromColor(s.detailColor);
    final double hue = primaryHsl.hue;
    final bool isLight =
        preferLightBg ?? (s.backgroundColor.computeLuminance() > 0.5);

    if (isLight) {
      s.backgroundColor = HSLColor.fromAHSL(1.0, hue, 0.24, 0.95).toColor();
      s.surfaceColor = HSLColor.fromAHSL(1.0, hue, 0.18, 0.99).toColor();
      // Açık zeminde vurgu okunurluğu düşükse koyulaştır.
      if (s.detailColor.computeLuminance() > 0.55) {
        s.detailColor = primaryHsl.withLightness(0.38).toColor();
      }
      s.secondaryColor = HSLColor.fromAHSL(
        1.0,
        (hue + 45) % 360,
        primaryHsl.saturation.clamp(0.45, 0.85),
        0.42,
      ).toColor();
      s.tertiaryColor = HSLColor.fromAHSL(
        1.0,
        (hue + 150) % 360,
        primaryHsl.saturation.clamp(0.50, 0.88),
        0.44,
      ).toColor();
      s.warningColor = const Color(0xFFD32F2F);
    } else {
      s.backgroundColor = HSLColor.fromAHSL(1.0, hue, 0.38, 0.05).toColor();
      s.surfaceColor = HSLColor.fromAHSL(1.0, hue, 0.34, 0.11).toColor();
      if (s.detailColor.computeLuminance() < 0.20) {
        s.detailColor = primaryHsl.withLightness(0.58).toColor();
      }
      s.secondaryColor = HSLColor.fromAHSL(
        1.0,
        (hue + 45) % 360,
        primaryHsl.saturation.clamp(0.55, 0.88),
        0.64,
      ).toColor();
      s.tertiaryColor = HSLColor.fromAHSL(
        1.0,
        (hue + 150) % 360,
        primaryHsl.saturation.clamp(0.60, 0.90),
        0.60,
      ).toColor();
      s.warningColor = const Color(0xFFFF5252);
    }
  }

  void _updateAndMaybeHarmonize(
    void Function(Color c) applyPicked,
    Color picked, {
    bool isPrimary = false,
    bool isSurfaceOrBg = false,
    bool isBackground = false,
  }) {
    final bool preferLight =
        isBackground ? picked.computeLuminance() > 0.5 : _s.backgroundColor.computeLuminance() > 0.5;
    applyPicked(picked);
    if (_s.preventIncompatibleColors) {
      if (isPrimary) {
        _applyColorHarmony(_s, preferLightBg: preferLight);
      } else if (_areColorsIncompatible(
        _s.detailColor,
        picked,
        isSurfaceOrBg: isSurfaceOrBg,
      )) {
        _applyColorHarmony(_s, preferLightBg: preferLight);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppTranslations.getText('colors_harmonized')),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
    _prov.updateSettings(_s);
  }

  /// Tüm renk ve görsel özelleştirmelerini varsayılana sıfırlayan üst buton.
  Widget _buildResetColorsButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _s.warningColor,
          side: BorderSide(color: _s.warningColor.withValues(alpha: 0.7)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.restore_rounded),
        label: Text(
          AppTranslations.getText('reset_colors_to_default'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: _confirmResetColors,
      ),
    );
  }

  Future<void> _confirmResetColors() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: _s.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppTranslations.getText('reset_colors_to_default'),
          style: TextStyle(color: _s.textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppTranslations.getText('reset_colors_confirm'),
          style: TextStyle(color: _s.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(
              AppTranslations.getText('cancel'),
              style: TextStyle(color: _s.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _s.warningColor,
              foregroundColor: _s.contrastTextFor(_s.warningColor),
            ),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(AppTranslations.getText('confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _s.resetCustomizationToDefaults();
      _prov.updateSettings(_s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.getText('reset_colors_done'))),
        );
      }
    }
  }

  /// Giriş ekranı karşılama yazısını ("Hoşgeldin <İsim>") düzenleme satırı.
  Widget _buildDriverGreetingRow() {
    final String displayName = _s.customDriverName.trim().isEmpty
        ? AppTranslations.getText('default_driver_name')
        : _s.customDriverName.trim();
    return GlassContainer(
      isGlassActive: _hasBgMedia,
      solidBackgroundColor: _hasBgMedia ? null : _s.surfaceColor,
      border: Border.all(
        color: _hasBgMedia ? Colors.white24 : _s.dividerColor,
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(Icons.waving_hand_rounded, color: _s.detailColor),
        title: BlurredTextChip(
          enabled: _hasBgMedia,
          child: Text(
            AppTranslations.getText('welcome_header_section'),
            style: TextStyle(
              color: _cardTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${AppTranslations.getText('welcome_prefix')}, $displayName',
            style: TextStyle(color: _cardSecondaryColor, fontSize: 13),
          ),
        ),
        trailing: Icon(Icons.edit_rounded, color: _s.detailColor, size: 20),
        onTap: _showDriverNameDialog,
      ),
    );
  }

  Future<void> _showDriverNameDialog() async {
    final controller = TextEditingController(text: _s.customDriverName);
    final String? res = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: _s.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppTranslations.getText('driver_title_dialog_title'),
          style: TextStyle(color: _s.textColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.getText('driver_title_dialog_desc'),
              style: TextStyle(color: _s.textSecondaryColor, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: TextStyle(color: _s.textColor),
              decoration: InputDecoration(
                labelText: AppTranslations.getText('driver_title_label'),
                labelStyle: TextStyle(color: _s.textSecondaryColor),
                hintText: AppTranslations.getText('default_driver_name'),
                hintStyle: TextStyle(color: _s.textDisabledColor),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _s.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _s.detailColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text(
              AppTranslations.getText('cancel'),
              style: TextStyle(color: _s.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _s.detailColor,
              foregroundColor: _s.contrastTextFor(_s.detailColor),
            ),
            onPressed: () => Navigator.pop(dctx, controller.text.trim()),
            child: Text(AppTranslations.getText('save')),
          ),
        ],
      ),
    );
    if (res != null) {
      _s.customDriverName = res;
      _prov.updateSettings(_s);
    }
  }

  /// Kapsam açılır listesi (Genel + aktif flavor'ın izin verdiği modlar).
  Widget _buildScopeDropdown() {
    final List<String> scopes = _availableScopes;
    final String safeScope =
        scopes.contains(_selectedScope) ? _selectedScope : 'general';
    return GlassContainer(
      isGlassActive: _hasBgMedia,
      solidBackgroundColor: _hasBgMedia ? null : _s.surfaceColor,
      border: Border.all(
        color: _hasBgMedia ? Colors.white24 : _s.dividerColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, color: _s.detailColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.getText('customization_scope'),
                  style: TextStyle(
                    color: _cardSecondaryColor,
                    fontSize: 11,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: safeScope,
                    isExpanded: true,
                    dropdownColor: _s.surfaceColor,
                    iconEnabledColor: _s.detailColor,
                    style: TextStyle(
                      color: _cardTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: _s.appFontFamily,
                    ),
                    selectedItemBuilder: (_) => scopes
                        .map(
                          (scope) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _scopeLabel(scope),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _cardTextColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: _s.appFontFamily,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    items: scopes
                        .map(
                          (scope) => DropdownMenuItem<String>(
                            value: scope,
                            child: Text(
                              _scopeLabel(scope),
                              style: TextStyle(
                                color: _s.textColor,
                                fontFamily: _s.appFontFamily,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedScope = v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Görsel / GIF / döngülü video seçim satırı.
  Widget _buildMediaRow({
    required String label,
    String? subtitle,
    required String? currentPath,
    required void Function(String? path) onChanged,
  }) {
    final bool hasMedia = AppMediaHelper.hasMedia(currentPath);
    return GlassContainer(
      isGlassActive: _hasBgMedia,
      solidBackgroundColor: _hasBgMedia ? null : _s.surfaceColor,
      border: Border.all(
        color: _hasBgMedia ? Colors.white24 : _s.dividerColor,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _s.detailColor.withValues(alpha: 0.14),
            border: Border.all(
              color: hasMedia ? _s.detailColor : _s.dividerColor,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasMedia
              ? LoopingMediaWidget(
                  mediaPath: currentPath,
                  fit: BoxFit.cover,
                  fallback: Icon(
                    Icons.perm_media_outlined,
                    color: _s.detailColor,
                  ),
                )
              : Icon(Icons.perm_media_outlined, color: _s.detailColor),
        ),
        title: BlurredTextChip(
          enabled: _hasBgMedia,
          child: Text(
            label,
            style: TextStyle(
              color: _cardTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        subtitle: subtitle != null
            ? Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle,
                  style: TextStyle(color: _cardSecondaryColor, fontSize: 12),
                ),
              )
            : (hasMedia
                ? Text(
                    currentPath!.split(RegExp(r'[/\\]')).last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _cardSecondaryColor, fontSize: 11),
                  )
                : null),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMedia)
              IconButton(
                tooltip: AppTranslations.getText('clear_media'),
                icon: Icon(Icons.close_rounded, color: _s.warningColor),
                onPressed: () {
                  onChanged(null);
                  _prov.updateSettings(_s);
                },
              ),
            Icon(Icons.chevron_right_rounded, color: _cardSecondaryColor),
          ],
        ),
        onTap: () async {
          final String? picked = await showAppMediaPickerDialog(
            context,
            title: label,
            currentPath: currentPath,
          );
          if (picked == null) return;
          onChanged(picked.isEmpty ? null : picked);
          _prov.updateSettings(_s);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monetization = Provider.of<MonetizationProvider>(context);
    final bool isPro = monetization.isPro;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (!isPro) _buildProLockCard(context, monetization),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isPro ? null : () => monetization.showPaywall(context),
          child: AbsorbPointer(
            absorbing: !isPro,
            child: Opacity(
              opacity: isPro ? 1.0 : 0.45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Genel başlığının hemen üstünde varsayılana sıfırlama butonu
                  _buildResetColorsButton(),
                  // 2. Genel başlığı & Karşılama yazısı
                  widget.buildHeader(AppTranslations.getText('scope_general')),
                  _buildDriverGreetingRow(),
                  // 3. Karşılama yazısının hemen altında kapsam açılır listesi
                  _buildScopeDropdown(),
                  // 4. Seçili kapsama göre dinamik içerik
                  ..._buildScopeContent(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProLockCard(
    BuildContext context,
    MonetizationProvider monetization,
  ) {
    final ac = _s.detailColor;
    return GlassContainer(
      isGlassActive: _hasBgMedia,
      solidBackgroundColor: Colors.amber.withValues(alpha: 0.12),
      border: Border.all(color: Colors.amber.withValues(alpha: 0.55)),
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.getText('colors_pro_lock_title'),
                  style: TextStyle(
                    color: _cardTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  AppTranslations.getText('colors_pro_lock_desc'),
                  style: TextStyle(color: _cardSecondaryColor, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                  label: Text(AppTranslations.getText('upgrade_to_pro')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => monetization.showPaywall(context),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline, color: ac.withValues(alpha: 0.7), size: 20),
        ],
      ),
    );
  }

  List<Widget> _buildScopeContent() {
    final List<String> scopes = _availableScopes;
    final String safeScope =
        scopes.contains(_selectedScope) ? _selectedScope : 'general';
    switch (safeScope) {
      case 'general':
        return _buildGeneralSection();
      case 'mode_0_1':
        return _buildMode01Section();
      case 'mode_2_3_4':
        return _buildMode234Section();
      case 'mode_5':
        return _buildMode5Section();
      case 'mode_6':
        return _buildMode6Section();
      case 'mode_7':
        return _buildMode7Section();
      case 'mode_8':
        return _buildMode8Section();
      case 'mode_9':
        return _buildMode9Section();
      default:
        return _buildGeneralSection();
    }
  }

  // ── GENEL (GİRİŞ & AYARLAR) ──
  List<Widget> _buildGeneralSection() {
    final String safeFont = _fontOptions.contains(_s.appFontFamily)
        ? _s.appFontFamily
        : 'Roboto';
    final String startBtnLabel = AppTranslations.currentLanguage == 'tr'
        ? 'Giriş "${AppTranslations.getText('start_button')}" Butonu Rengi'
        : 'Home "${AppTranslations.getText('start_button')}" Button Color';

    return [
      // Uygulama geneli yazı tipi (Font)
      GlassContainer(
        isGlassActive: _hasBgMedia,
        solidBackgroundColor: _hasBgMedia ? null : _s.surfaceColor,
        border: Border.all(
          color: _hasBgMedia ? Colors.white24 : _s.dividerColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(Icons.font_download_outlined, color: _s.detailColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.getText('app_font'),
                    style: TextStyle(
                      color: _cardTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    AppTranslations.getText('app_font_desc'),
                    style: TextStyle(color: _cardSecondaryColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: safeFont,
              dropdownColor: _s.surfaceColor,
              iconEnabledColor: _s.detailColor,
              underline: const SizedBox.shrink(),
              items: _fontOptions
                  .map(
                    (f) => DropdownMenuItem<String>(
                      value: f,
                      child: Text(
                        f,
                        style: TextStyle(
                          color: _s.textColor,
                          fontFamily: f,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (_) => _fontOptions
                  .map(
                    (f) => Center(
                      child: Text(
                        f,
                        style: TextStyle(
                          color: _cardTextColor,
                          fontFamily: f,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  _s.appFontFamily = v;
                  _prov.updateSettings(_s);
                }
              },
            ),
          ],
        ),
      ),

      // Uyumsuz renkleri önle anahtarı
      widget.buildSwitchRow(
        title: AppTranslations.getText('prevent_incompatible_colors'),
        subtitle: AppTranslations.getText('prevent_incompatible_colors_desc'),
        value: _s.preventIncompatibleColors,
        onChanged: (val) {
          _s.preventIncompatibleColors = val;
          if (val) {
            _applyColorHarmony(_s);
          }
          _prov.updateSettings(_s);
        },
      ),

      widget.buildHeader(AppTranslations.getText('theme_colors')),
      widget.buildColorPickerRow(
        AppTranslations.getText('primary_color'),
        _s.detailColor,
        (c) => _updateAndMaybeHarmonize(
          (v) => _s.detailColor = v,
          c,
          isPrimary: true,
        ),
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('secondary_color'),
        _s.secondaryColor,
        (c) => _updateAndMaybeHarmonize((v) => _s.secondaryColor = v, c),
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('tertiary_color'),
        _s.tertiaryColor,
        (c) => _updateAndMaybeHarmonize((v) => _s.tertiaryColor = v, c),
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('bg_color'),
        _s.backgroundColor,
        (c) => _updateAndMaybeHarmonize(
          (v) => _s.backgroundColor = v,
          c,
          isSurfaceOrBg: true,
          isBackground: true,
        ),
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('surface_color'),
        _s.surfaceColor,
        (c) => _updateAndMaybeHarmonize(
          (v) => _s.surfaceColor = v,
          c,
          isSurfaceOrBg: true,
        ),
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('warning_color'),
        _s.warningColor,
        (c) => _updateAndMaybeHarmonize((v) => _s.warningColor = v, c),
      ),

      widget.buildHeader(AppTranslations.getText('media_settings')),
      _buildMediaRow(
        label: AppTranslations.getText('bg_media'),
        subtitle: AppTranslations.getText('bg_media_desc'),
        currentPath: _s.bgMediaPath,
        onChanged: (p) => _s.bgMediaPath = p,
      ),
      widget.buildColorPickerRow(
        startBtnLabel,
        _s.homeStartBtnColor,
        (c) {
          _s.homeStartBtnColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('start_btn_media'),
        subtitle: AppTranslations.getText('start_btn_media_desc'),
        currentPath: _s.homeStartBtnMediaPath,
        onChanged: (p) => _s.homeStartBtnMediaPath = p,
      ),
      _buildMediaRow(
        label: AppTranslations.getText('btn_media'),
        currentPath: _s.generalButtonMediaPath,
        onChanged: (p) => _s.generalButtonMediaPath = p,
      ),
    ];
  }

  /// Mod 0-4 & Mod 6 tarafından paylaşılan pedal ve isteğe bağlı direksiyon barı kontrolleri.
  List<Widget> _buildPedalAndSteeringBarControls({
    required bool includeSteeringBar,
  }) {
    return [
      if (includeSteeringBar) ...[
        widget.buildHeader(AppTranslations.getText('steering_indicator')),
        widget.buildColorPickerRow(
          AppTranslations.getText('steering_bar_color'),
          _s.steeringIndicatorColor,
          (c) {
            _s.steeringIndicatorColor = c;
            _prov.updateSettings(_s);
          },
        ),
        widget.buildColorPickerRow(
          AppTranslations.getText('indicator_bg'),
          _s.steeringBgColor,
          (c) {
            _s.steeringBgColor = c;
            _prov.updateSettings(_s);
          },
        ),
        _buildMediaRow(
          label: AppTranslations.getText('steering_bar_media'),
          currentPath: _s.steeringBarMediaPath,
          onChanged: (p) => _s.steeringBarMediaPath = p,
        ),
      ],
      widget.buildHeader(AppTranslations.getText('pedals')),
      widget.buildColorPickerRow(
        AppTranslations.getText('left_bar_fill_color'),
        _s.brakeColor,
        (c) {
          _s.brakeColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('left_bar_fill_media'),
        currentPath: _s.brakeBarMediaPath,
        onChanged: (p) => _s.brakeBarMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('right_bar_fill_color'),
        _s.gasColor,
        (c) {
          _s.gasColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('right_bar_fill_media'),
        currentPath: _s.gasBarMediaPath,
        onChanged: (p) => _s.gasBarMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('yetsore_color'),
        _s.yetsoreColor,
        (c) {
          _s.yetsoreColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('yetsore_media'),
        currentPath: _s.yetsoreMediaPath,
        onChanged: (p) => _s.yetsoreMediaPath = p,
      ),
      widget.buildSwitchRow(
        title: AppTranslations.getText('separate_bar_bg'),
        subtitle: AppTranslations.getText('separate_bar_bg_desc'),
        value: _s.separatePedalBg,
        onChanged: (val) {
          _s.separatePedalBg = val;
          _prov.updateSettings(_s);
        },
      ),
      if (!_s.separatePedalBg) ...[
        widget.buildColorPickerRow(
          AppTranslations.getText('unified_bar_bg_color'),
          _s.pedalBgColor,
          (c) {
            _s.pedalBgColor = c;
            _prov.updateSettings(_s);
          },
        ),
        _buildMediaRow(
          label: AppTranslations.getText('unified_bar_bg_media'),
          currentPath: _s.pedalBarBgMediaPath,
          onChanged: (p) => _s.pedalBarBgMediaPath = p,
        ),
      ] else ...[
        widget.buildColorPickerRow(
          AppTranslations.getText('left_bar_bg_color'),
          _s.leftPedalBgColor,
          (c) {
            _s.leftPedalBgColor = c;
            _prov.updateSettings(_s);
          },
        ),
        _buildMediaRow(
          label: AppTranslations.getText('left_bar_bg_media'),
          currentPath: _s.leftPedalBgMediaPath,
          onChanged: (p) => _s.leftPedalBgMediaPath = p,
        ),
        widget.buildColorPickerRow(
          AppTranslations.getText('right_bar_bg_color'),
          _s.rightPedalBgColor,
          (c) {
            _s.rightPedalBgColor = c;
            _prov.updateSettings(_s);
          },
        ),
        _buildMediaRow(
          label: AppTranslations.getText('right_bar_bg_media'),
          currentPath: _s.rightPedalBgMediaPath,
          onChanged: (p) => _s.rightPedalBgMediaPath = p,
        ),
      ],
    ];
  }

  // ── MOD 0 & 1 ──
  List<Widget> _buildMode01Section() {
    return [
      widget.buildHeader(AppTranslations.getText('mode_0_1')),
      widget.buildColorPickerRow(
        AppTranslations.getText('bg_color'),
        _s.mod01BgColor,
        (c) {
          _s.mod01BgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('bg_media'),
        currentPath: _s.mod01BgMediaPath,
        onChanged: (p) => _s.mod01BgMediaPath = p,
      ),
      ..._buildPedalAndSteeringBarControls(includeSteeringBar: true),
    ];
  }

  // ── MOD 2, 3 & 4 ──
  List<Widget> _buildMode234Section() {
    return [
      widget.buildHeader(AppTranslations.getText('mode_2_3_4')),
      widget.buildColorPickerRow(
        AppTranslations.getText('bg_color'),
        _s.mod234BgColor,
        (c) {
          _s.mod234BgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('bg_media'),
        currentPath: _s.mod234BgMediaPath,
        onChanged: (p) => _s.mod234BgMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mode_buttons_color'),
        _s.mode234ButtonColor,
        (c) {
          _s.mode234ButtonColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mode_buttons_media'),
        currentPath: _s.mode234ButtonMediaPath,
        onChanged: (p) => _s.mode234ButtonMediaPath = p,
      ),
      ..._buildPedalAndSteeringBarControls(includeSteeringBar: true),
    ];
  }

  // ── MOD 5 (AYARLARDA YALNIZCA SAYFA ARKA PLANI) ──
  List<Widget> _buildMode5Section() {
    return [
      widget.buildHeader(AppTranslations.getText('mode_5')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod5_page_bg_color'),
        _s.mod5BgColor,
        (c) {
          _s.mod5BgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod5_page_bg_media'),
        currentPath: _s.mod5BgMediaPath,
        onChanged: (p) => _s.mod5BgMediaPath = p,
      ),
      GlassContainer(
        isGlassActive: _hasBgMedia,
        solidBackgroundColor: _hasBgMedia ? null : _s.surfaceColor,
        border: Border.all(
          color: _s.detailColor.withValues(alpha: 0.45),
        ),
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _s.detailColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTranslations.getText('mod5_editor_media_hint'),
                    style: TextStyle(color: _cardTextColor, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _s.detailColor,
                  foregroundColor: _s.contrastTextFor(_s.detailColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.dashboard_customize_rounded),
                label: Text(AppTranslations.getText('open_mod5_editor')),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomLayout5EditorScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── MOD 6 (SİMÜLASYON) ──
  List<Widget> _buildMode6Section() {
    return [
      widget.buildHeader(AppTranslations.getText('mode_6')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod6_page_bg_color'),
        _s.mod6BgColor,
        (c) {
          _s.mod6BgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod6_page_bg_media'),
        currentPath: _s.mod6BgMediaPath,
        onChanged: (p) => _s.mod6BgMediaPath = p,
      ),

      widget.buildHeader(AppTranslations.getText('steering_indicator')),
      // Direksiyon simidi yalnızca renk
      widget.buildColorPickerRow(
        AppTranslations.getText('mod6_wheel_rim_color'),
        _s.steeringWheelColor,
        (c) {
          _s.steeringWheelColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod6_turn_right_color'),
        _s.steeringTurnRightColor,
        (c) {
          _s.steeringTurnRightColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod6_turn_left_color'),
        _s.steeringTurnLeftColor,
        (c) {
          _s.steeringTurnLeftColor = c;
          _prov.updateSettings(_s);
        },
      ),

      widget.buildHeader(AppTranslations.getText('mode_buttons_color')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod6_horn_color'),
        _s.mod6HornColor,
        (c) {
          _s.mod6HornColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod6_horn_media'),
        currentPath: _s.mod6HornMediaPath,
        onChanged: (p) => _s.mod6HornMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('clutch_button_color'),
        _s.clutchButtonColor,
        (c) {
          _s.clutchButtonColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('handbrake_button_color'),
        _s.handbrakeButtonColor,
        (c) {
          _s.handbrakeButtonColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod6_buttons_media'),
        currentPath: _s.mod6ButtonsMediaPath,
        onChanged: (p) => _s.mod6ButtonsMediaPath = p,
      ),

      widget.buildHeader(AppTranslations.getText('mod6_accel_icons_color')),
      widget.buildColorPickerRow(
        AppTranslations.getText('gas_icon_color'),
        _s.gasIconColor,
        (c) {
          _s.gasIconColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('brake_icon_color'),
        _s.brakeIconColor,
        (c) {
          _s.brakeIconColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('clutch_icon_color'),
        _s.clutchIconColor,
        (c) {
          _s.clutchIconColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod6_accel_icons_media'),
        currentPath: _s.mod6AccelIconsMediaPath,
        onChanged: (p) => _s.mod6AccelIconsMediaPath = p,
      ),

      ..._buildPedalAndSteeringBarControls(includeSteeringBar: false),

      widget.buildColorPickerRow(
        AppTranslations.getText('mod6_clutch_bar_color'),
        _s.clutchColor,
        (c) {
          _s.clutchColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod6_clutch_bar_media'),
        currentPath: _s.clutchBarMediaPath,
        onChanged: (p) => _s.clutchBarMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('clutch_feedback_color'),
        _s.clutchYetsoreColor,
        (c) {
          _s.clutchYetsoreColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod6_handbrake_bar_color'),
        _s.handbrakeColor,
        (c) {
          _s.handbrakeColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod6_handbrake_bar_media'),
        currentPath: _s.handbrakeBarMediaPath,
        onChanged: (p) => _s.handbrakeBarMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('handbrake_feedback_color'),
        _s.handbrakeYetsoreColor,
        (c) {
          _s.handbrakeYetsoreColor = c;
          _prov.updateSettings(_s);
        },
      ),
    ];
  }

  /// Mod 7 için renk geçişi (gradient) canlı önizleme şeridi.
  Widget _buildGradientPreviewBar(List<Color> colors) {
    return Container(
      height: 14,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _hasBgMedia ? Colors.white24 : _s.dividerColor,
        ),
        gradient: LinearGradient(colors: colors),
      ),
    );
  }

  // ── MOD 7 (F1 HUD) ──
  List<Widget> _buildMode7Section() {
    return [
      widget.buildHeader(AppTranslations.getText('mode_7')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_page_bg_color'),
        _s.mod7BgColor,
        (c) {
          _s.mod7BgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod7_page_bg_media'),
        currentPath: _s.mod7BgMediaPath,
        onChanged: (p) => _s.mod7BgMediaPath = p,
      ),

      widget.buildHeader(AppTranslations.getText('mod7_tyre_gradient_header')),
      _buildGradientPreviewBar([
        _s.mod7TyreColdColor,
        _s.mod7TyreOptColor,
        _s.mod7TyreHotColor,
        _s.mod7TyreCritColor,
      ]),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_tyre_cold_color'),
        _s.mod7TyreColdColor,
        (c) {
          _s.mod7TyreColdColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_tyre_opt_color'),
        _s.mod7TyreOptColor,
        (c) {
          _s.mod7TyreOptColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_tyre_hot_color'),
        _s.mod7TyreHotColor,
        (c) {
          _s.mod7TyreHotColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_tyre_crit_color'),
        _s.mod7TyreCritColor,
        (c) {
          _s.mod7TyreCritColor = c;
          _prov.updateSettings(_s);
        },
      ),

      widget.buildHeader(AppTranslations.getText('mod7_rpm_gradient_header')),
      _buildGradientPreviewBar([
        _s.mod7RpmLowColor,
        _s.mod7RpmMidColor,
        _s.mod7RpmHighColor,
        _s.mod7RpmLimColor,
      ]),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_rpm_low_color'),
        _s.mod7RpmLowColor,
        (c) {
          _s.mod7RpmLowColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_rpm_mid_color'),
        _s.mod7RpmMidColor,
        (c) {
          _s.mod7RpmMidColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_rpm_high_color'),
        _s.mod7RpmHighColor,
        (c) {
          _s.mod7RpmHighColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_rpm_lim_color'),
        _s.mod7RpmLimColor,
        (c) {
          _s.mod7RpmLimColor = c;
          _prov.updateSettings(_s);
        },
      ),

      widget.buildHeader(AppTranslations.getText('telemetry_tab_hud')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_speed_color'),
        _s.mod7SpeedColor,
        (c) {
          _s.mod7SpeedColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_gear_color'),
        _s.mod7GearColor,
        (c) {
          _s.mod7GearColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_drs_color'),
        _s.mod7DrsActiveColor,
        (c) {
          _s.mod7DrsActiveColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_ers_color'),
        _s.mod7ErsColor,
        (c) {
          _s.mod7ErsColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_rpm_box_color'),
        _s.mod7RpmBoxColor,
        (c) {
          _s.mod7RpmBoxColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod7_buttons_color'),
        _s.mod7ButtonsColor,
        (c) {
          _s.mod7ButtonsColor = c;
          _prov.updateSettings(_s);
        },
      ),
    ];
  }

  // ── MOD 8 (RAHAT SÜRÜŞ: SAYFA İÇİ & SAYFA DIŞI AYRI) ──
  List<Widget> _buildMode8Section() {
    return [
      widget.buildHeader(AppTranslations.getText('mod8_in_page_header')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_page_bg_color'),
        _s.mod8BgColor,
        (c) {
          _s.mod8BgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod8_page_bg_media'),
        currentPath: _s.mod8BgMediaPath,
        onChanged: (p) => _s.mod8BgMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_steer_color'),
        _s.mod8SteerColor,
        (c) {
          _s.mod8SteerColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_gas_color'),
        _s.mod8GasColor,
        (c) {
          _s.mod8GasColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_brake_color'),
        _s.mod8BrakeColor,
        (c) {
          _s.mod8BrakeColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_radar_color'),
        _s.mod8RadarColor,
        (c) {
          _s.mod8RadarColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_cruise_color'),
        _s.mod8CruiseColor,
        (c) {
          _s.mod8CruiseColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_hold_btn_color'),
        _s.mod8HoldButtonsColor,
        (c) {
          _s.mod8HoldButtonsColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_gear_btn_color'),
        _s.mod8GearBtnColor,
        (c) {
          _s.mod8GearBtnColor = c;
          _prov.updateSettings(_s);
        },
      ),

      widget.buildHeader(AppTranslations.getText('mod8_out_page_header')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_overlay_bg_color'),
        _s.mod8OverlayBgColor,
        (c) {
          _s.mod8OverlayBgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_overlay_border_color'),
        _s.mod8OverlayBorderColor,
        (c) {
          _s.mod8OverlayBorderColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_overlay_steer_color'),
        _s.mod8OverlaySteerColor,
        (c) {
          _s.mod8OverlaySteerColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_overlay_gas_color'),
        _s.mod8OverlayGasColor,
        (c) {
          _s.mod8OverlayGasColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_overlay_brake_color'),
        _s.mod8OverlayBrakeColor,
        (c) {
          _s.mod8OverlayBrakeColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod8_overlay_gear_btn_color'),
        _s.mod8OverlayGearBtnColor,
        (c) {
          _s.mod8OverlayGearBtnColor = c;
          _prov.updateSettings(_s);
        },
      ),
    ];
  }

  // ── MOD 9 (UÇUŞ HOTAS) ──
  List<Widget> _buildMode9Section() {
    return [
      widget.buildHeader(AppTranslations.getText('mode_9')),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_page_bg_color'),
        _s.mod9BgColor,
        (c) {
          _s.mod9BgColor = c;
          _prov.updateSettings(_s);
        },
      ),
      _buildMediaRow(
        label: AppTranslations.getText('mod9_page_bg_media'),
        currentPath: _s.mod9BgMediaPath,
        onChanged: (p) => _s.mod9BgMediaPath = p,
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_throttle_color'),
        _s.mod9ThrottleColor,
        (c) {
          _s.mod9ThrottleColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_wep_color'),
        _s.mod9WepColor,
        (c) {
          _s.mod9WepColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_avionics_color'),
        _s.mod9AvionicsColor,
        (c) {
          _s.mod9AvionicsColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_rudder_color'),
        _s.mod9RudderColor,
        (c) {
          _s.mod9RudderColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_hud_color'),
        _s.mod9HudColor,
        (c) {
          _s.mod9HudColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_fire_btn_color'),
        _s.mod9FireBtnColor,
        (c) {
          _s.mod9FireBtnColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_weapon_btn_color'),
        _s.mod9WeaponBtnColor,
        (c) {
          _s.mod9WeaponBtnColor = c;
          _prov.updateSettings(_s);
        },
      ),
      widget.buildColorPickerRow(
        AppTranslations.getText('mod9_hat_switch_color'),
        _s.mod9HatSwitchColor,
        (c) {
          _s.mod9HatSwitchColor = c;
          _prov.updateSettings(_s);
        },
      ),
    ];
  }
}
