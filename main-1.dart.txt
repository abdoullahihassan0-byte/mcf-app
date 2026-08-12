import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/session_provider.dart';
import 'screens/auth/otp_auth_screen.dart';
import 'screens/borrower/borrower_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() {
  runApp(const ProviderScope(child: McfApp()));
}

class McfApp extends ConsumerWidget {
  const McfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return MaterialApp(
      title: 'MCF',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F5132), // vert du symbole MCF
        useMaterial3: true,
      ),
      home: !session.isAuthenticated
          ? const OtpAuthScreen()
          : session.user!.isAdmin
              ? const AdminHomeScreen()
              : const BorrowerHomeScreen(),
    );
  }
}
