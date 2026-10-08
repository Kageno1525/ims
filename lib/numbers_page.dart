import 'package:flutter/material.dart';
import 'widgets.dart';
import 'models.dart';

class NumbersPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final List<String> ranges;
  final String? selectedRange;
  final int selectedCount;
  final String selectedType;
  final bool loadingRanges;
  final bool busy;
  final List<LogEntry> logs;
  final VoidCallback onBack;
  final Future<void> Function() onRefreshRanges;
  final ValueChanged<String> onSelectRange;
  final ValueChanged<int> onSelectCount;
  final ValueChanged<String> onSelectType;
  final Future<void> Function() onApplyFilter;
  final Future<void> Function() onDownloadCsv;

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
    required this.logs,
    required this.onBack,
    required this.onRefreshRanges,
    required this.onSelectRange,
    required this.onSelectCount,
    required this.onSelectType,
    required this.onApplyFilter,
    required this.onDownloadCsv,
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
                        Text('الأرقام', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text('اختر الرنج وفلتره وحمّله',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    onTap: onToggleTheme,
                  ),
                  const SizedBox(width: 8),
                  IconBtn(
                    icon: Icons.refresh_rounded,
                    spinning: loadingRanges,
                    onTap: loadingRanges ? null : () => onRefreshRanges(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _card(theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(theme, Icons.sim_card_rounded, 'الرنج'),
                    const SizedBox(height: 10),
                    _RangePicker(
                      theme: theme,
                      ranges: ranges,
                      selected: selectedRange,
                      loading: loadingRanges,
                      onSelect: onSelectRange,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(theme, Icons.numbers_rounded, 'العدد'),
                              const SizedBox(height: 10),
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
                              const SizedBox(height: 10),
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
                    const SizedBox(height: 20),
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
              ),
              const SizedBox(height: 16),
              Expanded(child: LogPanel(logs: logs, isDark: isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
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