import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/settings_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/monetization_provider.dart';
import 'services/ad_service.dart';
import 'models/app_settings.dart';
import 'screens/home_screen.dart';
import 'core/network/addon_network_service.dart';
export 'core/overlay_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flavor yapılandırmasını başlat (--dart-define=FLAVOR=oyuku|doyadi|planeLever|sanrevye)
  AppConfig.instance.initFromEnvironment(defaultFlavor: AppFlavor.oyuku);
  
  // Lock to landscape only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Hide system UI (full screen)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // MobileAds SDK'sını başlat ve geçiş reklamlarını önceden yükle (Pre-load)
  AdService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()..loadSavedConnection()),
        ChangeNotifierProvider(create: (_) => MonetizationProvider()..initialize()),
      ],
      child: const DoYaDiApp(),
    ),
  );
}

class DoYaDiApp extends StatefulWidget {
  const DoYaDiApp({super.key});

  @override
  State<DoYaDiApp> createState() => _DoYaDiAppState();
}

class _DoYaDiAppState extends State<DoYaDiApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AddonNetworkService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      settings.settings.isAddonMasterSwitchActive = false;
      settings.settings.activeAddonIds = [];
      AddonNetworkService().isMasterSwitchActive = false;
      AddonNetworkService().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final s = settings.settings;
        final isLightBg = s.backgroundColor.computeLuminance() > 0.5;
        final baseTheme = ThemeData(
          brightness: isLightBg ? Brightness.light : Brightness.dark,
          fontFamily: s.appFontFamily,
        );
        return MaterialApp(
          title: AppConfig.instance.appName,
          scaffoldMessengerKey: MonetizationProvider.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            scaffoldBackgroundColor: s.backgroundColor,
            primaryColor: s.detailColor,
            colorScheme: (isLightBg
                    ? const ColorScheme.light()
                    : const ColorScheme.dark())
                .copyWith(
              primary: s.detailColor,
              secondary: s.secondaryColor,
              tertiary: s.tertiaryColor,
              error: s.warningColor,
              surface: s.surfaceColor,
              onSurface: s.textColor,
            ),
            textTheme: baseTheme.textTheme.apply(
              bodyColor: s.textColor,
              displayColor: s.textColor,
              fontFamily: s.appFontFamily,
            ),
            listTileTheme: ListTileThemeData(
              textColor: s.textColor,
              iconColor: s.textSecondaryColor,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: s.surfaceColor,
              titleTextStyle: TextStyle(
                color: s.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: s.appFontFamily,
              ),
              contentTextStyle: TextStyle(
                color: s.textSecondaryColor,
                fontSize: 14,
                fontFamily: s.appFontFamily,
              ),
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
