import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/thumbnail_service.dart';

/// 全螢幕檢視名片縮圖（可雙指縮放）
class CardImageView extends StatelessWidget {
  final Contact contact;
  const CardImageView({super.key, required this.contact});

  static void open(BuildContext context, Contact contact) {
    if (!contact.hasThumbnail) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CardImageView(contact: contact),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = ThumbCache.bytes(contact.id, contact.thumbnail);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          contact.name.isEmpty ? '名片' : contact.name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: bytes == null
            ? const Text('縮圖無法顯示',
                style: TextStyle(color: Colors.white54, fontSize: 14))
            : InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
      ),
    );
  }
}
