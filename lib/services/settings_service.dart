// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

const kOllamaBaseUrl = 'https://ollama.com';
const kDefaultModel = 'gemma4:31b-cloud';

class AppSettings {
  String apiKey;
  String model;
  final String baseUrl = kOllamaBaseUrl; // 鎖死，不可更改

  AppSettings({
    this.apiKey = '',
    this.model = kDefaultModel,
  });

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      apiKey: p.getString('apiKey') ?? '',
      model: p.getString('model') ?? kDefaultModel,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('apiKey', apiKey);
    await p.setString('model', model);
    // baseUrl 不儲存，永遠固定
  }
}
