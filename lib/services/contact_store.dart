// lib/services/contact_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact.dart';

class ContactStore {
  static const _key = 'biz_contacts_v2';

  static Future<List<Contact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Contact.fromJson(e)).toList();
  }

  static Future<void> _save(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(contacts.map((c) => c.toJson()).toList()));
  }

  static Future<Contact> add(Contact contact) async {
    final contacts = await load();
    contacts.insert(0, contact);
    await _save(contacts);
    return contact;
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
