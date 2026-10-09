class TemplateResolver {
  TemplateResolver._();

  static final _varPattern = RegExp(r'\{[^}]+\}');

  static bool hasVariables(String input) => _varPattern.hasMatch(input);

  static String resolve(
    String input, {
    required List<String> numbers,
    required int currentIndex,
  }) {
    if (input.isEmpty) return input;
    var out = input;
    final now = DateTime.now();

    if (numbers.isNotEmpty &&
        currentIndex >= 0 &&
        currentIndex < numbers.length) {
      out = out.replaceAll('{num}', numbers[currentIndex]);
    } else {
      out = out.replaceAll('{num}', '');
    }

    out = out.replaceAllMapped(RegExp(r'\{num:(\d+)\}'), (m) {
      final idx = int.tryParse(m.group(1) ?? '0') ?? 0;
      if (idx >= 0 && idx < numbers.length) return numbers[idx];
      return '';
    });

    final y = now.year.toString();
    final mo = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    out = out.replaceAll('{date}', '$y-$mo-$d');

    final h = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    out = out.replaceAll('{time}', '$h:$mi');

    out = out.replaceAll('{datetime}', '$y-$mo-$d $h:$mi');
    out = out.replaceAll('{index}', currentIndex.toString());

    return out;
  }
}