// lib/screens/camera_screen.dart
// 內建相機：對焦穩定後自動拍照，不依賴 ML Kit
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  final bool continuous;
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
  bool _capturing = false;
  bool _focused = false;
  int _stableCount = 0;
  Timer? _autoTimer;
  Timer? _countdownTimer;
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoTimer?.cancel();
    _countdownTimer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _autoTimer?.cancel();
      _ctrl?.dispose();
      _ctrl = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final ctrl = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await ctrl.initialize();
    if (!mounted) return;

    await ctrl.setFocusMode(FocusMode.auto);
    await ctrl.setExposureMode(ExposureMode.auto);

    setState(() {
      _ctrl = ctrl;
      _initialized = true;
    });

    // 監聽對焦狀態
    ctrl.addListener(_onCameraUpdate);

    // 自動拍照：2秒後如果沒手動拍就自動觸發
    _startAutoTimer();
  }

  void _onCameraUpdate() {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    final isFocused = !_ctrl!.value.isTakingPicture;
    if (isFocused != _focused && mounted) {
      setState(() => _focused = isFocused);
    }
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _countdownTimer?.cancel();
    _stableCount = 0;

    // 倒數 3 秒自動拍照
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        if (!_capturing) _capture();
      }
    });
  }

  Future<void> _capture() async {
    if (_capturing || _ctrl == null || !_ctrl!.value.isInitialized) return;
    _autoTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() { _capturing = true; _countdown = 0; });

    try {
      final image = await _ctrl!.takePicture();
      final dir = await getTemporaryDirectory();
      final dest = '${dir.path}/cardify_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(image.path).copy(dest);
      widget.onCapture(File(dest));

      if (widget.continuous && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() { _capturing = false; _focused = false; });
          _startAutoTimer();
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _capturing = false; });
        _startAutoTimer();
      }
    }
  }

  // 手動點擊對焦並重置計時器
  Future<void> _onTapFocus(TapDownDetails details) async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    final size = MediaQuery.of(context).size;
    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;
    try {
      await _ctrl!.setFocusPoint(Offset(x, y));
      await _ctrl!.setExposurePoint(Offset(x, y));
    } catch (_) {}
    _startAutoTimer(); // 點對焦後重新開始計時
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapFocus,
        child: Stack(children: [
          // 相機預覽
          if (_initialized && _ctrl != null)
            Positioned.fill(child: CameraPreview(_ctrl!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 名片對準框
          if (_initialized)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: MediaQuery.of(context).size.width * 0.85 / 1.6,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _capturing
                      ? Colors.white
                      : (_countdown <= 1 ? const Color(0xFF1D9E75) : Colors.white70),
                    width: _countdown <= 1 ? 3 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

          // 上方提示
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Column(children: [
              Text(
                _capturing
                  ? '拍攝中...'
                  : _countdown > 0
                    ? '對準名片　$_countdown 秒後自動拍攝'
                    : '準備拍攝...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500,
                  color: _countdown <= 1 && !_capturing
                    ? const Color(0xFF4ADE80) : Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              if (widget.continuous) ...[
                const SizedBox(height: 4),
                const Text('連續掃描中・按關閉結束',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white54,
                    decoration: TextDecoration.none)),
              ],
              const SizedBox(height: 6),
              const Text('點擊畫面可對焦・點快門立即拍攝',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white38,
                  decoration: TextDecoration.none)),
            ]),
          ),

          // 倒數圓圈
          if (_countdown > 0 && !_capturing)
            Center(
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black45,
                  border: Border.all(
                    color: _countdown <= 1
                      ? const Color(0xFF4ADE80) : Colors.white70,
                    width: 2),
                ),
                child: Center(
                  child: Text('$_countdown',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold,
                      color: _countdown <= 1
                        ? const Color(0xFF4ADE80) : Colors.white,
                      decoration: TextDecoration.none,
                    )),
                ),
              ),
            ),

          // 底部按鈕
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              // 關閉
              _circleBtn(Icons.close, Colors.white60, () => Navigator.pop(context)),

              // 快門（立即拍）
              GestureDetector(
                onTap: _capturing ? null : () {
                  _countdownTimer?.cancel();
                  setState(() => _countdown = 0);
                  _capture();
                },
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
              _circleBtn(
                _ctrl?.value.flashMode == FlashMode.torch
                  ? Icons.flash_on : Icons.flash_off,
                _ctrl?.value.flashMode == FlashMode.torch
                  ? Colors.yellow : Colors.white60,
                () async {
                  final mode = _ctrl?.value.flashMode;
                  await _ctrl?.setFlashMode(
                    mode == FlashMode.off ? FlashMode.torch : FlashMode.off);
                  setState(() {});
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _circleBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle, color: Colors.black38),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
