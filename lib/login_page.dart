import 'package:flutter/material.dart';
import 'widgets.dart';

class LoginPage extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final GlobalKey<FormState> formKey;
  final bool busy;
  final String? error;
  final Future<void> Function() onSubmit;
  final VoidCallback onBack;

  const LoginPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.userCtrl,
    required this.passCtrl,
    required this.formKey,
    required this.busy,
    required this.error,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconBtn(icon: Icons.arrow_back_rounded, onTap: onBack),
                      const Spacer(),
                      IconBtn(
                        icon: isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        onTap: onToggleTheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _logo(theme),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface
                          .withOpacity(isDark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('تسجيل الدخول',
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('ادخل بياناتك للوصول لإحصائيات الرسائل',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6))),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: userCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'من فضلك ادخل اسم المستخدم'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'من فضلك ادخل كلمة المرور'
                                : null,
                            onFieldSubmitted: (_) => onSubmit(),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                            color: theme.colorScheme.error
                                                .withOpacity(0.35)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.error_outline_rounded,
                                              color: theme.colorScheme.error,
                                              size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(error!,
                                                style: TextStyle(
                                                    color: theme
                                                        .colorScheme.error,
                                                    fontSize: 13)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          _submit(theme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('IMS SMS',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 12,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF6C5CE7).withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 14)),
            ],
          ),
          child: const Icon(Icons.sms_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 14),
        Text('لوحة تحكم الرسائل',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _submit(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF6C5CE7).withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : () => onSubmit(),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: busy
                  ? const SizedBox(
                      key: ValueKey('spin'),
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      key: ValueKey('txt'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('دخول',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}