import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/home_screen.dart';
import 'core/network/addon_network_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to landscape only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Hide system UI (full screen)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
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
        return MaterialApp(
          title: 'DoYaDi',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: settings.backgroundColor,
            primaryColor: settings.primaryColor,
            fontFamily: 'Roboto', // Basic modern font
            colorScheme: ColorScheme.dark(
              primary: settings.primaryColor,
              surface: Colors.grey[900]!,
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
