// lib/screens/qr_share_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/contact.dart';
import '../widgets/contact_avatar.dart';

class QRShareScreen extends StatefulWidget {
  final Contact contact;
  const QRShareScreen({super.key, required this.contact});
  @override
  State<QRShareScreen> createState() => _QRShareScreenState();
}

class _QRShareScreenState extends State<QRShareScreen> {
  final _qrKey = GlobalKey();
  bool _sharing = false;

  String get _vcard {
    final vc = widget.contact.toVCard();
    // vCard QR 上限約 2953 bytes；超出則省略地址備註
    if (vc.length > 2800) {
      final trimmed = widget.contact;
      final copy = Contact(
        id: trimmed.id, createdAt: trimmed.createdAt,
        name: trimmed.name, title: trimmed.title, department: trimmed.department,
        company: trimmed.company, taxId: trimmed.taxId,
        mobile: trimmed.mobile, phone: trimmed.phone,
        email: trimmed.email, website: trimmed.website, line: trimmed.line,
      );
      return copy.toVCard();
    }
    return vc;
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_card.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], subject: '${widget.contact.name} 的名片 QR');
    } finally {
      setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final isTrimmed = widget.contact.toVCard().length > 2800;

    return Scaffold(
      appBar: AppBar(title: const Text('分享名片 QR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // 聯絡人摘要
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E6DF)),
            ),
            child: Row(children: [
              ContactAvatar(name: c.name, size: 44),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text([c.title, c.company].where((s) => s.isNotEmpty).join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ])),
            ]),
          ),
          const SizedBox(height: 20),

          // QR Code
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8E6DF)),
            ),
            child: Column(children: [
              RepaintBoundary(
                key: _qrKey,
                child: QrImageView(
                  data: _vcard,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 14),
              Text('對方掃描後可直接存入通訊錄',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ]),
          ),
          const SizedBox(height: 16),

          // 包含欄位
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E6DF)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('QR 包含的資訊',
                style: TextStyle(fontSize: 11, color: Colors.grey[400], letterSpacing: 0.4)),
              const SizedBox(height: 8),
              for (final row in [
                if (c.mobile.isNotEmpty) '手機：${c.mobile}',
                if (c.phone.isNotEmpty) '市話：${c.phone}',
                if (c.email.isNotEmpty) 'Email：${c.email}',
                if (c.company.isNotEmpty) '公司：${c.company}',
                if (c.title.isNotEmpty) '職稱：${c.title}',
                if (!isTrimmed && c.address.isNotEmpty) '地址：${c.address}',
                if (c.website.isNotEmpty) '網址：${c.website}',
                if (c.line.isNotEmpty) 'LINE：${c.line}',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    const Icon(Icons.check, size: 13, color: Color(0xFF1D9E75)),
                    const SizedBox(width: 6),
                    Text(row, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
                  ]),
                ),
              if (isTrimmed) ...[
                const SizedBox(height: 6),
                Text('* 資料量較大，地址與備註已省略以確保 QR 可讀性',
                  style: TextStyle(fontSize: 11, color: Colors.red[300])),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // 分享按鈕
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_outlined),
              label: Text(_sharing ? '處理中...' : '儲存 / 分享 QR 圖片'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a1a1a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
