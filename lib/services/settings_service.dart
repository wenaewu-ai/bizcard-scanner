// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

const kOllamaBaseUrl = 'https://ollama.com';
const kDefaultModel = 'gemma4:31b-cloud';

class AppSettings {
  String apiKey;
  String model;
  bool saveThumbnail; // 是否把名片縮圖存進資料
  final String baseUrl = kOllamaBaseUrl; // 鎖死，不可更改

  AppSettings({
    this.apiKey = '',
    this.model = kDefaultModel,
    this.saveThumbnail = true,
  });

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      apiKey: p.getString('apiKey') ?? '',
      model: p.getString('model') ?? kDefaultModel,
      saveThumbnail: p.getBool('saveThumbnail') ?? true,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('apiKey', apiKey);
    await p.setString('model', model);
    await p.setBool('saveThumbnail', saveThumbnail);
    // baseUrl 不儲存，永遠固定
  }
}
