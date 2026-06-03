// lib/services/export_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../models/contact.dart';

class ExportService {
  // ── vCard ──────────────────────────────────────────────────────────────────
  static Future<void> exportVCard(List<Contact> contacts) async {
    final content = contacts.map((c) => c.toVCard()).join('\r\n');
    await _shareText(content, 'contacts.vcf', 'text/vcard');
  }

  // ── CSV（UTF-8 BOM，Excel 直接開）────────────────────────────────────────
  static Future<void> exportCSV(List<Contact> contacts) async {
    final headers = ['姓名','職稱','部門','公司','統編','手機','市話','傳真','Email','地址','網址','LINE','備註'];
    final rows = contacts.map((c) => [
      c.name, c.title, c.department, c.company, c.taxId,
      c.mobile, c.phone, c.fax, c.email, c.address, c.website, c.line, c.notes,
    ].map(_csvEscape).join(','));

    final bom = '\uFEFF';
    final content = bom + [headers.join(','), ...rows].join('\r\n');
    await _shareText(content, 'contacts.csv', 'text/csv');
  }

  // ── JSON ──────────────────────────────────────────────────────────────────
  static Future<void> exportJSON(List<Contact> contacts) async {
    final content = const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'contacts': contacts.map((c) => c.toJson()).toList(),
    });
    await _shareText(content, 'contacts_backup.json', 'application/json');
  }

  static String _csvEscape(String val) {
    if (val.isEmpty) return '';
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }

  static Future<void> _shareText(String content, String filename, String mimeType) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, encoding: utf8);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: filename,
    );
  }
}
