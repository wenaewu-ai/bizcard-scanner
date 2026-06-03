// lib/screens/scan_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/contact.dart';
import '../services/scan_queue.dart';
import 'edit_contact_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _queue = ScanQueue.instance;

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

  void _onQueueUpdate() => setState(() {});

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (xfile == null) return;
    _queue.addJob(File(xfile.path));
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _queue.jobs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描名片'),
        actions: [
          if (jobs.any((j) => j.status == ScanJobStatus.done))
            TextButton(
              onPressed: _queue.clearDone,
              child: const Text('清除完成'),
            ),
        ],
      ),
      body: Column(children: [
        // 拍照按鈕列
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('拍照掃描'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a1a1a),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('相簿'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Color(0xFFD0CEC7)),
              ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E6DF)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 縮圖
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(job.imageFile, width: 64, height: 64, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 狀態列
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

          // 辨識結果摘要
          if (job.status == ScanJobStatus.done && job.result != null) ...[
            Text(
              job.result!.name.isNotEmpty ? job.result!.name : '（未辨識到姓名）',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (job.result!.company.isNotEmpty)
              Text(job.result!.company,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            if (job.result!.mobile.isNotEmpty)
              Text(job.result!.mobile,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            const SizedBox(height: 6),
            Row(children: [
              _smallBtn(
                icon: Icons.check_circle_outline,
                label: '已存入聯絡人',
                color: const Color(0xFF1D9E75),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final updated = await Navigator.push<Contact>(context,
                    MaterialPageRoute(builder: (_) => EditContactScreen(contact: job.result!)));
                  if (updated != null) setState(() => job.result = updated);
                },
                child: _smallBtn(icon: Icons.edit_outlined, label: '編輯', color: Colors.grey),
              ),
            ]),
          ],

          if (job.status == ScanJobStatus.scanning)
            const Text('辨識中...', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),

          if (job.status == ScanJobStatus.pending)
            const Text('等待辨識', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),

          if (job.status == ScanJobStatus.error)
            Text(
              '失敗：${job.errorMsg ?? '未知錯誤'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFE24B4A)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ])),
      ]),
    );
  }

  Widget _statusBadge(ScanJobStatus status) {
    final map = {
      ScanJobStatus.pending:  (const Color(0xFFF1EFE8), const Color(0xFF888780), '等待中'),
      ScanJobStatus.scanning: (const Color(0xFFE6F1FB), const Color(0xFF185FA5), '辨識中'),
      ScanJobStatus.done:     (const Color(0xFFE1F5EE), const Color(0xFF0F6E56), '完成'),
      ScanJobStatus.error:    (const Color(0xFFFCEBEB), const Color(0xFFA32D2D), '失敗'),
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

  Widget _smallBtn({required IconData icon, required String label, required Color color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 12, color: color)),
    ]);
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.document_scanner_outlined, size: 52, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('點擊「拍照掃描」開始', style: TextStyle(fontSize: 15, color: Colors.grey[400])),
      const SizedBox(height: 4),
      Text('可連續拍多張，系統會依序辨識', style: TextStyle(fontSize: 13, color: Colors.grey[300])),
    ]),
  );
}
