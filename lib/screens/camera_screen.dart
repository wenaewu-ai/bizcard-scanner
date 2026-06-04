// lib/screens/camera_screen.dart
// 內建相機 + 自動偵測名片文字區塊後拍照
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  final bool continuous; // 拍完後是否繼續掃
  final void Function(File image) onCapture;

  const CameraScreen({
    super.key,
    required this.onCapture,
    this.continuous = false,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _ctrl;
  bool _initialized = false;
  bool _processing = false;
  bool _detected = false;      // 偵測到名片
  bool _capturing = false;     // 正在拍照
  int _stableFrames = 0;       // 連續偵測到的 frame 數
  static const _stableThreshold = 8; // 需要連續 8 frame 才拍（約 1 秒）
  Timer? _scanTimer;
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);

  // 提示文字
  String _hint = '對準名片';
  Color _borderColor = Colors.white38;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanTimer?.cancel();
    _ctrl?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _ctrl?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    // 先請求相機權限
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('需要相機權限'),
            content: const Text('請到手機設定開啟 Cardify 的相機權限'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              TextButton(
                onPressed: () { Navigator.pop(context); openAppSettings(); },
                child: const Text('去設定')),
            ],
          ),
        );
      }
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _ctrl = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _ctrl!.initialize();
    if (!mounted) return;

    await _ctrl!.setFocusMode(FocusMode.auto);
    await _ctrl!.setExposureMode(ExposureMode.auto);

    setState(() => _initialized = true);

    // 開始定期掃描 frame（每 300ms）
    _scanTimer = Timer.periodic(const Duration(milliseconds: 300), (_) => _scanFrame());
  }

  Future<void> _scanFrame() async {
    if (_processing || _capturing || _ctrl == null || !_ctrl!.value.isInitialized) return;
    _processing = true;

    try {
      final image = await _ctrl!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final result = await _textRecognizer.processImage(inputImage);

      // 清理暫存
      File(image.path).deleteSync();

      // 判斷是否像名片：有足夠的文字區塊
      final hasEnoughText = result.blocks.length >= 2 &&
          result.text.trim().length > 10;

      if (hasEnoughText) {
        _stableFrames++;
        if (_stableFrames >= _stableThreshold) {
          _stableFrames = 0;
          await _capture();
          return;
        }
        if (mounted) setState(() {
          _detected = true;
          _borderColor = const Color(0xFF1D9E75);
          _hint = '偵測到名片，保持穩定...';
        });
      } else {
        _stableFrames = 0;
        if (mounted) setState(() {
          _detected = false;
          _borderColor = Colors.white38;
          _hint = '對準名片';
        });
      }
    } catch (_) {
      _stableFrames = 0;
    } finally {
      _processing = false;
    }
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() {
      _capturing = true;
      _hint = '已拍攝！';
      _borderColor = Colors.white;
    });
    _scanTimer?.cancel();

    try {
      final image = await _ctrl!.takePicture();
      final dir = await getTemporaryDirectory();
      final dest = '${dir.path}/cardify_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(image.path).copy(dest);

      widget.onCapture(File(dest));

      if (widget.continuous && mounted) {
        // 連續模式：短暫提示後繼續掃
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _capturing = false;
            _detected = false;
            _borderColor = Colors.white38;
            _hint = '對準下一張名片';
          });
          _scanTimer = Timer.periodic(
            const Duration(milliseconds: 300), (_) => _scanFrame());
        }
      } else {
        // 單張模式：拍完回上一頁
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() { _capturing = false; _hint = '拍攝失敗，請重試'; });
      _scanTimer = Timer.periodic(
        const Duration(milliseconds: 300), (_) => _scanFrame());
    }
  }

  // 手動拍照按鈕
  Future<void> _manualCapture() async {
    _stableFrames = _stableThreshold; // 跳過穩定計數
    await _capture();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 相機預覽
        if (_initialized && _ctrl != null)
          Positioned.fill(child: CameraPreview(_ctrl!))
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // 名片對準框
        if (_initialized)
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: MediaQuery.of(context).size.width * 0.82,
              height: MediaQuery.of(context).size.width * 0.82 / 1.6,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _borderColor,
                  width: _detected ? 3 : 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

        // 上方提示
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 0, right: 0,
          child: Column(children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _detected ? const Color(0xFF1D9E75) : Colors.white,
                decoration: TextDecoration.none,
              ),
              child: Text(_hint, textAlign: TextAlign.center),
            ),
            if (widget.continuous) ...[
              const SizedBox(height: 4),
              const Text('按關閉結束連續掃描',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54,
                  decoration: TextDecoration.none)),
            ],
          ]),
        ),

        // 底部按鈕列
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 32,
          left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            // 關閉
            _circleBtn(Icons.close, Colors.white54, () => Navigator.pop(context)),
            // 手動拍照
            GestureDetector(
              onTap: _capturing ? null : _manualCapture,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: _capturing ? Colors.white38 : Colors.white24,
                ),
                child: _capturing
                  ? const Center(child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera, color: Colors.white, size: 32),
              ),
            ),
            // 閃光燈
            _circleBtn(Icons.flash_auto, Colors.white54, () async {
              final mode = _ctrl?.value.flashMode;
              await _ctrl?.setFlashMode(
                mode == FlashMode.off ? FlashMode.torch : FlashMode.off);
              setState(() {});
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black38,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
