import 'dart:async';
import 'package:flutter/material.dart';
import '../autofill_bridge.dart';
import '../models.dart' show InstalledApp;
import 'task_model.dart';

const _noDeco = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
);

// ═══════════ Step Type Picker ═══════════
Future<TaskStepType?> showStepTypePicker(
  BuildContext context, {
  required bool isDark,
}) {
  return showModalBottomSheet<TaskStepType>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _StepTypeSheet(isDark: isDark),
  );
}

class _StepTypeSheet extends StatelessWidget {
  final bool isDark;
  const _StepTypeSheet({required this.isDark});

  IconData _iconFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp:
        return Icons.apps_rounded;
      case TaskStepType.wait:
        return Icons.hourglass_top_rounded;
      case TaskStepType.typeText:
        return Icons.keyboard_rounded;
      case TaskStepType.numberFromFile:
        return Icons.numbers_rounded;
      case TaskStepType.clickByText:
        return Icons.text_fields_rounded;
      case TaskStepType.clickByDesc:
        return Icons.description_rounded;
      case TaskStepType.clickById:
        return Icons.tag_rounded;
      case TaskStepType.clickAt:
        return Icons.my_location_rounded;
      case TaskStepType.waitForElement:
        return Icons.hourglass_bottom_rounded;
      case TaskStepType.clearAppData:
        return Icons.delete_sweep_rounded;
      case TaskStepType.swipe:
        return Icons.swipe_rounded;
      case TaskStepType.swipeToFind:
        return Icons.search_rounded;
      case TaskStepType.back:
        return Icons.arrow_back_rounded;
      case TaskStepType.home:
        return Icons.home_rounded;
      case TaskStepType.recents:
        return Icons.view_carousel_rounded;
    }
  }

  Color _colorFor(TaskStepType t) {
    switch (t) {
      case TaskStepType.openApp:
        return const Color(0xFF6C5CE7);
      case TaskStepType.wait:
        return const Color(0xFF95A5A6);
      case TaskStepType.typeText:
        return const Color(0xFF00D2FF);
      case TaskStepType.numberFromFile:
        return const Color(0xFF8E44AD);
      case TaskStepType.clickByText:
      case TaskStepType.clickByDesc:
      case TaskStepType.clickById:
        return const Color(0xFF00B894);
      case TaskStepType.clickAt:
        return const Color(0xFFFFB84D);
      case TaskStepType.waitForElement:
        return const Color(0xFFE17055);
      case TaskStepType.clearAppData:
        return const Color(0xFFFF6B6B);
      case TaskStepType.swipe:
        return const Color(0xFFFF8E53);
      case TaskStepType.swipeToFind:
        return const Color(0xFF9B59B6);
      case TaskStepType.back:
      case TaskStepType.home:
      case TaskStepType.recents:
        return const Color(0xFF34495E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اختر نوع الخطوة',
              textAlign: TextAlign.center,
              style: _noDeco.copyWith(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: TaskStepType.values.map((t) {
                final label =
                    TaskStep(id: '', type: t, params: {}, waitAfterMs: 0)
                        .typeLabel;
                final color = _colorFor(t);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, t),
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_iconFor(t), size: 22, color: color),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: _noDeco.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════ Element Picker ═══════════
Future<ScreenElement?> showElementPicker(
  BuildContext context, {
  required List<ScreenElement> elements,
  required bool isDark,
}) {
  return showModalBottomSheet<ScreenElement>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) =>
        _ElementPickerSheet(elements: elements, isDark: isDark),
  );
}

enum _ElementFilter { all, clickable, editable }

class _ElementPickerSheet extends StatefulWidget {
  final List<ScreenElement> elements;
  final bool isDark;
  const _ElementPickerSheet({
    required this.elements,
    required this.isDark,
  });

  @override
  State<_ElementPickerSheet> createState() => _ElementPickerSheetState();
}

class _ElementPickerSheetState extends State<_ElementPickerSheet> {
  late List<ScreenElement> _filtered;
  late TextEditingController _search;
  _ElementFilter _filter = _ElementFilter.all;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _filtered = widget.elements;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final s = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.elements.where((e) {
        if (_filter == _ElementFilter.clickable) {
          if (!e.isInteractive) return false;
        } else if (_filter == _ElementFilter.editable) {
          if (!e.editable) return false;
        }
        if (s.isEmpty) return true;
        return e.text.toLowerCase().contains(s) ||
            e.desc.toLowerCase().contains(s) ||
            e.id.toLowerCase().contains(s) ||
            e.hint.toLowerCase().contains(s);
      }).toList();
    });
  }

  IconData _iconFor(ScreenElement e) {
    if (e.editable) return Icons.keyboard_rounded;
    if (e.clickable || e.clickableParent) return Icons.touch_app_rounded;
    if (e.hasText) return Icons.text_fields_rounded;
    return Icons.widgets_rounded;
  }

  Color _colorFor(ScreenElement e) {
    if (e.editable) return const Color(0xFF00D2FF);
    if (e.clickable) return const Color(0xFF00D68F);
    if (e.clickableParent) return const Color(0xFFFFB84D);
    if (e.hasText) return const Color(0xFF6C5CE7);
    return const Color(0xFF95A5A6);
  }

  String _typeLabelFor(ScreenElement e) {
    if (e.editable) return 'حقل كتابة';
    if (e.clickable) return 'قابل للضغط';
    if (e.clickableParent) return 'أب قابل للضغط';
    if (e.hasText) return 'نص';
    if (e.hasDesc) return 'وصف';
    if (e.hasId) return 'id';
    return 'عنصر';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'عناصر الشاشة',
            style: _noDeco.copyWith(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${_filtered.length} من ${widget.elements.length}',
            style: _noDeco.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              style: _noDeco.copyWith(fontSize: 15),
              onChanged: (_) => _applyFilter(),
              decoration: InputDecoration(
                hintText: 'ابحث…',
                prefixIcon: const Icon(Icons.search_rounded),
                hintStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _chip(
                  theme,
                  label: 'الكل',
                  icon: Icons.apps_rounded,
                  selected: _filter == _ElementFilter.all,
                  color: theme.colorScheme.primary,
                  onTap: () {
                    setState(() => _filter = _ElementFilter.all);
                    _applyFilter();
                  },
                ),
                const SizedBox(width: 6),
                _chip(
                  theme,
                  label: 'قابلة للضغط',
                  icon: Icons.touch_app_rounded,
                  selected: _filter == _ElementFilter.clickable,
                  color: const Color(0xFF00D68F),
                  onTap: () {
                    setState(() => _filter = _ElementFilter.clickable);
                    _applyFilter();
                  },
                ),
                const SizedBox(width: 6),
                _chip(
                  theme,
                  label: 'قابلة للكتابة',
                  icon: Icons.keyboard_rounded,
                  selected: _filter == _ElementFilter.editable,
                  color: const Color(0xFF00D2FF),
                  onTap: () {
                    setState(() => _filter = _ElementFilter.editable);
                    _applyFilter();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'مفيش نتائج',
                      style: _noDeco.copyWith(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) =>
                        _buildTile(theme, _filtered[i]),
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _chip(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.2)
                  : theme.colorScheme.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? color
                    : theme.colorScheme.primary.withOpacity(0.15),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 14,
                    color: selected
                        ? color
                        : theme.colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: _noDeco.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? color
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(ThemeData theme, ScreenElement e) {
    final color = _colorFor(e);
    int sameIdx = 0;
    for (final x in widget.elements) {
      if (identical(x, e)) break;
      if (x.sameSpecs(e)) sameIdx++;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, e),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFor(e), color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _typeLabelFor(e),
                              style: _noDeco.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            e.shortClassName,
                            style: _noDeco.copyWith(
                              fontSize: 9.5,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.4),
                            ),
                          ),
                          if (sameIdx > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB84D)
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$sameIdx',
                                style: _noDeco.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFB84D),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (e.hasText)
                        Text(
                          e.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      if (e.hasDesc)
                        Text(
                          '📝 ${e.desc}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.75),
                          ),
                        ),
                      if (e.hasHint && !e.hasText)
                        Text(
                          '💡 ${e.hint}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      if (e.hasId)
                        Text(
                          '🏷 ${e.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _noDeco.copyWith(
                            fontSize: 10.5,
                            color: theme.colorScheme.primary
                                .withOpacity(0.8),
                          ),
                        ),
                      Text(
                        '(${e.x}, ${e.y}) • ${e.width}×${e.height}',
                        style: _noDeco.copyWith(
                          fontSize: 9.5,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════ App Picker ═══════════
Future<InstalledApp?> showAppPicker(
  BuildContext context, {
  required bool isDark,
}) {
  return showModalBottomSheet<InstalledApp>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _AppPickerSheet(isDark: isDark),
  );
}

class _AppPickerSheet extends StatefulWidget {
  final bool isDark;
  const _AppPickerSheet({required this.isDark});

  @override
  State<_AppPickerSheet> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  List<InstalledApp> _all = [];
  List<InstalledApp> _filtered = [];
  bool _loading = true;
  late TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await AutoFillBridge.listInstalledApps();
    if (!mounted) return;
    setState(() {
      _all = list;
      _filtered = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'اختر تطبيق',
            style: _noDeco.copyWith(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '${_all.length} تطبيق مثبّت',
            style: _noDeco.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              style: _noDeco.copyWith(fontSize: 15),
              onChanged: (q) {
                final s = q.trim().toLowerCase();
                setState(() {
                  _filtered = s.isEmpty
                      ? _all
                      : _all
                          .where((a) =>
                              a.name.toLowerCase().contains(s) ||
                              a.package.toLowerCase().contains(s))
                          .toList();
                });
              },
              decoration: InputDecoration(
                hintText: 'ابحث باسم التطبيق…',
                hintStyle: _noDeco.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4)),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'مفيش نتائج',
                          style: _noDeco.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5)),
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) =>
                            _buildAppTile(theme, _filtered[i]),
                      ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAppTile(ThemeData theme, InstalledApp app) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, app),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.android_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: _noDeco.copyWith(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.package,
                        style: _noDeco.copyWith(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════ Countdown + Capture ═══════════
Future<List<ScreenElement>?> showCountdownAndCapture(
    BuildContext context) {
  return showDialog<List<ScreenElement>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CountdownDialog(),
  );
}

class _CountdownDialog extends StatefulWidget {
  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _seconds = 5;
  Timer? _timer;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_seconds > 1) {
        setState(() => _seconds--);
      } else {
        t.cancel();
        setState(() {
          _seconds = 0;
          _capturing = true;
        });
        final elements = await AutoFillBridge.dumpScreen();
        if (mounted) Navigator.pop(context, elements);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.screen_share_rounded,
            size: 50,
            color: Color(0xFF6C5CE7),
          ),
          const SizedBox(height: 14),
          Text(
            _capturing
                ? 'جاري الالتقاط…'
                : 'هيتم الالتقاط بعد $_seconds',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _capturing ? 'من فضلك استنى' : 'اسرع! روح للتطبيق',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              decoration: TextDecoration.none,
            ),
          ),
          if (!_capturing) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: _seconds / 5,
                      strokeWidth: 4,
                      backgroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),
                  Text(
                    '$_seconds',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
