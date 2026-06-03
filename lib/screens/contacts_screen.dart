// lib/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact.dart';
import '../services/contact_store.dart';
import '../services/scan_queue.dart';
import '../widgets/contact_avatar.dart';
import 'qr_share_screen.dart';
import 'edit_contact_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _all = [];
  List<Contact> _filtered = [];
  List<Contact> _suggestions = [];
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSugg = false;
  bool _loading = true;
  final _queue = ScanQueue.instance;

  @override
  void initState() {
    super.initState();
    _load();
    // 監聽 queue 更新 → 有新聯絡人存入時自動刷新
    _queue.addListener(_onQueueUpdate);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) setState(() => _showSugg = false);
    });
  }

  @override
  void dispose() {
    _queue.removeListener(_onQueueUpdate);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueueUpdate() {
    // 當有 job 變成 done，重新載入聯絡人
    if (_queue.jobs.any((j) => j.status == ScanJobStatus.done)) {
      _load();
    }
  }

  Future<void> _load() async {
    final contacts = await ContactStore.load();
    if (!mounted) return;
    setState(() {
      _all = contacts;
      _applyFilter(_searchCtrl.text);
      _loading = false;
    });
  }

  void _applyFilter(String q) {
    if (q.isEmpty) {
      _filtered = List.from(_all);
      _suggestions = [];
      _showSugg = false;
    } else {
      _filtered = _all.where((c) => c.matches(q)).toList();
      _suggestions = _filtered.take(6).toList();
    }
  }

  void _onSearch(String q) {
    setState(() {
      _applyFilter(q);
      _showSugg = q.isNotEmpty && _suggestions.isNotEmpty;
    });
  }

  void _openDetail(Contact c) {
    setState(() => _showSugg = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        contact: c,
        onDelete: () async {
          await ContactStore.delete(c.id);
          _load();
        },
        onQR: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => QRShareScreen(contact: c))),
        onEdit: () async {
          final updated = await Navigator.push<Contact>(context,
            MaterialPageRoute(builder: (_) => EditContactScreen(contact: c)));
          if (updated != null) {
            await ContactStore.update(updated);
            _load();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聯絡人'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('${_all.length} 筆',
                style: TextStyle(fontSize: 13, color: Colors.grey[400])),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // 搜尋列
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _focusNode,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: '搜尋姓名、公司、手機、統編...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () { _searchCtrl.clear(); _onSearch(''); },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8E6DF))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8E6DF))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFB0AEAA))),
            ),
          ),
        ),

        // 自動完成下拉
        if (_showSugg)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E6DF)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: _suggestions.map((c) => ListTile(
                  dense: true,
                  leading: ContactAvatar(name: c.name, size: 32),
                  title: _Highlight(text: c.name, query: _searchCtrl.text),
                  subtitle: Text(
                    [c.company, c.mobile].where((s) => s.isNotEmpty).join('  '),
                    style: const TextStyle(fontSize: 11)),
                  onTap: () => _openDetail(c),
                )).toList(),
              ),
            ),
          ),

        // 聯絡人列表
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _all.isEmpty
              ? _buildEmpty('尚無聯絡人', '請先到「掃描」頁面新增')
              : _filtered.isEmpty
                ? _buildEmpty('找不到符合的聯絡人', '')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        return GestureDetector(
                          onTap: () => _openDetail(c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE8E6DF)),
                            ),
                            child: Row(children: [
                              ContactAvatar(name: c.name),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Highlight(
                                    text: c.name.isEmpty ? '（未知）' : c.name,
                                    query: _searchCtrl.text,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                  if (c.title.isNotEmpty || c.company.isNotEmpty)
                                    Text(
                                      [c.title, c.company].where((s) => s.isNotEmpty).join(' · '),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              )),
                              Text(c.mobile.isNotEmpty ? c.mobile : c.phone,
                                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ]),
    );
  }

  Widget _buildEmpty(String title, String sub) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.contacts_outlined, size: 52, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[400])),
      if (sub.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(fontSize: 13, color: Colors.grey[300])),
      ],
    ]),
  );
}

// ── Highlight ────────────────────────────────────────────────────────────────
class _Highlight extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  const _Highlight({required this.text, required this.query, this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) return Text(text, style: style);
    final base = style ?? const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1a1a1a));
    return Text.rich(TextSpan(children: [
      TextSpan(text: text.substring(0, idx), style: base),
      TextSpan(text: text.substring(idx, idx + query.length),
        style: base.copyWith(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
      TextSpan(text: text.substring(idx + query.length), style: base),
    ]));
  }
}

// ── Detail bottom sheet ───────────────────────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final Contact contact;
  final VoidCallback onDelete;
  final VoidCallback onQR;
  final VoidCallback onEdit;
  const _DetailSheet({required this.contact, required this.onDelete,
    required this.onQR, required this.onEdit});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = contact;
    // (icon, label, launchUrl, displayText)
    final rows = <(IconData, String, String?, String)>[
      if (c.mobile.isNotEmpty)  (Icons.phone_android,      '手機',  'tel:${c.mobile}',          c.mobile),
      if (c.phone.isNotEmpty)   (Icons.phone_outlined,     '市話',  'tel:${c.phone}',            c.phone),
      if (c.fax.isNotEmpty)     (Icons.fax_outlined,       '傳真',  null,                        c.fax),
      if (c.email.isNotEmpty)   (Icons.email_outlined,     'Email', 'mailto:${c.email}',         c.email),
      if (c.website.isNotEmpty) (Icons.language,           '網址',  c.website.startsWith('http') ? c.website : 'https://${c.website}', c.website),
      if (c.address.isNotEmpty) (Icons.location_on_outlined,'地址', 'geo:0,0?q=${Uri.encodeComponent(c.address)}', c.address),
      if (c.line.isNotEmpty)    (Icons.chat_outlined,      'LINE',  'https://line.me/ti/p/~${c.line}', c.line),
      if (c.taxId.isNotEmpty)   (Icons.tag,                '統編',  null,                        c.taxId),
      if (c.notes.isNotEmpty)   (Icons.note_outlined,      '備註',  null,                        c.notes),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFE0DDD5), borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              ContactAvatar(name: c.name, size: 50),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name.isEmpty ? '（未知）' : c.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                Text(
                  [c.title, c.department, c.company].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ])),
              IconButton(onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close), color: Colors.grey[400]),
            ]),
          ),
          const Divider(height: 1),
          // 欄位列表
          Expanded(child: ListView(controller: ctrl, children: [
            for (final r in rows)
              ListTile(
                leading: Icon(r.$1, color: Colors.grey[400], size: 22),
                title: Text(r.$2, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                subtitle: Text(r.$4,
                  style: TextStyle(fontSize: 15,
                    color: r.$3 != null ? const Color(0xFF185FA5) : const Color(0xFF1a1a1a))),
                trailing: r.$3 != null
                  ? const Icon(Icons.chevron_right, color: Color(0xFFD0CEC7))
                  : null,
                onTap: r.$3 != null ? () => _launch(r.$3!) : null,
              ),
          ])),
          // 操作按鈕
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); onQR(); },
                icon: const Icon(Icons.qr_code),
                label: const Text('分享 QR'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFD0CEC7)),
                ),
              )),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () { Navigator.pop(context); onEdit(); },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('編輯'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFD0CEC7)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => AlertDialog(
                    title: const Text('確認刪除'),
                    content: Text('刪除「${c.name}」？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                      TextButton(
                        onPressed: () { Navigator.pop(context); onDelete(); },
                        child: const Text('刪除', style: TextStyle(color: Colors.red))),
                    ],
                  ));
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Color(0xFFF0C0C0)),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
