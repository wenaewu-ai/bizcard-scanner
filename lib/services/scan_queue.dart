// lib/services/scan_queue.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import 'ollama_service.dart';
import 'settings_service.dart';
import 'contact_store.dart';
import 'gcis_service.dart';

enum ScanJobStatus { pending, scanning, duplicate, done, error }

class ScanJob {
  final String id;
  final File imageFile;
  ScanJobStatus status;
  Contact? result;
  Contact? duplicateOf; // 發現重複時，這是已存在的聯絡人
  String? errorMsg;

  ScanJob({required this.id, required this.imageFile})
      : status = ScanJobStatus.pending;
}

class ScanQueue extends ChangeNotifier {
  static final ScanQueue instance = ScanQueue._();
  ScanQueue._();

  final List<ScanJob> jobs = [];
  bool _processing = false;

  void addJob(File imageFile) {
    final job = ScanJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imageFile: imageFile,
    );
    jobs.insert(0, job);
    notifyListeners();
    _processNext();
  }

  Future<void> _processNext() async {
    if (_processing) return;
    // 有 duplicate 狀態的 job 在等用戶決定，先不處理後面的
    if (jobs.any((j) => j.status == ScanJobStatus.duplicate)) return;

    final pending = jobs.where((j) => j.status == ScanJobStatus.pending).toList();
    if (pending.isEmpty) return;

    _processing = true;
    final job = pending.last;
    job.status = ScanJobStatus.scanning;
    notifyListeners();

    try {
      final settings = await AppSettings.load();
      if (settings.apiKey.isEmpty) throw Exception('請先到「設定」填入 Ollama API Key');

      final b64 = await _toBase64(job.imageFile);
      final service = OllamaService(
        apiKey: settings.apiKey,
        model: settings.model,
        baseUrl: settings.baseUrl,
      );
      final contact = await service.scanCard(b64);

      job.result = contact;

      // 檢查重複
      final existing = await ContactStore.findDuplicate(contact);
      if (existing != null) {
        job.status = ScanJobStatus.duplicate;
        job.duplicateOf = existing;
        // 不繼續處理，等用戶決定
      } else {
        await ContactStore.add(contact);
        job.status = ScanJobStatus.done;

        // 非同步查統編行業（失敗不影響任何事）
        if (contact.taxId.isNotEmpty) {
          GcisService.lookupIndustry(contact.taxId).then((industry) async {
            if (industry != null && industry.isNotEmpty) {
              contact.industry = industry;
              await ContactStore.update(contact);
              notifyListeners();
            }
          }).catchError((_) {});
        }
      }
    } catch (e) {
      job.status = ScanJobStatus.error;
      job.errorMsg = e.toString().replaceAll('Exception: ', '');
    } finally {
      _processing = false;
      notifyListeners();
      if (!jobs.any((j) => j.status == ScanJobStatus.duplicate)) {
        _processNext();
      }
    }
  }

  // 用戶選「另存新的」
  Future<void> resolveKeepBoth(String jobId) async {
    final job = jobs.firstWhere((j) => j.id == jobId);
    if (job.result == null) return;
    await ContactStore.add(job.result!);
    job.status = ScanJobStatus.done;
    job.duplicateOf = null;
    notifyListeners();
    _processNext();
  }

  // 用戶選「更新舊的」
  Future<void> resolveUpdate(String jobId) async {
    final job = jobs.firstWhere((j) => j.id == jobId);
    if (job.result == null || job.duplicateOf == null) return;
    await ContactStore.replaceWith(job.duplicateOf!, job.result!);
    job.status = ScanJobStatus.done;
    job.duplicateOf = null;
    notifyListeners();
    _processNext();
  }

  // 用戶選「略過」
  void resolveSkip(String jobId) {
    final job = jobs.firstWhere((j) => j.id == jobId);
    job.status = ScanJobStatus.done;
    job.duplicateOf = null;
    notifyListeners();
    _processNext();
  }

  void retryJob(String id) {
    final job = jobs.firstWhere((j) => j.id == id, orElse: () => throw Exception('Job not found'));
    job.status = ScanJobStatus.pending;
    job.errorMsg = null;
    notifyListeners();
    _processNext();
  }

  void removeJob(String id) {
    jobs.removeWhere((j) => j.id == id);
    notifyListeners();
  }

  void clearDone() {
    jobs.removeWhere((j) => j.status == ScanJobStatus.done);
    notifyListeners();
  }

  static Future<String> _toBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
