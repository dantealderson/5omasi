import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';
import 'package:admin/widgets/ui.dart';

/// Roster of who can use the operations desk: approve/reject access
/// requests, add an admin by email, remove admins.
class AdminsPage extends StatelessWidget {
  const AdminsPage({super.key});

  Future<void> _approve(
      BuildContext context, String uid, String? email) async {
    final me = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('admins').doc(uid),
        {'email': email, 'addedBy': me, 'addedAt': Timestamp.now()},
      );
      batch.delete(
          FirebaseFirestore.instance.collection('adminRequests').doc(uid));
      await batch.commit();
      if (context.mounted) showAppSnack(context, 'تمت الموافقة — $email مشرف الآن');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'خطأ: $e', danger: true);
    }
  }

  Future<void> _reject(
      BuildContext context, String uid, String? email) async {
    final ok = await confirmDanger(
      context,
      title: 'رفض الطلب',
      message: 'رفض طلب "$email"؟ يمكنه إرسال طلب جديد لاحقاً.',
      confirmLabel: 'رفض',
    );
    if (!ok) return;
    try {
      await FirebaseFirestore.instance
          .collection('adminRequests')
          .doc(uid)
          .delete();
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'خطأ: $e', danger: true);
    }
  }

  Future<void> _remove(
      BuildContext context, String uid, String? email) async {
    final ok = await confirmDanger(
      context,
      title: 'إزالة مشرف',
      message:
          'إزالة "$email" من المشرفين؟ سيفقد الوصول إلى مكتب العمليات فوراً.',
      confirmLabel: 'إزالة',
    );
    if (!ok) return;
    try {
      await FirebaseFirestore.instance.collection('admins').doc(uid).delete();
      if (context.mounted) showAppSnack(context, 'تمت إزالة المشرف');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'خطأ: $e', danger: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: PageHeader(
                      title: 'المشرفون',
                      hint: 'من يستطيع الدخول إلى مكتب العمليات',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const _AddAdminDialog(),
                    ),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('إضافة مشرف'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pending access requests.
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('adminRequests')
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                          title: 'طلبات الوصول',
                          icon: Icons.mark_email_unread_outlined),
                      const SizedBox(height: 14),
                      SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < docs.length; i++) ...[
                              if (i > 0) Divider(color: p.line, height: 1),
                              _RequestRow(
                                data: docs[i].data()
                                    as Map<String, dynamic>,
                                onApprove: () => _approve(
                                  context,
                                  docs[i].id,
                                  (docs[i].data() as Map)['email'],
                                ),
                                onReject: () => _reject(
                                  context,
                                  docs[i].id,
                                  (docs[i].data() as Map)['email'],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  );
                },
              ),

              const SectionHeader(
                  title: 'المشرفون الحاليون',
                  icon: Icons.admin_panel_settings_outlined),
              const SizedBox(height: 14),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('admins')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.error_outline,
                      title: 'تعذر تحميل المشرفين',
                      hint: '${snapshot.error}',
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const EmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'لا يوجد مشرفون',
                    );
                  }

                  return SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < docs.length; i++) ...[
                          if (i > 0) Divider(color: p.line, height: 1),
                          _AdminRow(
                            data: docs[i].data() as Map<String, dynamic>,
                            isMe: docs[i].id == myUid,
                            onRemove: () => _remove(
                              context,
                              docs[i].id,
                              (docs[i].data() as Map)['email'],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.data,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: p.gold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['email'] ?? '—',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (requestedAt != null)
                  Text(
                    '${formatDate(requestedAt)} — ${formatTime(requestedAt)}',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: AppText.mono(size: 11, color: p.textLow),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.danger,
              side: BorderSide(color: p.danger),
              minimumSize: const Size(0, 40),
            ),
            child: const Text('رفض'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('موافقة'),
          ),
        ],
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.data,
    required this.isMe,
    required this.onRemove,
  });

  final Map<String, dynamic> data;
  final bool isMe;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final addedAt = (data['addedAt'] as Timestamp?)?.toDate();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: p.emerald, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        data['email'] ?? '—',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      const MiniChip(label: 'أنت'),
                    ],
                  ],
                ),
                if (addedAt != null)
                  Text(
                    'أُضيف في ${formatDate(addedAt)}',
                    style: TextStyle(color: p.textLow, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (!isMe)
            IconButton(
              icon: Icon(Icons.person_remove_outlined,
                  color: p.danger, size: 20),
              tooltip: 'إزالة المشرف',
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Add an admin directly by email — works for accounts that exist in the
/// mobile app's `users` collection. Accounts created from the admin login
/// screen should use the request flow instead.
class _AddAdminDialog extends StatefulWidget {
  const _AddAdminDialog();

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final email = _controller.text.toLowerCase().trim();
    if (email.isEmpty) {
      setState(() => _error = 'أدخل البريد الإلكتروني');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        setState(() {
          _error =
              'لا يوجد حساب بهذا البريد في خماسي. اطلب من صاحبه فتح تطبيق الإدارة وإنشاء حساب ثم إرسال طلب صلاحية، وستظهر موافقته هنا.';
          _busy = false;
        });
        return;
      }

      final uid = userQuery.docs.first.id;
      final adminDoc =
          FirebaseFirestore.instance.collection('admins').doc(uid);
      if ((await adminDoc.get()).exists) {
        setState(() {
          _error = 'هذا الحساب مشرف بالفعل';
          _busy = false;
        });
        return;
      }

      final me = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await adminDoc.set({
        'email': email,
        'addedBy': me,
        'addedAt': Timestamp.now(),
      });

      if (mounted) {
        Navigator.pop(context);
        showAppSnack(context, 'أصبح $email مشرفاً');
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ: $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AlertDialog(
      title: const Text('إضافة مشرف'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'أدخل البريد الإلكتروني لحساب خماسي موجود لمنحه صلاحية مشرف.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              onSubmitted: (_) => _add(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: p.danger, fontSize: 13, height: 1.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _add,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إضافة'),
        ),
      ],
    );
  }
}
