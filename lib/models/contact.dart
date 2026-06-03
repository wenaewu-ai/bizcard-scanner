// lib/models/contact.dart
import 'dart:convert';

class Contact {
  final String id;
  final DateTime createdAt;
  String name;
  String title;
  String department;
  String company;
  String taxId;
  String mobile;
  String phone;
  String fax;
  String email;
  String address;
  String website;
  String line;
  String notes;

  Contact({
    required this.id,
    required this.createdAt,
    this.name = '',
    this.title = '',
    this.department = '',
    this.company = '',
    this.taxId = '',
    this.mobile = '',
    this.phone = '',
    this.fax = '',
    this.email = '',
    this.address = '',
    this.website = '',
    this.line = '',
    this.notes = '',
  });

  factory Contact.empty() => Contact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
      );

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: j['id'] ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] ?? 0),
        name: j['name'] ?? '',
        title: j['title'] ?? '',
        department: j['department'] ?? '',
        company: j['company'] ?? '',
        taxId: j['taxId'] ?? '',
        mobile: j['mobile'] ?? '',
        phone: j['phone'] ?? '',
        fax: j['fax'] ?? '',
        email: j['email'] ?? '',
        address: j['address'] ?? '',
        website: j['website'] ?? '',
        line: j['line'] ?? '',
        notes: j['notes'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'name': name,
        'title': title,
        'department': department,
        'company': company,
        'taxId': taxId,
        'mobile': mobile,
        'phone': phone,
        'fax': fax,
        'email': email,
        'address': address,
        'website': website,
        'line': line,
        'notes': notes,
      };

  // 產生 vCard 3.0 字串
  String toVCard() {
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
      if (name.isNotEmpty) 'FN:$name',
      if (name.isNotEmpty) 'N:${name.split(' ').reversed.join(';')};;;',
      if (title.isNotEmpty || department.isNotEmpty)
        'TITLE:${[title, department].where((s) => s.isNotEmpty).join(' / ')}',
      if (company.isNotEmpty)
        'ORG:$company${department.isNotEmpty ? ';$department' : ''}',
      if (mobile.isNotEmpty) 'TEL;TYPE=CELL:$mobile',
      if (phone.isNotEmpty) 'TEL;TYPE=WORK:$phone',
      if (fax.isNotEmpty) 'TEL;TYPE=FAX:$fax',
      if (email.isNotEmpty) 'EMAIL:$email',
      if (address.isNotEmpty) 'ADR;TYPE=WORK:;;$address;;;;',
      if (website.isNotEmpty) 'URL:$website',
      if (line.isNotEmpty) 'X-LINE:$line',
      if (taxId.isNotEmpty) 'X-TAX-ID:$taxId',
      if (notes.isNotEmpty) 'NOTE:$notes',
      'END:VCARD',
    ];
    return lines.join('\r\n');
  }

  // 搜尋比對
  bool matches(String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        company.toLowerCase().contains(q) ||
        department.toLowerCase().contains(q) ||
        mobile.contains(query) ||
        phone.contains(query) ||
        email.toLowerCase().contains(q) ||
        taxId.contains(query);
  }

  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}';
    return name.substring(0, name.length.clamp(0, 2));
  }
}
