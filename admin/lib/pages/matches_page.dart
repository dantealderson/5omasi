import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';
import 'package:admin/widgets/ui.dart';

/// Fixtures desk: create matches (writes the same document shape the mobile
/// app reads) and manage the upcoming list.
class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;

        final header = const PageHeader(
          title: 'المباريات',
          hint: 'أنشئ مباراة جديدة أو احذف مباراة قادمة — تظهر التغييرات فوراً في تطبيق اللاعبين',
        );

        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 40),
                              child: const SurfaceCard(
                                  child: CreateMatchForm()),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 9,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 40),
                              child: const UpcomingMatchesList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final phone = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(phone ? 14 : 24, 28, phone ? 14 : 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 24),
              const SurfaceCard(child: CreateMatchForm()),
              const SizedBox(height: 24),
              const UpcomingMatchesList(),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// CREATE MATCH FORM
// ============================================================

class CreateMatchForm extends StatefulWidget {
  const CreateMatchForm({super.key});

  @override
  State<CreateMatchForm> createState() => _CreateMatchFormState();
}

class _CreateMatchFormState extends State<CreateMatchForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedStadiumId;
  Map<String, dynamic>? _selectedStadium;
  List<int> _availableSizes = [];

  final _priceController = TextEditingController(text: '5000');

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 20, minute: 0);
  int? _maxPlayers;
  int _durationMinutes = 60;
  bool _isRecurring = false;
  int _recurringWeeks = 4;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  /// Same client-side overlap check the test page used: same stadium, same
  /// size, overlapping time window.
  Future<bool> _checkForConflict() async {
    final matchDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final matchEnd = matchDateTime.add(Duration(minutes: _durationMinutes));

    try {
      final existingMatches = await FirebaseFirestore.instance
          .collection('matches')
          .where('stadiumId', isEqualTo: _selectedStadiumId)
          .where('status', isEqualTo: 'open')
          .get();

      for (var doc in existingMatches.docs) {
        final data = doc.data();
        if (data['maxPlayers'] != _maxPlayers) continue;

        final existingStart = (data['dateTime'] as Timestamp).toDate();
        final existingEnd = existingStart
            .add(Duration(minutes: data['durationMinutes'] ?? 60));

        if (matchDateTime.isBefore(existingEnd) &&
            matchEnd.isAfter(existingStart)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking conflict: $e');
      return false;
    }
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStadium == null) {
      showAppSnack(context, 'اختر ملعباً أولاً', danger: true);
      return;
    }
    if (_maxPlayers == null) {
      showAppSnack(context, 'اختر حجم الملعب', danger: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hasConflict = await _checkForConflict();
      if (hasConflict) {
        if (mounted) {
          showAppSnack(context, 'يوجد مباراة أخرى بنفس الوقت والحجم في هذا الملعب',
              danger: true);
        }
        setState(() => _isLoading = false);
        return;
      }

      final matchDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final int totalMatches = _isRecurring ? _recurringWeeks : 1;
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      for (int i = 0; i < totalMatches; i++) {
        final thisDateTime = matchDateTime.add(Duration(days: 7 * i));
        await FirebaseFirestore.instance.collection('matches').add({
          'stadiumId': _selectedStadiumId,
          'stadiumName': _selectedStadium!['name'],
          'stadiumAddress': _selectedStadium!['address'],
          'googleMapsUrl': _selectedStadium!['googleMapsUrl'],
          'locationText': _selectedStadium!['locationText'],
          'location': _selectedStadium!['location'],
          'stadiumImage': _selectedStadium!['imageUrl'],
          'pitchImageUrl': _selectedStadium!['imageUrl'],
          'dateTime': Timestamp.fromDate(thisDateTime),
          'durationMinutes': _durationMinutes,
          'pricePerPlayer': double.parse(_priceController.text),
          'maxPlayers': _maxPlayers,
          'currentPlayers': 0,
          'status': 'open',
          'surfaceType': _selectedStadium!['surfaceType'] ?? 'artificial',
          'refereeId': null,
          'refereeName': null,
          'createdBy': adminUid,
          'createdAt': Timestamp.now(),
          'teamAName': 'الفريق الأزرق',
          'teamBName': 'الفريق الأحمر',
          'teamAPlayers': [],
          'teamBPlayers': [],
          'teamAScore': 0,
          'teamBScore': 0,
          'totalYellowCards': 0,
          'totalRedCards': 0,
          'isRecurring': _isRecurring,
        });
      }

      if (mounted) {
        showAppSnack(
          context,
          _isRecurring
              ? 'تم إنشاء $totalMatches مباريات أسبوعية'
              : 'تم إنشاء المباراة',
        );
      }
      _resetForm();
    } catch (e) {
      if (mounted) showAppSnack(context, 'خطأ: $e', danger: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _resetForm() {
    setState(() {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = const TimeOfDay(hour: 20, minute: 0);
      _maxPlayers = _availableSizes.isNotEmpty ? _availableSizes.first : null;
      _durationMinutes = 60;
      _priceController.text = '5000';
      _isRecurring = false;
      _recurringWeeks = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Form(
      key: _formKey,
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;

        // Two fields side by side on desktop, stacked on narrow screens.
        Widget pair(Widget a, Widget b) => narrow
            ? Column(children: [a, const SizedBox(height: 16), b])
            : Row(children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ]);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const SectionHeader(title: 'مباراة جديدة', icon: Icons.add_circle_outline),
          const SizedBox(height: 18),

          // Stadium picker (live from Firestore).
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stadiums')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final stadiums = (snapshot.data?.docs ?? [])
                  .map((doc) => {
                        'id': doc.id,
                        ...doc.data() as Map<String, dynamic>,
                      })
                  .toList();

              if (stadiums.isEmpty) {
                return const EmptyState(
                  icon: Icons.stadium_outlined,
                  title: 'لا توجد ملاعب',
                  hint: 'أضف ملعباً من تبويب الملاعب أولاً',
                );
              }

              // Drop the selection if the stadium disappeared.
              final ids = stadiums.map((s) => s['id']).toSet();
              final selectedId =
                  ids.contains(_selectedStadiumId) ? _selectedStadiumId : null;

              return DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(
                  labelText: 'الملعب',
                  prefixIcon: Icon(Icons.stadium_outlined),
                ),
                hint: const Text('اختر ملعباً'),
                items: stadiums
                    .map((stadium) => DropdownMenuItem<String>(
                          value: stadium['id'] as String,
                          child: Text(stadium['name'] ?? 'بدون اسم'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStadiumId = value;
                    _selectedStadium = stadiums.firstWhere(
                      (s) => s['id'] == value,
                      orElse: () => {},
                    );
                    _availableSizes = List<int>.from(
                        _selectedStadium?['availableSizes'] ?? [10]);
                    _maxPlayers = _availableSizes.isNotEmpty
                        ? _availableSizes.first
                        : null;
                  });
                },
              );
            },
          ),

          if (_selectedStadium != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.emeraldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: p.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedStadium!['address'] ?? 'لا يوجد عنوان',
                      style: TextStyle(color: p.textMid, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MiniChip(
                      label: surfaceLabel(_selectedStadium!['surfaceType'])),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),
          const SectionHeader(
              title: 'تفاصيل المباراة', icon: Icons.sports_soccer),
          const SizedBox(height: 16),

          pair(
            _PickerField(
              icon: Icons.calendar_today_outlined,
              label: 'التاريخ',
              value: formatDate(_selectedDate),
              onTap: _selectDate,
            ),
            _PickerField(
              icon: Icons.access_time,
              label: 'الوقت',
              value: formatTimeOfDay(_selectedTime),
              onTap: _selectTime,
            ),
          ),
          const SizedBox(height: 16),

          pair(
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر للاعب (د.ع)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'مطلوب';
                if (double.tryParse(v) == null) return 'رقم غير صحيح';
                return null;
              },
            ),
            DropdownButtonFormField<int>(
              value: _durationMinutes,
              decoration: const InputDecoration(
                labelText: 'المدة',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              items: [30, 45, 60, 90]
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text('$m دقيقة')))
                  .toList(),
              onChanged: (v) => setState(() => _durationMinutes = v!),
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            value: _maxPlayers,
            decoration: const InputDecoration(
              labelText: 'حجم الملعب',
              prefixIcon: Icon(Icons.people_outline),
            ),
            hint: Text(_selectedStadium == null
                ? 'اختر ملعباً أولاً'
                : 'اختر الحجم'),
            items: _availableSizes
                .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text('${n ~/ 2}v${n ~/ 2} ($n لاعب)'),
                    ))
                .toList(),
            onChanged: _selectedStadium == null
                ? null
                : (v) => setState(() => _maxPlayers = v),
          ),
          const SizedBox(height: 18),

          // Weekly recurrence.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _isRecurring ? p.emerald : p.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('مباراة متكررة أسبوعياً'),
                  subtitle: const Text('إنشاء نفس المباراة كل أسبوع'),
                  value: _isRecurring,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _isRecurring = v),
                ),
                if (_isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(Icons.repeat, color: p.emerald, size: 18),
                        const Text('عدد الأسابيع:'),
                        ...[2, 4, 6, 8].map((w) => ChoiceChip(
                              label: Text('$w'),
                              selected: _recurringWeeks == w,
                              onSelected: (_) =>
                                  setState(() => _recurringWeeks = w),
                            )),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createMatch,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isRecurring
                  ? 'إنشاء $_recurringWeeks مباريات'
                  : 'إنشاء المباراة'),
            ),
          ),
          ],
        );
      }),
    );
  }
}

/// Bordered tap-to-pick field (date / time).
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: p.emerald, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(color: p.textLow, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: AppText.mono(size: 15, color: p.textHi),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// UPCOMING MATCHES LIST
// ============================================================

class UpcomingMatchesList extends StatelessWidget {
  const UpcomingMatchesList({super.key});

  Future<void> _delete(BuildContext context, String matchId,
      String? stadiumName) async {
    final ok = await confirmDanger(
      context,
      title: 'حذف المباراة',
      message: 'هل تريد حذف المباراة في "${stadiumName ?? 'ملعب'}"؟',
    );
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .delete();
    if (context.mounted) showAppSnack(context, 'تم حذف المباراة');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
            title: 'المباريات القادمة', icon: Icons.upcoming_outlined),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .where('status', isEqualTo: 'open')
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
                title: 'تعذر تحميل المباريات',
                hint: '${snapshot.error}',
              );
            }

            final now = DateTime.now();
            final docs = (snapshot.data?.docs ?? []).where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final dt = (data['dateTime'] as Timestamp?)?.toDate();
              return dt != null && dt.isAfter(now);
            }).toList()
              ..sort((a, b) {
                final at =
                    ((a.data() as Map)['dateTime'] as Timestamp).toDate();
                final bt =
                    ((b.data() as Map)['dateTime'] as Timestamp).toDate();
                return at.compareTo(bt);
              });

            if (docs.isEmpty) {
              return const EmptyState(
                icon: Icons.event_available_outlined,
                title: 'لا توجد مباريات قادمة',
                hint: 'المباريات التي تنشئها ستظهر هنا',
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final dt = (data['dateTime'] as Timestamp).toDate();
                final maxPlayers = (data['maxPlayers'] ?? 10) as int;
                final side = maxPlayers ~/ 2;
                final currentPlayers = (data['currentPlayers'] ?? 0) as int;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.emeraldSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${side}v$side',
                          textDirection: TextDirection.ltr,
                          style: AppText.mono(size: 13, color: p.emerald),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['stadiumName'] ?? 'ملعب',
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${formatDate(dt)} — ${formatTime(dt)}',
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              style:
                                  AppText.mono(size: 12, color: p.textMid),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentPlayers/$maxPlayers',
                        textDirection: TextDirection.ltr,
                        style: AppText.mono(size: 13, color: p.textMid),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: p.danger, size: 20),
                        tooltip: 'حذف المباراة',
                        onPressed: () =>
                            _delete(context, doc.id, data['stadiumName']),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
