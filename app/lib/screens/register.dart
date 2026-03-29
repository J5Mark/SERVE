import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/api.dart';
import 'package:app/widgets.dart';

class RegisterScreen extends StatefulWidget {
  final bool showLoginTab;

  const RegisterScreen({super.key, this.showLoginTab = false});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showLoginTab ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Welcome', style: TextStyle(color: AppColors.onSurface)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.person_add), text: 'Register'),
                    Tab(icon: Icon(Icons.login), text: 'Login'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_RegisterForm(), _LoginForm()],
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _phoneCodeController = TextEditingController();
  bool _isEntrepreneur = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  bool _obscurePassword = true;

  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _emailCodeSent = false;
  bool _phoneCodeSent = false;
  bool _sendingEmailCode = false;
  bool _sendingPhoneCode = false;
  bool _verifyingEmail = false;
  bool _verifyingPhone = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emailCodeController.dispose();
    _phoneCodeController.dispose();
    super.dispose();
  }

  bool get _canProceedFromStep1 {
    return _usernameController.text.trim().isNotEmpty &&
        _firstNameController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  bool get _canProceedFromStep2 {
    final hasEmail = _emailController.text.trim().isNotEmpty;
    return !hasEmail || (hasEmail && _emailVerified);
  }

  bool get _canProceedFromStep3 {
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    if (!hasPhone) return true;
    return _phoneVerified;
  }

  bool get _canSubmit {
    return _canProceedFromStep1 && _canProceedFromStep2 && _canProceedFromStep3;
  }

  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter an email first');
      return;
    }

    setState(() {
      _sendingEmailCode = true;
      _error = null;
    });

    try {
      await Api.sendVerificationEmail(email);

      setState(() {
        _emailCodeSent = true;
        _sendingEmailCode = false;
      });
    } catch (e) {
      setState(() {
        _sendingEmailCode = false;
        _error = e is ApiException ? e.displayMessage : e.toString();
      });
    }
  }

  Future<void> _sendPhoneCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter a phone number first');
      return;
    }

    setState(() {
      _sendingPhoneCode = true;
      _error = null;
    });

    try {
      await Api.sendVerificationPhone(phone);

      setState(() {
        _phoneCodeSent = true;
        _sendingPhoneCode = false;
      });
    } catch (e) {
      setState(() {
        _sendingPhoneCode = false;
        _error = e is ApiException ? e.displayMessage : e.toString();
      });
    }
  }

  Future<void> _verifyEmailCode() async {
    if (_emailCodeController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the code');
      return;
    }

    setState(() {
      _verifyingEmail = true;
      _error = null;
    });

    try {
      await Api.verifyEmail(
        _emailController.text.trim(),
        _emailCodeController.text.trim(),
      );
      setState(() {
        _emailVerified = true;
        _verifyingEmail = false;
      });
    } catch (e) {
      setState(() {
        _verifyingEmail = false;
        _error = e is ApiException ? e.displayMessage : e.toString();
      });
    }
  }

  Future<void> _verifyPhoneCode() async {
    if (_phoneCodeController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the code');
      return;
    }

    setState(() {
      _verifyingPhone = true;
      _error = null;
    });

    try {
      await Api.verifyPhone(
        _phoneController.text.trim(),
        _phoneCodeController.text.trim(),
      );
      setState(() {
        _phoneVerified = true;
        _verifyingPhone = false;
      });
    } catch (e) {
      setState(() {
        _verifyingPhone = false;
        _error = e is ApiException ? e.displayMessage : e.toString();
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await Api.register(
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        password: _passwordController.text,
        entrep: _isEntrepreneur,
      );

      if (result.containsKey('access_token') &&
          result.containsKey('refresh_token')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', result['access_token']);
        await prefs.setString('refresh_token', result['refresh_token']);
      }

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.displayMessage : e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStepIndicator(),
                  const SizedBox(height: 24),
                  _buildCurrentStep(),
                ],
              ),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Account', 'Email', 'Phone', 'Create'];
    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (index < _currentStep) {
                setState(() => _currentStep = index);
              }
            },
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? AppColors.primary
                        : AppColors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create Your Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Let\'s get started with your basic info',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(
              Icons.alternate_email,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: 'First Name',
            prefixIcon: Icon(Icons.person, color: AppColors.onSurfaceVariant),
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: 'Last Name',
            prefixIcon: Icon(
              Icons.person_outline,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock, color: AppColors.onSurfaceVariant),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: AppColors.onSurfaceVariant,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          obscureText: _obscurePassword,
          onChanged: (_) => setState(() {}),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: Text(
            'Register as Entrepreneur',
            style: TextStyle(color: AppColors.onSurface),
          ),
          subtitle: Text(
            'Allow creating businesses',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          value: _isEntrepreneur,
          onChanged: (v) => setState(() => _isEntrepreneur = v),
          activeColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final hasEmail = _emailController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll send a verification code to your email',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email, color: AppColors.onSurfaceVariant),
            suffixIcon: _emailVerified
                ? Icon(Icons.check_circle, color: AppColors.primary)
                : _emailCodeSent
                ? null
                : IconButton(
                    icon: _sendingEmailCode
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(Icons.send, color: AppColors.primary),
                    onPressed: _sendingEmailCode || !hasEmail
                        ? null
                        : _sendEmailCode,
                  ),
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
          enabled: !_emailVerified,
        ),
        if (_emailCodeSent && !_emailVerified) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailCodeController,
                  decoration: InputDecoration(
                    labelText: 'Verification code',
                    prefixIcon: Icon(
                      Icons.pin,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  keyboardType: TextInputType.text,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _verifyingEmail ? null : _verifyEmailCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: _verifyingEmail
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Verify'),
              ),
            ],
          ),
        ],
        if (_emailVerified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Email verified',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStep3() {
    final hasPhone = _phoneController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify Your Phone',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Optional - add your phone for account recovery',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone (optional)',
            prefixIcon: Icon(Icons.phone, color: AppColors.onSurfaceVariant),
            suffixIcon: _phoneVerified
                ? Icon(Icons.check_circle, color: AppColors.primary)
                : _phoneCodeSent
                ? null
                : IconButton(
                    icon: _sendingPhoneCode
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(Icons.send, color: AppColors.primary),
                    onPressed: _sendingPhoneCode || !hasPhone
                        ? null
                        : _sendPhoneCode,
                  ),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          enabled: !_phoneVerified,
        ),
        if (_phoneCodeSent && !_phoneVerified) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneCodeController,
                  decoration: InputDecoration(
                    labelText: 'Verification code',
                    prefixIcon: Icon(
                      Icons.pin,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  keyboardType: TextInputType.text,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _verifyingPhone ? null : _verifyPhoneCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: _verifyingPhone
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Verify'),
              ),
            ],
          ),
        ],
        if (_phoneVerified)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Phone verified',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
        if (!hasPhone)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              onPressed: () {
                setState(() => _currentStep = 3);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Skip Phone (optional)'),
            ),
          ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review & Create',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Confirm your details before creating account',
          style: TextStyle(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _buildSummaryRow('Username', _usernameController.text.trim()),
        _buildSummaryRow(
          'Name',
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim(),
        ),
        if (_emailController.text.trim().isNotEmpty)
          _buildSummaryRow(
            'Email',
            _emailController.text.trim(),
            verified: _emailVerified,
          ),
        if (_phoneController.text.trim().isNotEmpty)
          _buildSummaryRow(
            'Phone',
            _phoneController.text.trim(),
            verified: _phoneVerified,
          ),
        _buildSummaryRow(
          'Account Type',
          _isEntrepreneur ? 'Entrepreneur' : 'Regular',
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton(
          onPressed: _isSubmitting || !_canSubmit ? null : _submitRegistration,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _isSubmitting
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Text('Create Account'),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool verified = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (verified)
            Icon(Icons.check_circle, color: AppColors.primary, size: 18),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _currentStep--);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _currentStep == 3
                    ? const Text('Create Account')
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && !_canProceedFromStep1) {
      setState(() => _error = 'Please fill in all required fields');
      return;
    }
    if (_currentStep == 1 && !_canProceedFromStep2) {
      setState(() => _error = 'Please verify your email');
      return;
    }
    if (_currentStep == 2 && !_canProceedFromStep3) {
      setState(() => _error = 'Please verify your phone');
      return;
    }
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
        _error = null;
      });
    }
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final identifier = _identifierController.text.trim();
    final isEmail = identifier.contains('@');
    final isPhone = RegExp(r'^\d+$').hasMatch(identifier);

    try {
      final result = await Api.login(
        username: !isEmail && !isPhone ? identifier : null,
        email: isEmail ? identifier : null,
        phone: isPhone ? identifier : null,
        password: _passwordController.text,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', result['access_token']);
      await prefs.setString('refresh_token', result['refresh_token']);
      await prefs.setInt('user_id', result['user_id']);

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.displayMessage : e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _identifierController,
              decoration: InputDecoration(
                labelText: 'Username, Email, or Phone',
                prefixIcon: Icon(
                  Icons.person,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock, color: AppColors.onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
