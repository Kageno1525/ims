import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models.dart';

class ScreenElement {
  final String text;
  final String desc;
  final String id;
  final String className;
  final String hint;
  final bool clickable;
  final bool longClickable;
  final bool focusable;
  final bool editable;
  final bool enabled;
  final bool clickableParent;
  final String pkg;
  final int x, y, left, top, right, bottom, width, height;

  ScreenElement({
    required this.text, required this.desc, required this.id,
    required this.className, required this.hint,
    required this.clickable, required this.longClickable,
    required this.focusable, required this.editable, required this.enabled,
    required this.clickableParent, required this.pkg,
    required this.x, required this.y,
    required this.left, required this.top, required this.right,
    required this.bottom, required this.width, required this.height,
  });

  factory ScreenElement.fromMap(Map<String, dynamic> m) => ScreenElement(
        text: m['text']?.toString() ?? '',
        desc: m['desc']?.toString() ?? '',
        id: m['id']?.toString() ?? '',
        className: m['className']?.toString() ?? '',
        hint: m['hint']?.toString() ?? '',
        clickable: m['clickable'] == true,
        longClickable: m['longClickable'] == true,
        focusable: m['focusable'] == true,
        editable: m['editable'] == true,
        enabled: m['enabled'] != false,
        clickableParent: m['clickableParent'] == true,
        pkg: m['pkg']?.toString() ?? '',
        x: (m['x'] as num?)?.toInt() ?? 0,
        y: (m['y'] as num?)?.toInt() ?? 0,
        left: (m['left'] as num?)?.toInt() ?? 0,
        top: (m['top'] as num?)?.toInt() ?? 0,
        right: (m['right'] as num?)?.toInt() ?? 0,
        bottom: (m['bottom'] as num?)?.toInt() ?? 0,
        width: (m['width'] as num?)?.toInt() ?? 0,
        height: (m['height'] as num?)?.toInt() ?? 0,
      );

  bool get hasText => text.isNotEmpty;
  bool get hasDesc => desc.isNotEmpty;
  bool get hasId => id.isNotEmpty;
  bool get hasHint => hint.isNotEmpty;
  bool get isInteractive => clickable || clickableParent;

  String get bestLabel {
    if (text.isNotEmpty) return text;
    if (desc.isNotEmpty) return desc;
    if (hint.isNotEmpty) return hint;
    if (id.isNotEmpty) return id.split('/').last;
    return className.split('.').last;
  }

  String get shortClassName => className.split('.').last;

  bool sameSpecs(ScreenElement o) =>
      text == o.text &&
      desc == o.desc &&
      id == o.id &&
      className == o.className;
}

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
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  static Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod('hasOverlayPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  static Future<bool> typeText(String text) async {
    try {
      return await _channel.invokeMethod('typeText', {'text': text}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> smartClick({
    String text = '',
    String desc = '',
    String viewId = '',
    String className = '',
    int index = 0,
    bool preferClickable = true,
  }) async {
    try {
      return await _channel.invokeMethod('smartClick', {
            'text': text,
            'desc': desc,
            'viewId': viewId,
            'className': className,
            'index': index,
            'preferClickable': preferClickable,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> smartType({
    required String value,
    String viewId = '',
    String hint = '',
    String className = '',
    int index = 0,
  }) async {
    try {
      return await _channel.invokeMethod('smartType', {
            'value': value,
            'viewId': viewId,
            'hint': hint,
            'className': className,
            'index': index,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> findElement({
    String text = '',
    String desc = '',
    String viewId = '',
    String className = '',
    int index = 0,
  }) async {
    try {
      return await _channel.invokeMethod('findElement', {
            'text': text,
            'desc': desc,
            'viewId': viewId,
            'className': className,
            'index': index,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// جديد: مسح بيانات تطبيق
  static Future<bool> clearAppData(String package) async {
    try {
      return await _channel
              .invokeMethod('clearAppData', {'package': package}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clickByText(String text) => smartClick(text: text);
  static Future<bool> clickByDesc(String desc) => smartClick(desc: desc);
  static Future<bool> clickById(String viewId) => smartClick(viewId: viewId);

  static Future<void> startVolumeListener() async {
    try {
      await _channel.invokeMethod('startVolume');
    } catch (_) {}
  }

  static Future<void> stopVolumeListener() async {
    try {
      await _channel.invokeMethod('stopVolume');
    } catch (_) {}
  }

  static Future<bool> showFloating() async {
    try {
      return await _channel.invokeMethod('showFloating') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> hideFloating() async {
    try {
      await _channel.invokeMethod('hideFloating');
    } catch (_) {}
  }

  static Future<void> updateFloatingText(String text) async {
    try {
      await _channel.invokeMethod('updateFloatingText', {'text': text});
    } catch (_) {}
  }

  static Future<bool> openApp(String package) async {
    try {
      return await _channel
              .invokeMethod('openApp', {'package': package}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clickAt(int x, int y) async {
    try {
      return await _channel.invokeMethod('clickAt', {'x': x, 'y': y}) ??
          false;
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

  static Future<String?> resolvePackage(String nameOrPackage) async {
    try {
      return await _channel.invokeMethod(
          'resolvePackage', {'name': nameOrPackage});
    } catch (_) {
      return null;
    }
  }

  static Future<List<ScreenElement>> dumpScreen() async {
    try {
      final raw = await _channel.invokeMethod('dumpScreen');
      if (raw == null) return [];
      final str = raw.toString();
      if (str.isEmpty || str == '[]') return [];
      final list = jsonDecode(str) as List;
      return list
          .map((e) => ScreenElement.fromMap(Map<String, dynamic>.from(e)))
          .toList();
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