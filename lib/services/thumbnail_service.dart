// lib/services/thumbnail_service.dart
//
// 名片照片 → 自動裁切 → 縮圖 → JPEG 壓縮 → base64 字串
// 產生的字串直接存在 Contact.thumbnail，隨聯絡人一起存進 SharedPreferences。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ThumbnailService {
  /// 縮圖最大寬度（px）
  static const int maxWidth = 480;

  /// 壓縮後 JPEG 位元組上限（base64 後約 1.34 倍 ≈ 60KB）
  static const int maxBytes = 45 * 1024;

  /// 名片標準比例 85.6mm × 54mm
  static const double cardAspect = 85.6 / 54.0;

  /// 分析用的縮圖寬度（找名片邊界時用，越小越快）
  static const int _analysisWidth = 160;

  /// 讀檔並在背景 isolate 產生縮圖。失敗時回傳空字串（不影響掃描流程）。
  static Future<String> fromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await compute(encodeBytes, bytes);
    } catch (_) {
      return '';
    }
  }

  /// 解碼 → 裁切 → 縮圖 → JPEG → base64。
  /// 這個方法會被丟到 isolate 執行，必須是 top-level / static。
  static String encodeBytes(Uint8List raw) {
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) return '';

      final oriented = img.bakeOrientation(decoded);
      final cropped = _autoCrop(oriented);

      var work = cropped.width > maxWidth
          ? img.copyResize(cropped,
              width: maxWidth, interpolation: img.Interpolation.average)
          : cropped;

      for (final quality in const [80, 62, 45]) {
        final jpg = img.encodeJpg(work, quality: quality);
        if (jpg.length <= maxBytes) return base64Encode(jpg);
      }

      // 還是太大（極少數高細節照片）→ 再縮一次尺寸
      final narrower = (work.width * 0.7).round().clamp(120, maxWidth);
      work = img.copyResize(work, width: narrower);
      return base64Encode(img.encodeJpg(work, quality: 45));
    } catch (_) {
      return '';
    }
  }

  // ── 自動裁切 ────────────────────────────────────────────────────────────────
  //
  // 名片放在桌面/手上拍，背景通常平坦、名片本身有大量文字邊緣。
  // 所以用「梯度能量」找出畫面中真正有內容的矩形範圍，再往名片比例補齊。
  // 判斷失敗（裁得太兇）時退回原圖，寧可不裁也不要切掉半張名片。
  static img.Image _autoCrop(img.Image src) {
    if (src.width < 120 || src.height < 120) return src;

    final small = img.grayscale(img.copyResize(src, width: _analysisWidth));
    final w = small.width;
    final h = small.height;
    if (w < 8 || h < 8) return src;

    final colEnergy = List<double>.filled(w, 0);
    final rowEnergy = List<double>.filled(h, 0);

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final c = small.getPixel(x, y).r.toDouble();
        final gx = (small.getPixel(x + 1, y).r.toDouble() - c).abs();
        final gy = (small.getPixel(x, y + 1).r.toDouble() - c).abs();
        final g = gx + gy;
        if (g < 12) continue; // 忽略感光雜訊
        colEnergy[x] += g;
        rowEnergy[y] += g;
      }
    }

    const trimRatio = 0.02; // 四邊各切掉能量最低的 2%
    final left = _edge(colEnergy, false, trimRatio);
    final right = _edge(colEnergy, true, trimRatio);
    final top = _edge(rowEnergy, false, trimRatio);
    final bottom = _edge(rowEnergy, true, trimRatio);

    if (right <= left || bottom <= top) return src;

    final sx = src.width / w;
    final sy = src.height / h;

    var x0 = (left * sx).floor();
    var y0 = (top * sy).floor();
    var x1 = ((right + 1) * sx).ceil();
    var y1 = ((bottom + 1) * sy).ceil();

    // 留一點邊界，避免貼齊名片邊緣
    final padX = ((x1 - x0) * 0.05).round();
    final padY = ((y1 - y0) * 0.05).round();
    x0 = (x0 - padX).clamp(0, src.width - 1);
    y0 = (y0 - padY).clamp(0, src.height - 1);
    x1 = (x1 + padX).clamp(x0 + 1, src.width);
    y1 = (y1 + padY).clamp(y0 + 1, src.height);

    var cw = x1 - x0;
    var ch = y1 - y0;

    // 裁得太小 → 判定偵測失敗（背景太亂或名片太遠），用原圖比較安全
    if (cw * ch < src.width * src.height * 0.08 ||
        cw < src.width * 0.25 ||
        ch < src.height * 0.15) {
      return src;
    }

    // 往名片比例補齊（只往外擴，不再切掉已偵測到的內容）。
    // 比例差太多代表名片是直立擺放或偵測不準，那就維持原偵測範圍。
    final aspect = cw / ch;
    if (aspect < 1.15 || aspect > 2.2) {
      return img.copyCrop(src, x: x0, y: y0, width: cw, height: ch);
    }
    if (aspect < cardAspect) {
      final want = (ch * cardAspect).round();
      x0 = (x0 - (want - cw) ~/ 2).clamp(0, src.width - 1);
      cw = want.clamp(1, src.width - x0);
    } else if (aspect > cardAspect) {
      final want = (cw / cardAspect).round();
      y0 = (y0 - (want - ch) ~/ 2).clamp(0, src.height - 1);
      ch = want.clamp(1, src.height - y0);
    }

    if (cw < 1 || ch < 1) return src;
    return img.copyCrop(src, x: x0, y: y0, width: cw, height: ch);
  }

  /// 從一側往內累積能量，達到 [ratio] 比例的位置就是內容邊界。
  static int _edge(List<double> energy, bool fromEnd, double ratio) {
    var total = 0.0;
    for (final e in energy) {
      total += e;
    }
    if (total <= 0) return fromEnd ? energy.length - 1 : 0;

    final limit = total * ratio;
    var acc = 0.0;
    if (!fromEnd) {
      for (var i = 0; i < energy.length; i++) {
        acc += energy[i];
        if (acc >= limit) return i;
      }
      return 0;
    }
    for (var i = energy.length - 1; i >= 0; i--) {
      acc += energy[i];
      if (acc >= limit) return i;
    }
    return energy.length - 1;
  }
}

/// base64 → Uint8List 的小快取。
/// 列表滾動時每次 build 都重新 decode 40KB 字串會很卡，
/// 而且每次產生的新 Uint8List 會讓 Flutter 的 image cache 失效。
class ThumbCache {
  static final Map<String, Uint8List> _cache = {};
  static const int _limit = 80;

  static Uint8List? bytes(String key, String base64Data) {
    if (base64Data.isEmpty) return null;
    final k = '$key#${base64Data.length}';
    final hit = _cache[k];
    if (hit != null) return hit;
    try {
      final decoded = base64Decode(base64Data);
      if (_cache.length >= _limit) _cache.clear();
      _cache[k] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static void clear() => _cache.clear();
}
