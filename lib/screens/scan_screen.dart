// lib/screens/scan_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/contact.dart';
import '../services/scan_queue.dart';
import '../services/contact_store.dart';
import '../widgets/contact_avatar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'camera_screen.dart';
import 'edit_contact_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _queue = ScanQueue.instance;
  String? _handlingDuplicateId;

  @override
  void initState() {
    super.initState();
    _queue.addListener(_onQueueUpdate);
  }

  @override
  void dispose() {
    _queue.removeListener(_onQueueUpdate);
    super.dispose();
  }

  void _onQueueUpdate() {
    setState(() {});
    final dups = _queue.jobs.where((j) => j.status == ScanJobStatus.duplicate).toList();
    if (dups.isNotEmpty && _handlingDuplicateId != dups.first.id) {
      _handlingDuplicateId = dups.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDuplicateDialog(dups.first));
    }
  }

  // 開啟內建相機
  Future<void> _openCamera({bool continuous = false}) async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) return;
    }
    if (!mounted) return;

    // 計算可拍上限：總上限 10，減去目前佇列中還沒完成的筆數
    const totalLimit = 10;
    final inQueue = _queue.jobs
        .where((j) => j.status == ScanJobStatus.pending || j.status == ScanJobStatus.scanning)
        .length;
    final canShoot = (totalLimit - inQueue).clamp(0, totalLimit);

    if (canShoot == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('目前佇列已有 10 筆待辨識，請等待完成後再拍'),
          backgroundColor: Color(0xFF1a1a1a),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CameraScreen(
        continuous: continuous,
        maxShots: canShoot,
        onCapture: (file) => _queue.addJob(file),
      ),
    ));
  }

  // 從相簿選取
  Future<void> _pickFromGallery() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 90, maxWidth: 2000, maxHeight: 2000,
    );
    if (xfile == null) return;
    _queue.addJob(File(xfile.path));
  }

  void _showDuplicateDialog(ScanJob job) {
    final incoming = job.result!;
    final existing = job.duplicateOf!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('偵測到重複名片'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('手機號碼相同，可能是同一人：',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 12),
          _dupCard('已存在', existing, const Color(0xFFE6F1FB), const Color(0xFF185FA5)),
          const SizedBox(height: 8),
          _dupCard('新掃描', incoming, const Color(0xFFE1F5EE), const Color(0xFF0F6E56)),
        ]),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _handlingDuplicateId = null; _queue.resolveSkip(job.id); },
            child: const Text('略過'),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _handlingDuplicateId = null; _queue.resolveKeepBoth(job.id); },
            child: const Text('另存新的'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _handlingDuplicateId = null; _queue.resolveUpdate(job.id); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a1a1a), foregroundColor: Colors.white),
            child: const Text('更新舊的'),
          ),
        ],
      ),
    );
  }

  Widget _dupCard(String label, Contact c, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        ContactAvatar(name: c.name, size: 36),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          Text(c.name.isEmpty ? '（未知）' : c.name,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
          if (c.company.isNotEmpty) Text(c.company, style: TextStyle(fontSize: 12, color: fg.withOpacity(0.7))),
          if (c.mobile.isNotEmpty) Text(c.mobile, style: TextStyle(fontSize: 12, color: fg.withOpacity(0.7))),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _queue.jobs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描名片'),
        actions: [
          if (jobs.any((j) => j.status == ScanJobStatus.done))
            TextButton(onPressed: _queue.clearDone, child: const Text('清除完成')),
        ],
      ),
      body: Column(children: [
        // 按鈕列
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openCamera(),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('拍照'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a1a1a),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openCamera(continuous: true),
                icon: const Icon(Icons.camera_enhance_outlined),
                label: const Text('連續掃描'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _pickFromGallery,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Color(0xFFD0CEC7)),
              ),
              child: const Icon(Icons.image_outlined, size: 22),
            ),
          ]),
        ),

        if (jobs.isEmpty)
          Expanded(child: _buildEmpty())
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildJobCard(jobs[i]),
            ),
          ),
      ]),
    );
  }

  Widget _buildJobCard(ScanJob job) {
    return GestureDetector(
      onTap: job.status == ScanJobStatus.done && job.result != null
        ? () async {
            final updated = await Navigator.push<Contact>(context,
              MaterialPageRoute(builder: (_) => EditContactScreen(contact: job.result!)));
            if (updated != null) {
              await ContactStore.update(updated);
              setState(() => job.result = updated);
            }
          }
        : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: job.status == ScanJobStatus.duplicate
              ? const Color(0xFFEF9F27) : const Color(0xFFE8E6DF),
            width: job.status == ScanJobStatus.duplicate ? 1.5 : 0.5,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(job.imageFile, width: 64, height: 64, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _statusBadge(job.status),
              const Spacer(),
              if (job.status == ScanJobStatus.error || job.status == ScanJobStatus.done)
                GestureDetector(
                  onTap: () => _queue.removeJob(job.id),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFFAAAAAA)),
                ),
            ]),
            const SizedBox(height: 6),

            if (job.status == ScanJobStatus.done && job.result != null) ...[
              Text(job.result!.name.isNotEmpty ? job.result!.name : '（未辨識到姓名）',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (job.result!.company.isNotEmpty)
                Text(job.result!.company, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              if (job.result!.mobile.isNotEmpty)
                Text(job.result!.mobile, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF1D9E75)),
                const SizedBox(width: 3),
                const Text('已存入・點卡片可編輯',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1D9E75))),
              ]),
            ],

            if (job.status == ScanJobStatus.duplicate) ...[
              Text(job.result?.name ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFBA7517)),
                const SizedBox(width: 4),
                const Text('與現有聯絡人手機相同', style: TextStyle(fontSize: 12, color: Color(0xFFBA7517))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                _smallActionBtn('更新舊的', const Color(0xFF1a1a1a), Colors.white,
                  () { _handlingDuplicateId = null; _queue.resolveUpdate(job.id); }),
                const SizedBox(width: 6),
                _smallActionBtn('另存新的', Colors.transparent, const Color(0xFF1a1a1a),
                  () { _handlingDuplicateId = null; _queue.resolveKeepBoth(job.id); },
                  border: const Color(0xFFD0CEC7)),
                const SizedBox(width: 6),
                _smallActionBtn('略過', Colors.transparent, Colors.grey,
                  () { _handlingDuplicateId = null; _queue.resolveSkip(job.id); },
                  border: const Color(0xFFE0DDD5)),
              ]),
            ],

            if (job.status == ScanJobStatus.scanning)
              const Text('辨識中...', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),

            if (job.status == ScanJobStatus.pending)
              const Text('等待辨識', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),

            if (job.status == ScanJobStatus.error) ...[
              Text('失敗：${job.errorMsg ?? "未知錯誤"}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFE24B4A)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              _smallActionBtn('重試', const Color(0xFF1a1a1a), Colors.white,
                () => _queue.retryJob(job.id)),
            ],
          ])),
        ]),
      ),
    );
  }

  Widget _smallActionBtn(String label, Color bg, Color fg, VoidCallback onTap, {Color? border}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _statusBadge(ScanJobStatus status) {
    final map = {
      ScanJobStatus.pending:   (const Color(0xFFF1EFE8), const Color(0xFF888780), '等待中'),
      ScanJobStatus.scanning:  (const Color(0xFFE6F1FB), const Color(0xFF185FA5), '辨識中'),
      ScanJobStatus.duplicate: (const Color(0xFFFAEEDA), const Color(0xFFBA7517), '重複'),
      ScanJobStatus.done:      (const Color(0xFFE1F5EE), const Color(0xFF0F6E56), '完成'),
      ScanJobStatus.error:     (const Color(0xFFFCEBEB), const Color(0xFFA32D2D), '失敗'),
    };
    final (bg, fg, label) = map[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (status == ScanJobStatus.scanning)
          SizedBox(width: 10, height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: fg)),
        if (status == ScanJobStatus.scanning) const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.document_scanner_outlined, size: 52, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('點擊「拍照」或「連續掃描」開始', style: TextStyle(fontSize: 15, color: Colors.grey[400])),
      const SizedBox(height: 4),
      Text('對準名片後自動拍攝', style: TextStyle(fontSize: 13, color: Colors.grey[300])),
    ]),
  );
}
