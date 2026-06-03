// lib/services/export_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/contact.dart';
import 'contact_store.dart';

class ImportResult {
  final int imported;
  final int skipped;
  final int duplicates;
  ImportResult({required this.imported, required this.skipped, required this.duplicates});
}

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

  // ── JSON 匯出 ─────────────────────────────────────────────────────────────
  static Future<void> exportJSON(List<Contact> contacts) async {
    final content = const JsonEncoder.withIndent('  ').convert({
      'exportedAt': DateTime.now().toIso8601String(),
      'contacts': contacts.map((c) => c.toJson()).toList(),
    });
    await _shareText(content, 'contacts_backup.json', 'application/json');
  }

  // ── JSON 匯入 ─────────────────────────────────────────────────────────────
  static Future<ImportResult?> importJSON() async {
    // 讓使用者選擇 JSON 檔案
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final path = result.files.first.path;
    if (path == null) return null;

    final content = await File(path).readAsString(encoding: utf8);
    final data = jsonDecode(content);

    // 支援兩種格式：{ contacts: [...] } 或直接 [...]
    final List rawList = data is Map ? (data['contacts'] as List? ?? []) : (data as List);

    final existing = await ContactStore.load();
    int imported = 0;
    int duplicates = 0;

    for (final item in rawList) {
      try {
        final contact = Contact.fromJson(item as Map<String, dynamic>);

        // 比對手機號碼是否已存在
        final dup = await ContactStore.findDuplicate(contact);
        if (dup != null) {
          duplicates++;
          continue; // 略過重複
        }

        // 產生新 id 避免衝突
        final newContact = Contact(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$imported',
          createdAt: contact.createdAt,
          name: contact.name, title: contact.title, department: contact.department,
          company: contact.company, taxId: contact.taxId,
          mobile: contact.mobile, phone: contact.phone, fax: contact.fax,
          email: contact.email, address: contact.address, website: contact.website,
          line: contact.line, notes: contact.notes,
        );
        await ContactStore.add(newContact);
        imported++;
      } catch (_) {
        // 格式錯誤的項目略過
      }
    }

    return ImportResult(
      imported: imported,
      skipped: rawList.length - imported - duplicates,
      duplicates: duplicates,
    );
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
    await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], subject: filename);
  }
}
