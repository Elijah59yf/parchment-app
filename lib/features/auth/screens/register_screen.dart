import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

/// Registration screen: first name, last name, matric number, email,
/// password -> POST /auth/register.
///
/// Matches the backend's Zod schema (registerSchema): firstName and
/// lastName 1-50 chars each, matricNumber 9 digits, valid email,
/// password 8-72 chars. On success, persists tokens and marks the
/// session authenticated - same pattern as LoginScreen, and lets
/// app_router's redirect send the user to /feed.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _matricController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _matricController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Required';
    if (trimmed.length > 50) return 'Too long';
    return null;
  }

  String? _validateLastName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Required';
    if (trimmed.length > 50) return 'Too long';
    return null;
  }

  String? _validateMatric(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter your matric number';
    if (!RegExp(r'^\d{9}$').hasMatch(trimmed)) {
      return 'Matric number should be 9 digits (e.g. 240408019)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter your email';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (value.length > 72) return 'Password is too long';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'Passwords don\'t match';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isSubmitting = true);

    final apiClient = ref.read(apiClientProvider);
    final tokenStorage = ref.read(tokenStorageProvider);

    try {
      final response = await apiClient.dio.post(
        '/auth/register',
        data: {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'matricNumber': _matricController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;

      await tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      ref.read(authStatusProvider.notifier).setAuthenticated();
      // Router redirect takes it from here.
    } on DioException catch (e) {
      if (!mounted) return;
      _showErrorDialog(_dioErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _dioErrorMessage(DioException e) {
    // Backend returns { error: "message" } on 4xx responses, including
    // "Unrecognized faculty/department code", "Registration is not
    // currently open for your cohort", and "already registered" cases.
    final data = e.response?.data;
    if (data is Map && data['error'] is String) {
      return data['error'] as String;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Couldn\'t reach the server. Check your connection and try again '
          '(the backend may be waking up from idle, so this can take a moment).';
    }
    return 'Something went wrong. Please try again.';
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button and logo share one header row instead of
                // stacking as two disconnected elements.
                Row(
                  children: [
                    IconButton(
                      onPressed: _isSubmitting ? null : () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 12),
                    const AppLogoLockup(),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'Create your account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Your year, faculty, and department are worked out '
                  'automatically from your matric number.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 28),
                _SplitNameField(
                  firstNameController: _firstNameController,
                  lastNameController: _lastNameController,
                  validateFirstName: _validateFirstName,
                  validateLastName: _validateLastName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _matricController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Matric number',
                    hintText: '240408019',
                  ),
                  validator: _validateMatric,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirmPassword =
                            !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  validator: _validateConfirmPassword,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Create account'),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : () => context.pop(),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationThickness: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// First/Last name as one bordered field split by a divider, rather
/// than two independent outlined boxes sitting side by side - reads
/// as "one Name field with two segments" instead of one field that
/// got hurriedly cut in half. The two segments still validate,
/// autofill, and submit independently; only the visual container is
/// shared. Tracks focus across both inner fields so the shared border
/// still darkens on focus, matching every other field's behavior
/// (see AppTheme.inputDecorationTheme) - error text still surfaces
/// per-segment below itself, same as any other field.
class _SplitNameField extends StatefulWidget {
  const _SplitNameField({
    required this.firstNameController,
    required this.lastNameController,
    required this.validateFirstName,
    required this.validateLastName,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final FormFieldValidator<String> validateFirstName;
  final FormFieldValidator<String> validateLastName;

  @override
  State<_SplitNameField> createState() => _SplitNameFieldState();
}

class _SplitNameFieldState extends State<_SplitNameField> {
  final _firstFocus = FocusNode();
  final _lastFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _firstFocus.addListener(_onFocusChange);
    _lastFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _firstFocus.removeListener(_onFocusChange);
    _lastFocus.removeListener(_onFocusChange);
    _firstFocus.dispose();
    _lastFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isFocused = _firstFocus.hasFocus || _lastFocus.hasFocus;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isFocused ? AppTheme.borderStrong : AppTheme.border,
          width: isFocused ? 1.6 : 1.2,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.firstNameController,
                focusNode: _firstFocus,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.givenName],
                decoration: const InputDecoration(
                  labelText: 'First name',
                  border: InputBorder.none,
                ),
                validator: widget.validateFirstName,
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.border),
            Expanded(
              child: TextFormField(
                controller: widget.lastNameController,
                focusNode: _lastFocus,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.familyName],
                decoration: const InputDecoration(
                  labelText: 'Last name',
                  border: InputBorder.none,
                ),
                validator: widget.validateLastName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
