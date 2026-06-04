// lib/screens/camera_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  final bool continuous;
  final void Function(File image) onCapture;
  final int maxShots; // 動態上限，由外部傳入

  const CameraScreen({
    super.key,
    required this.onCapture,
    this.continuous = false,
    this.maxShots = 10,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _ctrl;
  bool _initialized = false;
  bool _capturing = false;
  bool _showSuccess = false;
  int _shotCount = 0;
  Timer? _successTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _successTimer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _ctrl?.dispose();
      _ctrl = null;
      if (mounted) setState(() => _initialized = false);
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

    setState(() { _ctrl = ctrl; _initialized = true; });
  }

  Future<void> _onTapFocus(TapDownDetails details) async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    final size = MediaQuery.of(context).size;
    final x = details.localPosition.dx / size.width;
    final y = details.localPosition.dy / size.height;
    try {
      await _ctrl!.setFocusPoint(Offset(x, y));
      await _ctrl!.setExposurePoint(Offset(x, y));
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_capturing || _ctrl == null || !_ctrl!.value.isInitialized) return;

    // 達到上限時提示並關閉
    if (_shotCount >= widget.maxShots) {
      _showLimitDialog();
      return;
    }

    setState(() => _capturing = true);

    try {
      final image = await _ctrl!.takePicture();
      final dir = await getTemporaryDirectory();
      final dest = '${dir.path}/cardify_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(image.path).copy(dest);
      widget.onCapture(File(dest));
      _shotCount++;

      // 顯示成功提示
      setState(() { _capturing = false; _showSuccess = true; });
      _successTimer?.cancel();
      _successTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showSuccess = false);
      });

      // 達到上限自動提示
      if (_shotCount >= widget.maxShots) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _showLimitDialog();
        return;
      }

      // 單張模式：拍完直接離開
      if (!widget.continuous && mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _showLimitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('已達上限'),
        content: Text('單次最多掃描 ${widget.maxShots} 張，請先等待目前的辨識完成後再繼續。'),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a1a1a), foregroundColor: Colors.white),
            child: const Text('回到佇列'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.maxShots - _shotCount;

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

          // 拍照成功 overlay
          if (_showSuccess)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showSuccess ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F6E56),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_circle_outline, color: Colors.white, size: 48),
                        const SizedBox(height: 8),
                        const Text('拍攝成功',
                          style: TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                        const SizedBox(height: 4),
                        Text(
                          widget.continuous
                            ? '還可拍 $remaining 張'
                            : '已加入辨識佇列',
                          style: const TextStyle(color: Colors.white70, fontSize: 13,
                            decoration: TextDecoration.none)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

          // 上方提示列
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // 張數指示器
              if (widget.continuous)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_shotCount / ${widget.maxShots}',
                    style: TextStyle(
                      color: remaining <= 3 ? Colors.orange : Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none),
                  ),
                )
              else
                const SizedBox(),

              // 點擊對焦提示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                child: const Text('點擊畫面對焦',
                  style: TextStyle(color: Colors.white54, fontSize: 11,
                    decoration: TextDecoration.none)),
              ),
            ]),
          ),

          // 底部按鈕
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 0, right: 0,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _circleBtn(Icons.close, Colors.white60, () => Navigator.pop(context)),

              // 快門
              GestureDetector(
                onTap: _capturing ? null : _capture,
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
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
