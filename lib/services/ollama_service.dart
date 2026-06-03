// lib/services/ollama_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/contact.dart';

class OllamaService {
  final String apiKey;
  final String model;
  final String baseUrl;

  OllamaService({
    required this.apiKey,
    this.model = 'llava:latest',
    this.baseUrl = 'https://ollama.com',
  });

  Future<Contact> scanCard(String base64Image) async {
    const prompt = '''從這張名片圖片提取以下資訊，只回傳 JSON，不要任何說明文字或 markdown：
{
  "name": "姓名",
  "title": "職稱",
  "department": "部門",
  "company": "公司名稱",
  "taxId": "公司統一編號（台灣8碼數字，如有）",
  "mobile": "手機號碼",
  "phone": "市話",
  "fax": "傳真",
  "email": "電子郵件",
  "address": "地址",
  "website": "網址",
  "line": "LINE ID",
  "notes": "其他備註資訊"
}
找不到的欄位設為空字串。''';

    final response = await http
        .post(
          Uri.parse('$baseUrl/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                  },
                  {'type': 'text', 'text': prompt},
                ],
              }
            ],
            'max_tokens': 768,
            'temperature': 0.1,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('API 錯誤 ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final text = data['choices']?[0]?['message']?['content'] as String? ?? '';

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) throw Exception('AI 回應無法解析為 JSON');

    final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    return Contact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      name: parsed['name'] ?? '',
      title: parsed['title'] ?? '',
      department: parsed['department'] ?? '',
      company: parsed['company'] ?? '',
      taxId: parsed['taxId'] ?? '',
      mobile: parsed['mobile'] ?? '',
      phone: parsed['phone'] ?? '',
      fax: parsed['fax'] ?? '',
      email: parsed['email'] ?? '',
      address: parsed['address'] ?? '',
      website: parsed['website'] ?? '',
      line: parsed['line'] ?? '',
      notes: parsed['notes'] ?? '',
    );
  }
}
