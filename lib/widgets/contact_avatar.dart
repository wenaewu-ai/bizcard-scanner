// lib/widgets/contact_avatar.dart
import 'package:flutter/material.dart';
import '../services/thumbnail_service.dart';

const _bgs = [
  Color(0xFFE1F5EE), Color(0xFFE6F1FB), Color(0xFFFAEEDA),
  Color(0xFFFBEAF0), Color(0xFFEAF3DE),
];
const _fgs = [
  Color(0xFF0F6E56), Color(0xFF185FA5), Color(0xFF854F0B),
  Color(0xFF993556), Color(0xFF3B6D11),
];

/// 有名片縮圖就顯示縮圖（圓角方形），沒有就退回彩色縮寫頭像（圓形）
class ContactAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? thumbnail; // base64 JPEG
  final String? cacheKey;  // 通常傳 contact.id，避免每次 build 都重新 decode

  const ContactAvatar({
    super.key,
    required this.name,
    this.size = 42,
    this.thumbnail,
    this.cacheKey,
  });

  String get _initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}';
    return name.substring(0, name.length.clamp(0, 2));
  }

  @override
  Widget build(BuildContext context) {
    final b64 = thumbnail;
    if (b64 != null && b64.isNotEmpty) {
      final bytes = ThumbCache.bytes(cacheKey ?? name, b64);
      if (bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _initialsBox(),
          ),
        );
      }
    }
    return _initialsBox();
  }

  Widget _initialsBox() {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _bgs.length;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _bgs[idx], shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.33,
          fontWeight: FontWeight.w600,
          color: _fgs[idx],
        ),
      ),
    );
  }
}
