import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:admin/pages/access_page.dart';
import 'package:admin/pages/login_page.dart';
import 'package:admin/shell.dart';
import 'package:admin/theme/app_colors.dart';

/// Gate 1: a Firebase user must be signed in.
/// Gate 2: that user must appear in the `admins` collection; otherwise they
/// get the access-request screen (which also handles first-admin bootstrap).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return _AdminCheck(user: user);
      },
    );
  }
}

class _AdminCheck extends StatelessWidget {
  const _AdminCheck({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        // Live stream: approving/removing this account flips the UI
        // immediately. On read errors we fall through to the access page,
        // which explains the situation instead of a dead spinner.
        if (snapshot.hasData && snapshot.data!.exists) {
          return const AdminShell();
        }
        return AccessPage(user: user);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
