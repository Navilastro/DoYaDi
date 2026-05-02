import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:doyadi/main.dart';
import 'package:doyadi/providers/settings_provider.dart';
import 'package:doyadi/providers/connection_provider.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ],
        child: const DoYaDiApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the Home screen is rendered by looking for the connection button.
    expect(find.text('Bağlanılacak Cihazı Seç'), findsOneWidget);
    expect(find.text('Direksiyon Modunu Başlat'), findsOneWidget);
  });
}
