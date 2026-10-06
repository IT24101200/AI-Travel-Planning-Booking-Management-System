import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../services/api_service.dart';

/// Simple route guard that prevents unauthenticated users from seeing inside app data.
/// If user is not logged in, immediately redirects them to the landing page.
class AuthGuard extends StatefulWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _checking = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;

    if (!loggedIn) {
      // User is not signed in: block access and redirect to landing page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/landing', (route) => false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access restricted. Please sign in to view inside app data.'),
              backgroundColor: AppColors.coral500,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    } else {
      setState(() {
        _checking = false;
        _isAuthorized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_isAuthorized) {
      return const Scaffold(
        backgroundColor: AppColors.ivory,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.jungle600),
        ),
      );
    }
    return widget.child;
  }
}
