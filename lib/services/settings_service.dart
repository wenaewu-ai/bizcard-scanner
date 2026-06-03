// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  String apiKey;
  String model;
  String baseUrl;

  AppSettings({
    this.apiKey = '',
    this.model = 'llava:latest',
    this.baseUrl = 'https://ollama.com',
  });

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      apiKey: p.getString('apiKey') ?? '',
      model: p.getString('model') ?? 'llava:latest',
      baseUrl: p.getString('baseUrl') ?? 'https://ollama.com',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('apiKey', apiKey);
    await p.setString('model', model);
    await p.setString('baseUrl', baseUrl);
  }
}
