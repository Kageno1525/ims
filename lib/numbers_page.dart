import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'widgets.dart';
import 'models.dart';

class NumbersPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  // Stats
  final int today;
  final int week;

  // Download section
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

  // Autofill section
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
  final bool running;

  final Future<void> Function() onToggleRunning;
  final Future<void> Function() onReset;
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

  final ValueListenable<List<LogEntry>> logs;
  final VoidCallback onBack;
  final VoidCallback onLogout;

  const NumbersPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.today,
    required this.week,
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
    required this.running,
    required this.onToggleRunning,
    required this.onReset,
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
    required this.onLogout,
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
                    child: Text('الأرقام',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconBtn(
                    icon: isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                      icon: Icons.logout_rounded, onTap: onLogout),
                ],
              ),
              const SizedBox(height: 10),
              // Stats صغيرة فوق
              _miniStatsRow(theme),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 30),
                  children: [
                    _downloadCard(theme),
                    const SizedBox(height: 14),
                    _autofillCard(theme),
                    const SizedBox(height: 14),
                    LogPanel(logs: logs, isDark: isDark, shrink: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ شريط stats صغير
  Widget _miniStatsRow(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            theme,
            icon: Icons.today_rounded,
            title: 'اليوم',
            value: today,
            colors: const [Color(0xFF6C5CE7), Color(0xFF8E7CFF)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            theme,
            icon: Icons.calendar_view_week_rounded,
            title: 'الأسبوع',
            value: week,
            colors: const [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required int value,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: colors.first.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              Text('$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _downloadCard(ThemeData theme) {
    return _card(theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_download_rounded,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('تحميل من الموقع',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
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
                      labelBuilder: (v) =>
                          v == 'full' ? 'Full Num' : 'Local Num',
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

  Widget _autofillCard(ThemeData theme) {
    final current = (currentIndex >= 0 && currentIndex < currentNumbers.length)
        ? currentNumbers[currentIndex]
        : '—';
    final total = currentNumbers.length;

    return _card(theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _masterBar(theme),
          const SizedBox(height: 16),
          _label(theme, Icons.folder_rounded, 'ملف الأرقام'),
          const SizedBox(height: 8),
          _CsvPicker(
            theme: theme,
            files: csvFiles,
            selected: selectedCsvName,
            onSelect: onSelectCsv,
            onRefresh: onRefreshFiles,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: running
                    ? const [Color(0xFF6C5CE7), Color(0xFF00D2FF)]
                    : const [Color(0xFF3A3A4A), Color(0xFF2A2A38)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      running
                          ? Icons.play_circle_fill_rounded
                          : Icons.pause_circle_filled_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(running ? 'شغّال' : 'متوقف',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Text('الرقم الحالي',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12)),
                const SizedBox(height: 6),
                Text(current,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('${currentIndex + 1} / $total',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.repeat_rounded, 'عدد مرات التكرار'),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('repeat-$repeatCount-$infinite'),
                      keyboardType: TextInputType.number,
                      enabled: !infinite,
                      initialValue: repeatCount.toString(),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n > 0) onSetRepeat(n);
                      },
                      decoration: const InputDecoration(
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: infinite
                            ? const LinearGradient(colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFFFF8E53)
                              ])
                            : null,
                        color: infinite
                            ? null
                            : theme.colorScheme.surface.withOpacity(0.6),
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
                              color: infinite
                                  ? Colors.white
                                  : theme.colorScheme.onSurface),
                          const SizedBox(width: 6),
                          Text('∞',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: infinite
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
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

  Widget _masterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: running
            ? const LinearGradient(
                colors: [Color(0xFF00B894), Color(0xFF00D68F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: running ? null : theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: running
              ? Colors.transparent
              : const Color(0xFFFF6B6B).withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: running
                  ? Colors.white.withOpacity(0.25)
                  : theme.colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              running ? Icons.power_settings_new_rounded : Icons.power_off_rounded,
              color: running ? Colors.white : theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? 'التشغيل مفعّل' : 'التشغيل متوقف',
                  style: TextStyle(
                      color:
                          running ? Colors.white : theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  running ? 'الأزرار شغّالة' : 'كل الأزرار متوقفة',
                  style: TextStyle(
                      color: running
                          ? Colors.white.withOpacity(0.8)
                          : theme.colorScheme.onSurface.withOpacity(0.55),
                      fontSize: 11),
                ),
              ],
            ),
          ),
          Material(
            color: running
                ? Colors.white.withOpacity(0.2)
                : theme.colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onReset(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 16,
                        color: running
                            ? Colors.white
                            : theme.colorScheme.onSurface),
                    const SizedBox(width: 4),
                    Text('ريست',
                        style: TextStyle(
                            color: running
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: running,
            onChanged: (v) => onToggleRunning(),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.5),
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
    final enabled = running;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 10.5,
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? (v) => onChanged(v) : null,
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
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
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontSize: 12))),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12)),
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
            border: Border.all(
                color: color.withOpacity(onTap == null ? 0.1 : 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: onTap == null
                      ? theme.colorScheme.onSurface.withOpacity(0.3)
                      : color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: onTap == null
                          ? theme.colorScheme.onSurface.withOpacity(0.3)
                          : color,
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
      ),
      child: child,
    );
  }

  Widget _label(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ═══════════ Range Picker ═══════════
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
            border:
                Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: loading
                    ? Row(children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary)),
                        const SizedBox(width: 10),
                        Text('جاري التحميل…',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                                fontSize: 14)),
                      ])
                    : Text(
                        selected ?? (ranges.isEmpty ? 'مفيش رنجات' : 'اختر رنج'),
                        style: TextStyle(
                          color: selected != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: selected != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
      builder: (ctx) => _RangeSheet(
        ranges: ranges,
        selected: selected,
        onSelect: (r) {
          Navigator.pop(ctx);
          onSelect(r);
        },
      ),
    );
  }
}

class _RangeSheet extends StatefulWidget {
  final List<String> ranges;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _RangeSheet({
    required this.ranges,
    required this.selected,
    required this.onSelect,
  });
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
  void dispose() {
    _search.dispose();
    super.dispose();
  }
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
          Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          Text('اختر الرنج',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: (q) => setState(() {
                filtered = q.trim().isEmpty
                    ? widget.ranges
                    : widget.ranges
                        .where((r) =>
                            r.toLowerCase().contains(q.trim().toLowerCase()))
                        .toList();
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
                ? Center(
                    child: Text('مفيش نتائج',
                        style: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.5))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final r = filtered[i];
                      final isSel = r == widget.selected;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Material(
                          color: isSel
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onSelect(r),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    isSel
                                        ? Icons.radio_button_checked_rounded
                                        : Icons
                                            .radio_button_unchecked_rounded,
                                    color: isSel
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                            .withOpacity(0.4),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(r,
                                          style: TextStyle(
                                              fontWeight: isSel
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontSize: 14))),
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
  final Future<void> Function() onRefresh;

  const _CsvPicker({
    required this.theme,
    required this.files,
    required this.selected,
    required this.onSelect,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: theme.colorScheme.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.description_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  selected ??
                      (files.isEmpty ? 'مفيش ملفات — حمّل الأول' : 'اختر ملف'),
                  style: TextStyle(
                    color: selected != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 14,
                    fontWeight:
                        selected != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
      builder: (ctx) => _CsvSheet(
        initialFiles: files,
        selected: selected,
        onSelect: (name) {
          Navigator.pop(ctx);
          onSelect(name);
        },
        onRefresh: onRefresh,
      ),
    );
  }
}

class _CsvSheet extends StatefulWidget {
  final List<CsvFile> initialFiles;
  final String? selected;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onRefresh;
  const _CsvSheet({
    required this.initialFiles,
    required this.selected,
    required this.onSelect,
    required this.onRefresh,
  });
  @override
  State<_CsvSheet> createState() => _CsvSheetState();
}

class _CsvSheetState extends State<_CsvSheet> {
  late List<CsvFile> files;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    files = widget.initialFiles;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await widget.onRefresh();
      if (!mounted) return;
    });
  }

  @override
  void didUpdateWidget(_CsvSheet old) {
    super.didUpdateWidget(old);
    if (old.initialFiles != widget.initialFiles) {
      setState(() => files = widget.initialFiles);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 16),
          Text('اختر ملف CSV',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Text('مفيش ملفات',
                        style: TextStyle(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.5))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                      final f = files[i];
                      final isSel = f.name == widget.selected;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Material(
                          color: isSel
                              ? theme.colorScheme.primary.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => widget.onSelect(f.name),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    isSel
                                        ? Icons.radio_button_checked_rounded
                                        : Icons
                                            .radio_button_unchecked_rounded,
                                    color: isSel
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface
                                            .withOpacity(0.4),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(f.name,
                                            style: TextStyle(
                                                fontWeight: isSel
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 14)),
                                        Text('${f.count} رقم',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.5))),
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
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.6)),
          style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600),
          items: items
              .map((e) =>
                  DropdownMenuItem<T>(value: e, child: Text(labelBuilder(e))))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}