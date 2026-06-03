// lib/screens/edit_contact_screen.dart
import 'package:flutter/material.dart';
import '../models/contact.dart';

class EditContactScreen extends StatefulWidget {
  final Contact contact;
  const EditContactScreen({super.key, required this.contact});
  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  late final Map<String, TextEditingController> _ctrls;

  final _fields = [
    ('name',       '姓名',   Icons.person_outline,       TextInputType.name),
    ('title',      '職稱',   Icons.work_outline,          TextInputType.text),
    ('department', '部門',   Icons.group_outlined,        TextInputType.text),
    ('company',    '公司',   Icons.business_outlined,     TextInputType.text),
    ('taxId',      '統編',   Icons.tag,                   TextInputType.number),
    ('mobile',     '手機',   Icons.phone_android,         TextInputType.phone),
    ('phone',      '市話',   Icons.phone_outlined,        TextInputType.phone),
    ('fax',        '傳真',   Icons.fax_outlined,          TextInputType.phone),
    ('email',      'Email',  Icons.email_outlined,        TextInputType.emailAddress),
    ('address',    '地址',   Icons.location_on_outlined,  TextInputType.streetAddress),
    ('website',    '網址',   Icons.language,              TextInputType.url),
    ('line',       'LINE',   Icons.chat_outlined,         TextInputType.text),
    ('notes',      '備註',   Icons.note_outlined,         TextInputType.multiline),
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _ctrls = {
      'name':       TextEditingController(text: c.name),
      'title':      TextEditingController(text: c.title),
      'department': TextEditingController(text: c.department),
      'company':    TextEditingController(text: c.company),
      'taxId':      TextEditingController(text: c.taxId),
      'mobile':     TextEditingController(text: c.mobile),
      'phone':      TextEditingController(text: c.phone),
      'fax':        TextEditingController(text: c.fax),
      'email':      TextEditingController(text: c.email),
      'address':    TextEditingController(text: c.address),
      'website':    TextEditingController(text: c.website),
      'line':       TextEditingController(text: c.line),
      'notes':      TextEditingController(text: c.notes),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  void _save() {
    final c = widget.contact;
    c.name       = _ctrls['name']!.text;
    c.title      = _ctrls['title']!.text;
    c.department = _ctrls['department']!.text;
    c.company    = _ctrls['company']!.text;
    c.taxId      = _ctrls['taxId']!.text;
    c.mobile     = _ctrls['mobile']!.text;
    c.phone      = _ctrls['phone']!.text;
    c.fax        = _ctrls['fax']!.text;
    c.email      = _ctrls['email']!.text;
    c.address    = _ctrls['address']!.text;
    c.website    = _ctrls['website']!.text;
    c.line       = _ctrls['line']!.text;
    c.notes      = _ctrls['notes']!.text;
    Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('編輯聯絡人'),
        actions: [TextButton(onPressed: _save, child: const Text('儲存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E6DF)),
            ),
            child: Column(
              children: _fields.asMap().entries.map((entry) {
                final i = entry.key;
                final f = entry.value;
                return Column(children: [
                  if (i > 0) const Divider(height: 1, indent: 48),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(children: [
                      Icon(f.$3, size: 18, color: Colors.grey[400]),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 36,
                        child: Text(f.$2, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ),
                      Expanded(child: TextField(
                        controller: _ctrls[f.$1],
                        keyboardType: f.$4,
                        maxLines: f.$1 == 'notes' ? 3 : 1,
                        decoration: InputDecoration(
                          hintText: '（空）',
                          hintStyle: TextStyle(color: Colors.grey[300], fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                      )),
                    ]),
                  ),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a1a1a), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('儲存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
