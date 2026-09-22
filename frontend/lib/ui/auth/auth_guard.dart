import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'auth_modal.dart';

class AuthGuard {
  static void runGuarded(
    BuildContext context, {
    required VoidCallback onAuthorized,
    String message = 'Sign in to access watch party and member features',
  }) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isAuthenticated) {
      onAuthorized();
    } else {
      AuthModal.show(context, promptMessage: message).then((authenticated) {
        if (authenticated) {
          onAuthorized();
        }
      });
    }
  }
}
