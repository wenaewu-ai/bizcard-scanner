// lib/services/gcis_service.dart
// 經濟部商工行政資料開放平台 - 統編查行業類別
import 'dart:convert';
import 'package:http/http.dart' as http;

// 行業代碼第一碼 → 中文大類
const _industryMap = {
  'A': '農林漁牧業',
  'B': '礦業及土石採取業',
  'C': '製造業',
  'D': '電力及燃氣供應業',
  'E': '用水供應及污染整治業',
  'F': '營造業',
  'G': '批發及零售業',
  'H': '運輸及倉儲業',
  'I': '住宿及餐飲業',
  'J': '資訊及通訊傳播業',
  'K': '金融及保險業',
  'L': '不動產業',
  'M': '專業、科學及技術服務業',
  'N': '支援服務業',
  'O': '公共行政及國防',
  'P': '教育業',
  'Q': '醫療保健及社會工作服務業',
  'R': '藝術、娛樂及休閒服務業',
  'S': '其他服務業',
};

class GcisService {
  /// 用統編查行業大類，查不到或失敗回傳 null
  static Future<String?> lookupIndustry(String taxId) async {
    final id = taxId.replaceAll(RegExp(r'\s'), '');
    if (id.length != 8 || !RegExp(r'^\d{8}$').hasMatch(id)) return null;

    try {
      // 公司登記基本資料 API（用統編查）
      final url = Uri.parse(
        'https://data.gcis.nat.gov.tw/od/data/api/7E6AFA72-AD6A-46D3-8681-ED77951D912D'
        '?\$format=json&\$filter=Business_Accounting_NO eq $id&\$skip=0&\$top=1',
      );

      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final body = utf8.decode(resp.bodyBytes);
      final list = jsonDecode(body) as List?;
      if (list == null || list.isEmpty) return null;

      final company = list.first as Map<String, dynamic>;

      // 取得營業項目代碼（如 J601010 → J 開頭 = 資訊及通訊傳播業）
      final businessItems = company['Business_Item'] as String? ?? '';
      if (businessItems.isNotEmpty) {
        final firstCode = businessItems.trim()[0].toUpperCase();
        final industry = _industryMap[firstCode];
        if (industry != null) return industry;
      }

      // 備用：從公司名稱第一碼行業代碼判斷
      final coCategory = company['Industry_Category'] as String? ?? '';
      if (coCategory.isNotEmpty) {
        final firstCode = coCategory.trim()[0].toUpperCase();
        return _industryMap[firstCode];
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
