import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models.dart';

class AutoFillBridge {
  static const _channel = MethodChannel('ims/autofill');

  static Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try { await _channel.invokeMethod('openAccessibilitySettings'); } catch (_) {}
  }

  static Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod('hasOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openOverlaySettings() async {
    try { await _channel.invokeMethod('openOverlaySettings'); } catch (_) {}
  }

  static Future<bool> typeText(String text) async {
    try {
      return await _channel.invokeMethod('typeText', {'text': text}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startVolumeListener() async {
    try { await _channel.invokeMethod('startVolume'); } catch (_) {}
  }

  static Future<void> stopVolumeListener() async {
    try { await _channel.invokeMethod('stopVolume'); } catch (_) {}
  }

  static Future<bool> showFloating() async {
    try {
      return await _channel.invokeMethod('showFloating') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> hideFloating() async {
    try { await _channel.invokeMethod('hideFloating'); } catch (_) {}
  }

  static Future<void> updateFloatingText(String text) async {
    try {
      await _channel.invokeMethod('updateFloatingText', {'text': text});
    } catch (_) {}
  }

  static Future<bool> openApp(String package) async {
    try {
      return await _channel.invokeMethod('openApp', {'package': package}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clickByText(String text) async {
    try {
      return await _channel.invokeMethod('clickByText', {'text': text}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clickByDesc(String desc) async {
    try {
      return await _channel.invokeMethod('clickByDesc', {'desc': desc}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clickById(String viewId) async {
    try {
      return await _channel.invokeMethod('clickById', {'viewId': viewId}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clickAt(int x, int y) async {
    try {
      return await _channel.invokeMethod('clickAt', {'x': x, 'y': y}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> swipe(
      int x1, int y1, int x2, int y2, int durationMs) async {
    try {
      return await _channel.invokeMethod('swipe', {
            'x1': x1,
            'y1': y1,
            'x2': x2,
            'y2': y2,
            'duration': durationMs,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> globalBack() async {
    try {
      return await _channel.invokeMethod('globalBack') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> globalHome() async {
    try {
      return await _channel.invokeMethod('globalHome') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> globalRecents() async {
    try {
      return await _channel.invokeMethod('globalRecents') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> currentPackage() async {
    try {
      return await _channel.invokeMethod('currentPackage') ?? '';
    } catch (_) {
      return '';
    }
  }

  // ⭐ جديد: قائمة التطبيقات المثبتة
  static Future<List<InstalledApp>> listInstalledApps() async {
    try {
      final result = await _channel.invokeMethod('listApps');
      if (result == null) return [];
      return (result as List).map((e) {
        final m = Map<String, dynamic>.from(e);
        return InstalledApp(
          package: m['package']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static void setListener({
    required void Function(String action) onVolume,
    required VoidCallback onFloatingClick,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onVolume') {
        onVolume(call.arguments?.toString() ?? '');
      } else if (call.method == 'onFloatingClick') {
        onFloatingClick();
      }
    });
  }
}