import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/home_screen.dart';

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

class DoYaDiApp extends StatelessWidget {
  const DoYaDiApp({super.key});

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
