// lib/services/contact_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact.dart';

class DuplicateContact {
  final Contact existing;
  final Contact incoming;
  DuplicateContact({required this.existing, required this.incoming});
}

class ContactStore {
  static const _key = 'biz_contacts_v2';

  static Future<List<Contact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final contacts = list.map((e) => Contact.fromJson(e)).toList();
    // 依公司名稱排序，沒有公司的排最後
    contacts.sort((a, b) {
      final ca = a.company.toLowerCase();
      final cb = b.company.toLowerCase();
      if (ca.isEmpty && cb.isEmpty) return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (ca.isEmpty) return 1;
      if (cb.isEmpty) return -1;
      return ca.compareTo(cb);
    });
    return contacts;
  }

  static Future<void> _save(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(contacts.map((c) => c.toJson()).toList()));
  }

  // 檢查是否有重複手機號碼，回傳重複的聯絡人，沒有則回傳 null
  static Future<Contact?> findDuplicate(Contact incoming) async {
    if (incoming.mobile.isEmpty && incoming.phone.isEmpty) return null;
    final contacts = await load();

    // 正規化號碼（移除空白、-、( )）
    String normalize(String n) => n.replaceAll(RegExp(r'[\s\-()]'), '');

    final inMobile = normalize(incoming.mobile);
    final inPhone  = normalize(incoming.phone);

    for (final c in contacts) {
      final exMobile = normalize(c.mobile);
      final exPhone  = normalize(c.phone);

      if (inMobile.isNotEmpty && (inMobile == exMobile || inMobile == exPhone)) return c;
      if (inPhone.isNotEmpty  && (inPhone  == exMobile || inPhone  == exPhone))  return c;
    }
    return null;
  }

  // 直接新增（確認不重複後用）
  static Future<Contact> add(Contact contact) async {
    final contacts = await load();
    contacts.insert(0, contact);
    await _save(contacts);
    return contact;
  }

  // 更新舊的（用 incoming 的欄位覆蓋 existing，保留 id 和 createdAt）
  static Future<void> replaceWith(Contact existing, Contact incoming) async {
    final updated = Contact(
      id: existing.id,
      createdAt: existing.createdAt,
      name: incoming.name,
      title: incoming.title,
      department: incoming.department,
      company: incoming.company,
      taxId: incoming.taxId,
      mobile: incoming.mobile,
      phone: incoming.phone,
      fax: incoming.fax,
      email: incoming.email,
      address: incoming.address,
      website: incoming.website,
      line: incoming.line,
      notes: incoming.notes,
    );
    await update(updated);
  }

  static Future<void> update(Contact contact) async {
    final contacts = await load();
    final idx = contacts.indexWhere((c) => c.id == contact.id);
    if (idx >= 0) contacts[idx] = contact;
    await _save(contacts);
  }

  static Future<void> delete(String id) async {
    final contacts = await load();
    contacts.removeWhere((c) => c.id == id);
    await _save(contacts);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
