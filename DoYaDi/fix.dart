import 'dart:io';

void main() {
  final file = File('lib/screens/settings_screen.dart');
  String text = file.readAsStringSync();

  final regex = RegExp(r'  Widget _buildAssign\(.*?\]\);\r?\n  \}', multiLine: true, dotAll: true);
  
  final newMethod = '''  Widget _buildAssign(BuildContext ctx, SettingsProvider prov, AppSettings s, Color ac) {
    Future<void> pick(String label, int current, void Function(int) save) async {
      final val = await _swipeDialog(ctx, label, current);
      if (val != null) { save(val); prov.updateSettings(s); setState(() {}); }
    }

    return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
      _header('Gaz Bölgesi — Kaydırma Yönleri'),
      _swipeTile(ac, '↑ Yukarı',       _swipeName(s.gasSwipeUp),
          () => pick('Gaz ↑ Yukarı',      s.gasSwipeUp,       (v) => s.gasSwipeUp = v)),
      _swipeTile(ac, '↓ Aşağı',        _swipeName(s.gasSwipeDown),
          () => pick('Gaz ↓ Aşağı',       s.gasSwipeDown,     (v) => s.gasSwipeDown = v)),
      _swipeTile(ac, '← Sol',          _swipeName(s.gasSwipeLeft),
          () => pick('Gaz ← Sol',         s.gasSwipeLeft,     (v) => s.gasSwipeLeft = v)),
      _swipeTile(ac, '→ Sağ',          _swipeName(s.gasSwipeRight),
          () => pick('Gaz → Sağ',         s.gasSwipeRight,    (v) => s.gasSwipeRight = v)),
      _swipeTile(ac, '↖ Sol Üst',      _swipeName(s.gasSwipeUpLeft),
          () => pick('Gaz ↖ Sol Üst',     s.gasSwipeUpLeft,   (v) => s.gasSwipeUpLeft = v)),
      _swipeTile(ac, '↗ Sağ Üst',      _swipeName(s.gasSwipeUpRight),
          () => pick('Gaz ↗ Sağ Üst',     s.gasSwipeUpRight,  (v) => s.gasSwipeUpRight = v)),
      _swipeTile(ac, '↙ Sol Alt',      _swipeName(s.gasSwipeDownLeft),
          () => pick('Gaz ↙ Sol Alt',     s.gasSwipeDownLeft, (v) => s.gasSwipeDownLeft = v)),
      _swipeTile(ac, '↘ Sağ Alt',      _swipeName(s.gasSwipeDownRight),
          () => pick('Gaz ↘ Sağ Alt',     s.gasSwipeDownRight,(v) => s.gasSwipeDownRight = v)),

      const Divider(color: Colors.white12, height: 32),
      _header('Fren Bölgesi — Kaydırma Yönleri'),
      _swipeTile(ac, '↑ Yukarı',       _swipeName(s.brakeSwipeUp),
          () => pick('Fren ↑ Yukarı',     s.brakeSwipeUp,     (v) => s.brakeSwipeUp = v)),
      _swipeTile(ac, '↓ Aşağı',        _swipeName(s.brakeSwipeDown),
          () => pick('Fren ↓ Aşağı',      s.brakeSwipeDown,   (v) => s.brakeSwipeDown = v)),
      _swipeTile(ac, '← Sol',          _swipeName(s.brakeSwipeLeft),
          () => pick('Fren ← Sol',        s.brakeSwipeLeft,   (v) => s.brakeSwipeLeft = v)),
      _swipeTile(ac, '→ Sağ',          _swipeName(s.brakeSwipeRight),
          () => pick('Fren → Sağ',        s.brakeSwipeRight,  (v) => s.brakeSwipeRight = v)),
      _swipeTile(ac, '↖ Sol Üst',      _swipeName(s.brakeSwipeUpLeft),
          () => pick('Fren ↖ Sol Üst',    s.brakeSwipeUpLeft, (v) => s.brakeSwipeUpLeft = v)),
      _swipeTile(ac, '↗ Sağ Üst',      _swipeName(s.brakeSwipeUpRight),
          () => pick('Fren ↗ Sağ Üst',    s.brakeSwipeUpRight,(v) => s.brakeSwipeUpRight = v)),
      _swipeTile(ac, '↙ Sol Alt',      _swipeName(s.brakeSwipeDownLeft),
          () => pick('Fren ↙ Sol Alt',    s.brakeSwipeDownLeft,(v) => s.brakeSwipeDownLeft = v)),
      _swipeTile(ac, '↘ Sağ Alt',      _swipeName(s.brakeSwipeDownRight),
          () => pick('Fren ↘ Sağ Alt',    s.brakeSwipeDownRight,(v) => s.brakeSwipeDownRight = v)),
    ]);
  }''';

  if (regex.hasMatch(text)) {
    text = text.replaceFirst(regex, newMethod);
    file.writeAsStringSync(text);
    print("Replace success");
  } else {
    print("Pattern not found!");
  }
}
