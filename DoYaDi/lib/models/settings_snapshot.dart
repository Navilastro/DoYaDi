import 'dart:convert';
import 'app_settings.dart';

/// Uygulamanın o anki tüm ayarlarını (mod, hassasiyetler, eksen tersinirlikleri,
/// tema/medya vb.) tek bir JSON yapısında saklayan Global Settings Snapshot modeli.
class SettingsSnapshot {
  final String id;
  final String name;
  final DateTime createdAt;
  final Map<String, dynamic> settingsJson;

  const SettingsSnapshot({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.settingsJson,
  });

  factory SettingsSnapshot.fromAppSettings({
    required String id,
    required String name,
    required AppSettings settings,
    DateTime? createdAt,
  }) {
    return SettingsSnapshot(
      id: id,
      name: name,
      createdAt: createdAt ?? DateTime.now(),
      settingsJson: settings.toJson(),
    );
  }

  AppSettings toAppSettings() => AppSettings.fromJson(settingsJson);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'settingsJson': settingsJson,
      };

  factory SettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settingsJson'];
    return SettingsSnapshot(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Snapshot',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      settingsJson: rawSettings is Map
          ? Map<String, dynamic>.from(rawSettings)
          : <String, dynamic>{},
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory SettingsSnapshot.fromRawJson(String source) =>
      SettingsSnapshot.fromJson(jsonDecode(source) as Map<String, dynamic>);

  static String encodeList(List<SettingsSnapshot> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SettingsSnapshot> decodeList(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => SettingsSnapshot.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

