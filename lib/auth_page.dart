import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dart:typed_data';

import 'app_widgets.dart';
import 'auth_service.dart';
import 'firebase_bootstrap.dart';
import 'main.dart';
import 'profile_preferences.dart';
import 'reading_models.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();
  late Future<bool> _firebaseReady;

  @override
  void initState() {
    super.initState();
    _firebaseReady = FirebaseBootstrap.initialize();
  }

  void _retryFirebase() {
    setState(() => _firebaseReady = FirebaseBootstrap.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _firebaseReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _AuthLoading();
        if (snapshot.data != true) {
          return FirebaseSetupPage(onRetry: _retryFirebase);
        }
        return StreamBuilder(
          stream: _auth.authStateChanges,
          builder: (context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const _AuthLoading();
            final user = snapshot.data;
            if (user != null && user.email != null && !user.emailVerified) {
              return EmailVerificationPage(user: user);
            }
            return user == null
                ? const AuthPage()
                : ReadingHomePage(user: user);
          },
        );
      },
    );
  }
}

class FirebaseSetupPage extends StatelessWidget {
  const FirebaseSetupPage({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: AppSurface(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/readwise_logo.png',
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Unable to connect to Firebase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ReadingColors.forest,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign-in is unavailable until Firebase is configured. Check the project configuration and enabled sign-in providers, then retry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ReadingColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry connection'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  Uint8List? _signupAvatar;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AppSurface(
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/readwise_logo.png',
                          width: 92,
                          height: 92,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'READWISE',
                          style: TextStyle(
                            color: ReadingColors.green,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _registering
                            ? 'Create your reading account'
                            : 'Welcome back, reader',
                        style: const TextStyle(
                          color: ReadingColors.forest,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _registering
                            ? 'Save your library, goals, and reading history securely.'
                            : 'Sign in to continue your reading habit.',
                        style: const TextStyle(
                          color: ReadingColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) _ErrorBanner(message: _error!),
                      if (_registering) ...[
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: const Color(0xFFDCEEE5),
                                foregroundImage: _signupAvatar == null
                                    ? null
                                    : MemoryImage(_signupAvatar!),
                                child: _signupAvatar == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 34,
                                        color: ReadingColors.forest,
                                      )
                                    : null,
                              ),
                              TextButton.icon(
                                onPressed: _busy ? null : _chooseSignupAvatar,
                                icon: const Icon(Icons.add_a_photo_outlined),
                                label: Text(
                                  _signupAvatar == null
                                      ? 'Choose profile picture (optional)'
                                      : 'Change profile picture',
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a username'
                              : !RegExp(r'^[a-zA-Z0-9._]{3,20}$')
                                    .hasMatch(value.trim())
                              ? 'Use 3–20 letters, numbers, dots, or underscores'
                              : null,
                        ),
                        const SizedBox(height: 13),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Enter your email';
                          if (!email.contains('@'))
                            return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password';
                          }
                          if (value.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (!_registering)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy ? null : _resetPassword,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _registering ? 'Create account' : 'Sign in',
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: ReadingColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _signInWithGoogle,
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 28,
                          ),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _registering = !_registering;
                                  _error = null;
                                }),
                          child: Text(
                            _registering
                                ? 'Already have an account? Sign in'
                                : 'New here? Create an account',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await _auth.register(
          username: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          avatarBytes: _signupAvatar,
        );
      } else {
        await _auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseSignupAvatar() async {
    try {
      final bytes = await ProfilePreferences.instance.pickAvatarBytes();
      if (bytes != null && mounted) setState(() => _signupAvatar = bytes);
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.messageFor(error));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
    } catch (error) {
      if (mounted && !AuthService.isSignInCancelled(error)) {
        setState(() => _error = AuthService.messageFor(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error = 'Enter your email first, then tap Forgot password.',
      );
      return;
    }
    try {
      await _auth.sendPasswordReset(email);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.messageFor(error));
    }
  }
}

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, required this.user});

  final User user;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final AuthService _auth = AuthService();
  bool _busy = false;
  String? _message;

  Future<void> _checkVerification() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _auth.refreshCurrentUser();
      if (mounted && !(_auth.currentUser?.emailVerified ?? false)) {
        setState(
          () => _message = 'Still waiting for verification. Open the email link, then check again.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _auth.resendEmailVerification();
      if (mounted) {
        setState(
          () => _message =
              'A new verification link was sent to ${widget.user.email}.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await _auth.signOut();
    } catch (error) {
      if (mounted) setState(() => _message = AuthService.messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AppSurface(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/readwise_logo.png',
                      width: 82,
                      height: 82,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ReadingColors.forest,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to ${widget.user.email ?? 'your email'}. Open it, then return here to continue.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ReadingColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(_message!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _checkVerification,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('I verified my email'),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _resendVerification,
                      child: const Text('Resend verification email'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _signOut,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthLoading extends StatelessWidget {
  const _AuthLoading();

  @override
  Widget build(BuildContext context) =>
      const AppLoadingScreen(message: 'Connecting your reading account…');
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: const TextStyle(color: Color(0xFF9B3F3F), height: 1.35),
    ),
  );
}
