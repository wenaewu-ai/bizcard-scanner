// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../services/contact_store.dart';
import '../services/export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl  = TextEditingController();
  final _urlCtrl    = TextEditingController();
  bool _showKey = false;
  int _count = 0;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppSettings.load();
    final contacts = await ContactStore.load();
    setState(() {
      _apiKeyCtrl.text = s.apiKey;
      _modelCtrl.text  = s.model;
      _urlCtrl.text    = s.baseUrl;
      _count = contacts.length;
    });
  }

  Future<void> _save() async {
    final s = AppSettings(
      apiKey: _apiKeyCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim(),
    );
    await s.save();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('設定已儲存')));
  }

  Future<void> _export() async {
    final contacts = await ContactStore.load();
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('沒有聯絡人可匯出')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.contact_page_outlined), title: const Text('vCard (.vcf)'),
          subtitle: const Text('可直接匯入通訊錄'),
          onTap: () { Navigator.pop(context); _doExport(0, contacts); }),
        ListTile(leading: const Icon(Icons.table_chart_outlined), title: const Text('Excel CSV (.csv)'),
          onTap: () { Navigator.pop(context); _doExport(1, contacts); }),
        ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('JSON 備份'),
          onTap: () { Navigator.pop(context); _doExport(2, contacts); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<void> _doExport(int type, contacts) async {
    setState(() => _exporting = true);
    try {
      if (type == 0) await ExportService.exportVCard(contacts);
      else if (type == 1) await ExportService.exportCSV(contacts);
      else await ExportService.exportJSON(contacts);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯出失敗：$e')));
    } finally {
      setState(() => _exporting = false);
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('清除所有聯絡人'),
      content: const Text('此操作無法復原'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('確認清除', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) { await ContactStore.clearAll(); setState(() => _count = 0); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        _sectionLabel('Ollama 雲端 API'),
        _card([
          _fieldRow('API Key', Icons.key_outlined,
            TextField(
              controller: _apiKeyCtrl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'ollama_...',
                hintStyle: TextStyle(color: Colors.grey[300]),
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          _divider(),
          _fieldRow('模型', Icons.memory_outlined,
            TextField(controller: _modelCtrl,
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'llava:latest'),
              style: const TextStyle(fontSize: 14)),
          ),
          _divider(),
          _fieldRow('端點', Icons.link,
            TextField(controller: _urlCtrl, keyboardType: TextInputType.url,
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'https://api.ollama.com'),
              style: const TextStyle(fontSize: 14)),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('儲存設定'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a1a1a), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => launchUrl(Uri.parse('https://ollama.com/settings/api')),
          icon: const Icon(Icons.open_in_new, size: 14),
          label: const Text('取得 Ollama API Key'),
        ),

        _sectionLabel('資料管理'),
        _card([
          ListTile(leading: const Icon(Icons.people_outline), title: const Text('聯絡人數量'),
            trailing: Text('$_count 筆', style: TextStyle(color: Colors.grey[400]))),
          _divider(),
          ListTile(leading: const Icon(Icons.upload_outlined), title: const Text('匯出聯絡人'),
            subtitle: const Text('vCard · CSV · JSON'),
            trailing: _exporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right, color: Color(0xFFD0CEC7)),
            onTap: _exporting ? null : _export),
          _divider(),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('清除所有聯絡人', style: TextStyle(color: Colors.red)),
            subtitle: const Text('無法復原'),
            onTap: _clearAll),
        ]),

        _sectionLabel('關於'),
        _card([
          const ListTile(leading: Icon(Icons.info_outline), title: Text('名片掃描器'),
            trailing: Text('v1.1.0', style: TextStyle(color: Colors.grey))),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
  );

  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8E6DF))),
    child: Column(children: children),
  );

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _fieldRow(String label, IconData icon, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey[400]),
      const SizedBox(width: 10),
      SizedBox(width: 36, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
      Expanded(child: child),
    ]),
  );
}
