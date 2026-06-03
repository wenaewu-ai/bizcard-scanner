// lib/widgets/contact_avatar.dart
import 'package:flutter/material.dart';

const _bgs = [
  Color(0xFFE1F5EE), Color(0xFFE6F1FB), Color(0xFFFAEEDA),
  Color(0xFFFBEAF0), Color(0xFFEAF3DE),
];
const _fgs = [
  Color(0xFF0F6E56), Color(0xFF185FA5), Color(0xFF854F0B),
  Color(0xFF993556), Color(0xFF3B6D11),
];

class ContactAvatar extends StatelessWidget {
  final String name;
  final double size;

  const ContactAvatar({super.key, required this.name, this.size = 42});

  String get _initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}';
    return name.substring(0, name.length.clamp(0, 2));
  }

  @override
  Widget build(BuildContext context) {
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
