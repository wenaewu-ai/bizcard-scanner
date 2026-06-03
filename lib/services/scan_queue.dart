// lib/services/scan_queue.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import 'ollama_service.dart';
import 'settings_service.dart';
import 'contact_store.dart';

enum ScanJobStatus { pending, scanning, done, error }

class ScanJob {
  final String id;
  final File imageFile;
  ScanJobStatus status;
  Contact? result;
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
    final pending = jobs.where((j) => j.status == ScanJobStatus.pending).toList();
    if (pending.isEmpty) return;

    _processing = true;
    final job = pending.last;
    job.status = ScanJobStatus.scanning;
    notifyListeners();

    try {
      final settings = await AppSettings.load();

      if (settings.apiKey.isEmpty) {
        throw Exception('請先到「設定」填入 Ollama API Key');
      }

      // 壓縮圖片（簡單縮圖，不用 image 套件避免 isolate 問題）
      final b64 = await _compressToBase64(job.imageFile);

      final service = OllamaService(
        apiKey: settings.apiKey,
        model: settings.model,
        baseUrl: settings.baseUrl,
      );

      final contact = await service.scanCard(b64);
      await ContactStore.add(contact);

      job.result = contact;
      job.status = ScanJobStatus.done;
    } catch (e) {
      job.status = ScanJobStatus.error;
      job.errorMsg = e.toString().replaceAll('Exception: ', '');
    } finally {
      _processing = false;
      notifyListeners();
      // 繼續處理下一張
      _processNext();
    }
  }

  void removeJob(String id) {
    jobs.removeWhere((j) => j.id == id);
    notifyListeners();
  }

  void clearDone() {
    jobs.removeWhere((j) => j.status == ScanJobStatus.done);
    notifyListeners();
  }

  // 直接讀 bytes 轉 base64（image_picker 已經處理壓縮）
  static Future<String> _compressToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
