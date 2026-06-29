import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final ok = await ref.read(authControllerProvider.notifier).register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
    if (ok && mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;
    final error = state.hasError
        ? ref.read(authControllerProvider.notifier).errorMessage
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Join Ludo Friends', style: AppTextStyles.display),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                      hintText: 'Display name', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(
                      hintText: 'Email', prefixIcon: Icon(Icons.mail)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      hintText: 'Password (min 8 chars)',
                      prefixIcon: Icon(Icons.lock)),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error,
                      style: AppTextStyles.label
                          .copyWith(color: Colors.amberAccent)),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                    label: 'Create Account',
                    loading: loading,
                    onPressed: _register),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Already have an account? Sign in',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
