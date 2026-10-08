import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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