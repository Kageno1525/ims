import 'package:flutter/material.dart';
import '../firebase/auth_service.dart';
import '../widgets.dart';

class FirebaseLoginPage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback? onBack;

  const FirebaseLoginPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.onBack,
  });

  @override
  State<FirebaseLoginPage> createState() => _FirebaseLoginPageState();
}

class _FirebaseLoginPageState extends State<FirebaseLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AuthService.signIn(_userCtrl.text.trim(), _passCtrl.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AuthService.arError(e);
      });
      return;
    }
  }

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
                      if (widget.onBack != null)
                        IconBtn(
                            icon: Icons.arrow_back_rounded,
                            onTap: widget.onBack!),
                      const Spacer(),
                      IconBtn(
                        icon: widget.isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        onTap: widget.onToggleTheme,
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
                          .withOpacity(widget.isDark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                          color: theme.colorScheme.primary
                              .withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withOpacity(0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('تسجيل الدخول',
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('ادخل باسم المستخدم وكلمة المرور',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6))),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _userCtrl,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.username
                            ],
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              prefixIcon:
                                  Icon(Icons.person_outline_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'من فضلك اكتب اسم المستخدم';
                              }
                              if (v.trim().length < 3) {
                                return 'اسم المستخدم قصير (3 حروف)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            autofillHints: const [
                              AutofillHints.password
                            ],
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(
                                  Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded),
                                onPressed: () => setState(
                                    () => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'من فضلك اكتب كلمة المرور';
                              }
                              if (v.length < 6) {
                                return 'كلمة المرور قصيرة';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            child: _error == null
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(
                                        top: 14),
                                    child: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                            color: theme
                                                .colorScheme.error
                                                .withOpacity(0.35)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                              Icons
                                                  .error_outline_rounded,
                                              color: theme
                                                  .colorScheme.error,
                                              size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(_error!,
                                                style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .error,
                                                    fontSize: 13,
                                                    decoration:
                                                        TextDecoration
                                                            .none)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          _submitBtn(theme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('IMS',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.4),
                          fontSize: 12,
                          letterSpacing: 2,
                          decoration: TextDecoration.none)),
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
          child: const Icon(Icons.sms_rounded,
              color: Colors.white, size: 44),
        ),
        const SizedBox(height: 14),
        Text('لوحة التحكم',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _submitBtn(ThemeData theme) {
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
          onTap: _busy ? null : _submit,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _busy
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
                                fontSize: 16,
                                decoration: TextDecoration.none)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}