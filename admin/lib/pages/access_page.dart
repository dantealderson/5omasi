import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';
import 'package:admin/widgets/ui.dart';

/// Shown to a signed-in account that is not (yet) an admin.
///
/// Two paths in:
///   * No admins exist at all → this account can claim the first admin seat
///     (solves the cold-start problem).
///   * Admins exist → send an access request; an existing admin approves it
///     from the المشرفون page.
class AccessPage extends StatefulWidget {
  const AccessPage({super.key, required this.user});

  final User user;

  @override
  State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends State<AccessPage> {
  late Future<bool> _anyAdminExists;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anyAdminExists = _checkAnyAdmin();
  }

  Future<bool> _checkAnyAdmin() async {
    final snap = await FirebaseFirestore.instance
        .collection('admins')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> _claimFirstAdmin() async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(widget.user.uid)
          .set({
        'email': widget.user.email,
        'addedBy': 'bootstrap',
        'addedAt': Timestamp.now(),
      });
      // AuthGate's stream flips to the shell automatically.
    } catch (e) {
      if (mounted) showAppSnack(context, 'تعذر التفعيل: $e', danger: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendRequest() async {
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection('adminRequests')
          .doc(widget.user.uid)
          .set({
        'email': widget.user.email,
        'requestedAt': Timestamp.now(),
      });
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'تعذر إرسال الطلب: $e', danger: true);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancelRequest() async {
    try {
      await FirebaseFirestore.instance
          .collection('adminRequests')
          .doc(widget.user.uid)
          .delete();
    } catch (e) {
      if (mounted) showAppSnack(context, 'خطأ: $e', danger: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'خماسي',
                  style: AppText.kufi(size: 40, weight: 700, color: p.textHi),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.line),
                  ),
                  child: FutureBuilder<bool>(
                    future: _anyAdminExists,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child:
                              Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return _ErrorBody(error: '${snapshot.error}');
                      }
                      final anyAdmin = snapshot.data ?? false;
                      return anyAdmin
                          ? _RequestBody(
                              user: widget.user,
                              busy: _busy,
                              onSend: _sendRequest,
                              onCancel: _cancelRequest,
                            )
                          : _BootstrapBody(
                              busy: _busy,
                              onClaim: _claimFirstAdmin,
                            );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.user.email ?? '',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: p.textLow, fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// No admin exists anywhere yet — offer the first seat.
class _BootstrapBody extends StatelessWidget {
  const _BootstrapBody({required this.busy, required this.onClaim});

  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Icon(Icons.workspace_premium_outlined, size: 44, color: p.gold),
        const SizedBox(height: 14),
        Text('لا يوجد مشرفون بعد',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'أنت أول من يصل إلى مكتب العمليات. فعّل حسابك كأول مشرف، وبعدها تستطيع إضافة بقية المشرفين من داخل التطبيق.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textMid, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: busy ? null : onClaim,
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: const Text('تفعيل حسابي كأول مشرف'),
          ),
        ),
      ],
    );
  }
}

/// Admins exist — this account needs one of them to approve it.
class _RequestBody extends StatelessWidget {
  const _RequestBody({
    required this.user,
    required this.busy,
    required this.onSend,
    required this.onCancel,
  });

  final User user;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('adminRequests')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final hasRequest = snapshot.hasData && snapshot.data!.exists;

        return Column(
          children: [
            Icon(
              hasRequest
                  ? Icons.hourglass_top_outlined
                  : Icons.lock_outline,
              size: 44,
              color: hasRequest ? p.gold : p.textLow,
            ),
            const SizedBox(height: 14),
            Text(
              hasRequest ? 'طلبك قيد الانتظار' : 'هذا الحساب ليس مشرفاً',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              hasRequest
                  ? 'أُرسل طلبك إلى المشرفين الحاليين. عند الموافقة سيُفتح مكتب العمليات تلقائياً.'
                  : 'أرسل طلب صلاحية ليوافق عليه أحد المشرفين الحاليين من صفحة «المشرفون».',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMid, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: hasRequest
                  ? OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('إلغاء الطلب'),
                    )
                  : ElevatedButton.icon(
                      onPressed: busy ? null : onSend,
                      icon: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: const Text('إرسال طلب صلاحية'),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Icon(Icons.error_outline, size: 44, color: p.danger),
        const SizedBox(height: 14),
        Text('تعذر التحقق من الصلاحية',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          error,
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textMid, fontSize: 12),
        ),
      ],
    );
  }
}
