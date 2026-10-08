import 'package:flutter/material.dart';
import 'widgets.dart';
import 'models.dart';

class NumbersPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  // قسم التحميل من الموقع
  final List<String> ranges;
  final String? selectedRange;
  final int selectedCount;
  final String selectedType;
  final bool loadingRanges;
  final bool busy;
  final Future<void> Function() onRefreshRanges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<int> onSelectCount;
  final ValueChanged<String> onSelectType;
  final Future<void> Function() onApplyFilter;
  final Future<void> Function() onDownloadCsv;

  // قسم تشغيل الأرقام
  final List<CsvFile> csvFiles;
  final String? selectedCsvName;
  final List<String> currentNumbers;
  final int currentIndex;
  final bool infinite;
  final int repeatCount;
  final bool autoTypeEnabled;
  final bool volumeEnabled;
  final bool floatingEnabled;
  final bool accessibilityOn;
  final bool overlayOn;
  final Future<void> Function() onRefreshFiles;
  final ValueChanged<String> onSelectCsv;
  final VoidCallback onPrevNumber;
  final VoidCallback onNextNumber;
  final Future<void> Function() onCopyCurrent;
  final Future<void> Function() onTypeCurrent;
  final ValueChanged<bool> onToggleInfinite;
  final ValueChanged<int> onSetRepeat;
  final Future<void> Function(bool) onToggleAutoType;
  final Future<void> Function(bool) onToggleVolume;
  final Future<void> Function(bool) onToggleFloating;
  final Future<void> Function() onOpenAccessibility;
  final Future<void> Function() onOpenOverlay;

  // سجل
  final List<LogEntry> logs;
  final VoidCallback onBack;

  const NumbersPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.ranges,
    required this.selectedRange,
    required this.selectedCount,
    required this.selectedType,
    required this.loadingRanges,
    required this.busy,
    required this.onRefreshRanges,
    required this.onSelectRange,
    required this.onSelectCount,
    required this.onSelectType,
    required this.onApplyFilter,
    required this.onDownloadCsv,
    required this.csvFiles,
    required this.selectedCsvName,
    required this.currentNumbers,
    required this.currentIndex,
    required this.infinite,
    required this.repeatCount,
    required this.autoTypeEnabled,
    required this.volumeEnabled,
    required this.floatingEnabled,
    required this.accessibilityOn,
    required this.overlayOn,
    required this.onRefreshFiles,
    required this.onSelectCsv,
    required this.onPrevNumber,
    required this.onNextNumber,
    required this.onCopyCurrent,
    required this.onTypeCurrent,
    required this.onToggleInfinite,
    required this.onSetRepeat,
    required this.onToggleAutoType,
    required this.onToggleVolume,
    required this.onToggleFloating,
    required this.onOpenAccessibility,
    required this.onOpenOverlay,
    required this.logs,
    required this.onBack,
  });

  static const _counts = [10, 25, 50, 100, 500, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الأرقام',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text('حمّل الأرقام وشغّلها',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _downloadCard(theme),
                      const SizedBox(height: 14),
                      _autofillCard(theme),
                      const SizedBox(height: 14),
                      LogPanel(logs: logs, isDark: isDark, shrink: true),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════ قسم التحميل ═══════════
  Widget _downloadCard(ThemeData theme) {
    return _card(theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_download_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('تحميل من الموقع',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconBtn(
                icon: Icons.refresh_rounded,
                spinning: loadingRanges,
                onTap: loadingRanges ? null : () => onRefreshRanges(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _label(theme, Icons.sim_card_rounded, 'الرنج'),
          const SizedBox(height: 8),
          _RangePicker(
            theme: theme,
            ranges: ranges,
            selected: selectedRange,
            loading: loadingRanges,
            onSelect: onSelectRange,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.numbers_rounded, 'العدد'),
                    const SizedBox(height: 8),
                    _MiniSelect<int>(
                      theme: theme,
                      value: selectedCount,
                      items: _counts,
                      labelBuilder: (v) => v >= 1000
                          ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}K'
                          : '$v',
                      onChanged: onSelectCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.tag_rounded, 'النوع'),
                    const SizedBox(height: 8),
                    _MiniSelect<String>(
                      theme: theme,
                      value: selectedType,
                      items: const ['full', 'local'],
                      labelBuilder: (v) => v == 'full' ? 'Full Num' : 'Local Num',
                      onChanged: onSelectType,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ActionBtn(
                  label: 'تطبيق الفلتر',
                  icon: Icons.filter_alt_rounded,
                  gradient: const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                  busy: busy,
                  onTap: busy ? null : () => onApplyFilter(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionBtn(
                  label: 'تحميل CSV',
                  icon: Icons.download_rounded,
                  gradient: const [Color(0xFF00B894), Color(0xFF00D68F)],
                  busy: busy,
                  onTap: busy ? null : () => onDownloadCsv(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════ قسم التشغيل ═══════════
  Widget _autofillCard(ThemeData theme) {
    final current = (currentIndex >= 0 && currentIndex < currentNumbers.length)
        ? currentNumbers[currentIndex]
        : '—';
    final total = currentNumbers.length;
    return _card(theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 20, color: const Color(0xFFFF6B6B)),
              const SizedBox(width: 8),
              Text('تشغيل الأرقام',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconBtn(
                icon: Icons.refresh_rounded,
                onTap: () => onRefreshFiles(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // اختيار ملف
          _label(theme, Icons.folder_rounded, 'ملف الأرقام'),
          const SizedBox(height: 8),
          _CsvPicker(
            theme: theme,
            files: csvFiles,
            selected: selectedCsvName,
            onSelect: onSelectCsv,
          ),
          const SizedBox(height: 14),

          // العداد
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFF6C5CE7).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              children: [
                Text('الرقم الحالي',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                const SizedBox(height: 6),
                Text(current,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold,
                      fontFamily: 'monospace', letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('$currentIndex + 1 / $total',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // أزرار التنقل
          Row(
            children: [
              Expanded(
                child: _smallBtn(
                  theme,
                  icon: Icons.skip_previous_rounded,
                  label: 'السابق',
                  color: const Color(0xFFFFB84D),
                  onTap: currentNumbers.isEmpty ? null : onPrevNumber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallBtn(
                  theme,
                  icon: Icons.content_copy_rounded,
                  label: 'نسخ',
                  color: const Color(0xFF00D2FF),
                  onTap: currentNumbers.isEmpty ? null : () => onCopyCurrent(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallBtn(
                  theme,
                  icon: Icons.skip_next_rounded,
                  label: 'التالي',
                  color: const Color(0xFF00D68F),
                  onTap: currentNumbers.isEmpty ? null : onNextNumber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _smallBtn(
              theme,
              icon: Icons.keyboard_rounded,
              label: 'اكتب الرقم في الحقل المفتوح',
              color: const Color(0xFF6C5CE7),
              onTap: currentNumbers.isEmpty ? null : () => onTypeCurrent(),
            ),
          ),

          const SizedBox(height: 18),
          Divider(color: theme.colorScheme.primary.withOpacity(0.15)),
          const SizedBox(height: 10),

          // التكرار
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.repeat_rounded, 'عدد مرات التكرار'),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      enabled: !infinite,
                      controller: TextEditingController(text: repeatCount.toString()),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) onSetRepeat(n);
                      },
                      decoration: InputDecoration(
                        hintText: 'مثال: 3',
                        suffixIcon: Icon(Icons.repeat_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => onToggleInfinite(!infinite),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: infinite
                            ? const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])
                            : null,
                        color: infinite ? null : theme.colorScheme.surface.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: infinite
                              ? Colors.transparent
                              : theme.colorScheme.primary.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.all_inclusive_rounded,
                              size: 20,
                              color: infinite ? Colors.white : theme.colorScheme.onSurface),
                          const SizedBox(width: 6),
                          Text('∞',
                              style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold,
                                color: infinite ? Colors.white : theme.colorScheme.onSurface,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),
          Divider(color: theme.colorScheme.primary.withOpacity(0.15)),
          const SizedBox(height: 10),

          // إعدادات الأتمتة
          _label(theme, Icons.settings_remote_rounded, 'أزرار التشغيل'),
          const SizedBox(height: 10),

          _toggleRow(
            theme,
            icon: Icons.keyboard_alt_rounded,
            title: 'الكتابة التلقائية',
            subtitle: 'لما تدوس على أي زرار، الرقم يتكتب في الحقل فوراً',
            value: autoTypeEnabled,
            onChanged: onToggleAutoType,
          ),
          const SizedBox(height: 8),
          _toggleRow(
            theme,
            icon: Icons.volume_up_rounded,
            title: 'أزرار الصوت',
            subtitle: 'Volume Up = التالي • Volume Down = السابق',
            value: volumeEnabled,
            onChanged: onToggleVolume,
          ),
          const SizedBox(height: 8),
          _toggleRow(
            theme,
            icon: Icons.picture_in_picture_alt_rounded,
            title: 'أيقونة عائمة',
            subtitle: 'أيقونة فوق كل التطبيقات',
            value: floatingEnabled,
            onChanged: onToggleFloating,
          ),

          const SizedBox(height: 14),
          // التنبيهات
          if (!accessibilityOn)
            _warnBox(
              theme,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFFFB84D),
              text: 'Accessibility Service مش مفعّل',
              actionLabel: 'تفعيل',
              onAction: () => onOpenAccessibility(),
            ),
          if (floatingEnabled && !overlayOn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _warnBox(
                theme,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFFF6B6B),
                text: 'صلاحية الأيقونة العائمة مش مفعّلة',
                actionLabel: 'تفعيل',
                onAction: () => onOpenOverlay(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toggleRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) => onChanged(v),
            activeColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _warnBox(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String text,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12))),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: onTap == null
                ? theme.colorScheme.surface.withOpacity(0.3)
                : color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(onTap == null ? 0.1 : 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18,
                  color: onTap == null ? theme.colorScheme.onSurface.withOpacity(0.3) : color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: onTap == null ? theme.colorScheme.onSurface.withOpacity(0.3) : color,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(isDark ? 0.55 : 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: child,
    );
  }

  Widget _label(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ═══════════ Range Picker (زي ما هو) ═══════════
class _RangePicker extends StatelessWidget {
  final ThemeData theme;
  final List<String> ranges;
  final String? selected;
  final bool loading;
  final ValueChanged<String> onSelect;

  const _RangePicker({
    required this.theme,
    required this.ranges,
    required this.selected,
    required this.loading,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading || ranges.isEmpty ? null : () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: loading
                    ? Row(children: [
                        SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                        const SizedBox(width: 10),
                        Text('جاري التحميل…',
                            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 14)),
                      ])
                    : Text(
                        selected ?? (ranges.isEmpty ? 'مفيش رنجات' : 'اختر رنج'),
                        style: TextStyle(
                          color: selected != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: selected != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _RangeSheet(ranges: ranges, selected: selected, onSelect: (r) { Navigator.pop(ctx); onSelect(r); }),
    );
  }
}

class _RangeSheet extends StatefulWidget {
  final List<String> ranges;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _RangeSheet({required this.ranges, required this.selected, required this.onSelect});
  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late TextEditingController _search;
  List<String> filtered = [];
  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    filtered = widget.ranges;
  }
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 50, height: 5,
              decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('اختر الرنج', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (q) => setState(() {
                filtered = q.trim().isEmpty
                    ? widget.ranges
                    : widget.ranges.where((r) => r.toLowerCase().contains(q.trim().toLowerCase())).toList();
              }),
              decoration: InputDecoration(
                hintText: 'ابحث…',
                prefixIcon: const Icon(Icons.search_rounded),
                fillColor: theme.colorScheme.surface.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('مفيش نتائج',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final r = filtered[i];
                      final isSel = r == widget.selected;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Material(
                          color: isSel ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onSelect(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSel ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(r,
                                      style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 14))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ═══════════ CSV Picker ═══════════
class _CsvPicker extends StatelessWidget {
  final ThemeData theme;
  final List<CsvFile> files;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _CsvPicker({
    required this.theme,
    required this.files,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: files.isEmpty ? null : () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.description_rounded, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected ?? (files.isEmpty ? 'مفيش ملفات — حمّل الأول' : 'اختر ملف'),
                  style: TextStyle(
                    color: selected != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight: selected != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 50, height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                )),
            const SizedBox(height: 16),
            Text('اختر ملف CSV', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: files.length,
                itemBuilder: (_, i) {
                  final f = files[i];
                  final isSel = f.name == selected;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Material(
                      color: isSel ? Theme.of(ctx).colorScheme.primary.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () { Navigator.pop(ctx); onSelect(f.name); },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSel ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.onSurface.withOpacity(0.4),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.name, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('${f.count} رقم',
                                        style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.5))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniSelect<T> extends StatelessWidget {
  final ThemeData theme;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  const _MiniSelect({
    required this.theme,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(labelBuilder(e)))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}