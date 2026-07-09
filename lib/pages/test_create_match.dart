import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:khomasi/services/image_upload_service.dart';

/// Simple test page for creating matches and stadiums
/// This is temporary - admin desktop app will handle this later
class TestCreateMatchPage extends StatefulWidget {
  const TestCreateMatchPage({super.key});

  @override
  State<TestCreateMatchPage> createState() => _TestCreateMatchPageState();
}

class _TestCreateMatchPageState extends State<TestCreateMatchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Warning banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'هذه صفحة تجريبية للاختبار فقط - تطبيق الادمن سيتولى هذه المهمة لاحقاً',
                    style: TextStyle(
                      color: isDark ? Colors.orange[200] : Colors.orange[800],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              tabs: const [
                Tab(text: 'إنشاء مباراة'),
                Tab(text: 'إدارة الملاعب'),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CreateMatchTab(),
                _ManageStadiumsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// CREATE MATCH TAB
// ============================================

class _CreateMatchTab extends StatefulWidget {
  @override
  State<_CreateMatchTab> createState() => _CreateMatchTabState();
}

class _CreateMatchTabState extends State<_CreateMatchTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingStadiums = true;
  
  List<Map<String, dynamic>> _stadiums = [];
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
  void initState() {
    super.initState();
    _loadStadiums();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadStadiums() async {
    setState(() => _isLoadingStadiums = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stadiums')
          .where('isActive', isEqualTo: true)
          .get();
      
      setState(() {
        _stadiums = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        _isLoadingStadiums = false;
      });
    } catch (e) {
      print('Error loading stadiums: $e');
      setState(() => _isLoadingStadiums = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

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
      // Simple query - just get matches for this stadium, filter client-side
      final existingMatches = await FirebaseFirestore.instance
          .collection('matches')
          .where('stadiumId', isEqualTo: _selectedStadiumId)
          .where('status', isEqualTo: 'open')
          .get();
      
      for (var doc in existingMatches.docs) {
        final data = doc.data();
        
        // Check if same size
        if (data['maxPlayers'] != _maxPlayers) continue;
        
        final existingStart = (data['dateTime'] as Timestamp).toDate();
        final existingEnd = existingStart.add(Duration(minutes: data['durationMinutes'] ?? 60));
        
        // Check for time overlap
        if (matchDateTime.isBefore(existingEnd) && matchEnd.isAfter(existingStart)) {
          return true; // Conflict found
        }
      }
      
      return false; // No conflict
    } catch (e) {
      print('Error checking conflict: $e');
      return false; // Allow creation if check fails
    }
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStadium == null) {
      _showSnackbar('يرجى اختيار ملعب', Colors.red);
      return;
    }
    if (_maxPlayers == null) {
      _showSnackbar('يرجى اختيار حجم الملعب', Colors.red);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Check for conflicts
      final hasConflict = await _checkForConflict();
      if (hasConflict) {
        _showSnackbar('⚠️ يوجد مباراة أخرى في نفس الوقت والحجم', Colors.orange);
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
          'createdBy': 'test_admin',
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

      _showSnackbar(
        _isRecurring
            ? '✅ تم إنشاء $totalMatches مباريات أسبوعية'
            : '✅ تم إنشاء المباراة بنجاح',
        Colors.green,
      );
      _resetForm();
    } catch (e) {
      _showSnackbar('❌ خطأ: $e', Colors.red);
    }
    
    setState(() => _isLoading = false);
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

  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Stadium Selection
            _buildSectionHeader('اختر الملعب', Icons.stadium),
            const SizedBox(height: 12),
            
            _isLoadingStadiums
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _stadiums.isEmpty
                            ? const ListTile(
                                leading: Icon(Icons.info_outline, color: Colors.grey),
                                title: Text('لا توجد ملاعب'),
                                subtitle: Text('أضف ملعب من تبويب إدارة الملاعب'),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedStadiumId,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  border: InputBorder.none,
                                  hintText: 'اختر ملعب',
                                ),
                                items: _stadiums.map((stadium) {
                                  return DropdownMenuItem<String>(
                                    value: stadium['id'],
                                    child: Text(stadium['name'] ?? 'بدون اسم'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStadiumId = value;
                                    _selectedStadium = _stadiums.firstWhere(
                                      (s) => s['id'] == value,
                                      orElse: () => {},
                                    );
                                    _availableSizes = List<int>.from(
                                      _selectedStadium?['availableSizes'] ?? [10]
                                    );
                                    _maxPlayers = _availableSizes.isNotEmpty ? _availableSizes.first : null;
                                  });
                                },
                              ),
                      ),
                    ],
                  ),
            
            // Show selected stadium info
            if (_selectedStadium != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stadium image if available
                    if (_selectedStadium!['imageUrl'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _selectedStadium!['imageUrl'],
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedStadium!['address'] ?? 'لا يوجد عنوان',
                            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip(Icons.grass, _getSurfaceText(_selectedStadium!['surfaceType'])),
                        ..._availableSizes.map((size) => _buildChip(
                          Icons.people,
                          '${size ~/ 2}v${size ~/ 2}',
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Section: Match Details
            _buildSectionHeader('تفاصيل المباراة', Icons.sports_soccer),
            const SizedBox(height: 12),
            
            // Date & Time row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectTime,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Text(
                            '${_selectedTime.hour}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Price
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'السعر للاعب (د.ع)',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
            ),
            
            const SizedBox(height: 16),
            
            // Max Players dropdown
            DropdownButtonFormField<int>(
              value: _maxPlayers,
              decoration: InputDecoration(
                labelText: 'حجم الملعب',
                prefixIcon: const Icon(Icons.people),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              hint: Text(_selectedStadium == null ? 'اختر ملعب أولاً' : 'اختر الحجم'),
              items: _availableSizes.map((n) => DropdownMenuItem(
                value: n,
                child: Text('${n ~/ 2}v${n ~/ 2} ($n لاعب)'),
              )).toList(),
              onChanged: _selectedStadium == null ? null : (v) => setState(() => _maxPlayers = v),
            ),
            
            const SizedBox(height: 16),
            
            // Duration dropdown
            DropdownButtonFormField<int>(
              value: _durationMinutes,
              decoration: InputDecoration(
                labelText: 'مدة المباراة',
                prefixIcon: const Icon(Icons.timer),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [30, 45, 60, 90].map((m) => DropdownMenuItem(
                value: m,
                child: Text('$m دقيقة'),
              )).toList(),
              onChanged: (v) => setState(() => _durationMinutes = v!),
            ),
            
            const SizedBox(height: 16),

            // Recurring match toggle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: _isRecurring ? Colors.deepPurple : Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('مباراة متكررة أسبوعياً'),
                    subtitle: const Text('إنشاء نفس المباراة كل أسبوع'),
                    value: _isRecurring,
                    activeColor: Colors.deepPurple,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _isRecurring = v),
                  ),
                  if (_isRecurring) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.repeat, color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 8),
                        const Text('عدد الأسابيع:'),
                        const SizedBox(width: 12),
                        ...([2, 4, 6, 8].map((w) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text('$w'),
                            selected: _recurringWeeks == w,
                            selectedColor: Colors.deepPurple.withOpacity(0.2),
                            onSelected: (_) => setState(() => _recurringWeeks = w),
                          ),
                        ))),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'إنشاء المباراة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Upcoming matches list
            _buildSectionHeader('المباريات القادمة', Icons.list),
            const SizedBox(height: 12),
            _UpcomingMatchesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.deepPurple),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.deepPurple)),
        ],
      ),
    );
  }

  String _getSurfaceText(String? type) {
    switch (type) {
      case 'natural':
        return 'عشب طبيعي';
      case 'artificial':
        return 'عشب صناعي';
      case 'indoor':
        return 'داخلي';
      default:
        return 'غير محدد';
    }
  }
}

// ============================================
// UPCOMING MATCHES LIST WITH DELETE
// ============================================

class _UpcomingMatchesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'open')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('لا توجد مباريات قادمة', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        
        // Sort and filter client-side
        final now = DateTime.now();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateTime = (data['dateTime'] as Timestamp).toDate();
          return dateTime.isAfter(now);
        }).toList();
        
        docs.sort((a, b) {
          final aTime = ((a.data() as Map)['dateTime'] as Timestamp).toDate();
          final bTime = ((b.data() as Map)['dateTime'] as Timestamp).toDate();
          return aTime.compareTo(bTime);
        });
        
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('لا توجد مباريات قادمة', style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        
        return Column(
          children: docs.take(10).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dateTime = (data['dateTime'] as Timestamp).toDate();
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  child: Text(
                    '${data['maxPlayers'] ~/ 2}v${data['maxPlayers'] ~/ 2}',
                    style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
                  ),
                ),
                title: Text(data['stadiumName'] ?? 'ملعب'),
                subtitle: Text(
                  '${dateTime.day}/${dateTime.month} - ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(context, doc.id, data['stadiumName']),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String matchId, String? stadiumName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المباراة'),
        content: Text('هل تريد حذف المباراة في "$stadiumName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('matches').doc(matchId).delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ تم حذف المباراة'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ============================================
// MANAGE STADIUMS TAB
// ============================================

class _ManageStadiumsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add Stadium Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCreateStadiumDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('إضافة ملعب جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        
        // Stadiums List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stadiums')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stadium, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('لا توجد ملاعب', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('أضف ملعب جديد للبدء', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final sizes = List<int>.from(data['availableSizes'] ?? []);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stadium Image
                        if (data['imageUrl'] != null)
                          Image.network(
                            data['imageUrl'],
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 80,
                              color: Colors.grey[300],
                              child: const Center(child: Icon(Icons.image_not_supported)),
                            ),
                          )
                        else
                          Container(
                            height: 80,
                            color: Colors.deepPurple.withOpacity(0.1),
                            child: const Center(
                              child: Icon(Icons.stadium, size: 40, color: Colors.deepPurple),
                            ),
                          ),
                        
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['name'] ?? 'بدون اسم',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => _confirmDeleteStadium(context, doc.id, data['name']),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      data['address'] ?? '',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildMiniChip(_getSurfaceText(data['surfaceType'])),
                                  ...sizes.map((s) => _buildMiniChip('${s ~/ 2}v${s ~/ 2}')),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.deepPurple),
      ),
    );
  }

  String _getSurfaceText(String? type) {
    switch (type) {
      case 'natural':
        return 'طبيعي';
      case 'artificial':
        return 'صناعي';
      case 'indoor':
        return 'داخلي';
      default:
        return 'غير محدد';
    }
  }

  void _confirmDeleteStadium(BuildContext context, String stadiumId, String? name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملعب'),
        content: Text('هل تريد حذف ملعب "$name"?\nسيتم حذف جميع المباريات المرتبطة به.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Delete stadium (soft delete)
              await FirebaseFirestore.instance
                  .collection('stadiums')
                  .doc(stadiumId)
                  .update({'isActive': false});
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ تم حذف الملعب'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCreateStadiumDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateStadiumSheet(),
    );
  }
}

// ============================================
// CREATE STADIUM BOTTOM SHEET WITH IMAGE UPLOAD
// ============================================

class _CreateStadiumSheet extends StatefulWidget {
  const _CreateStadiumSheet();

  @override
  State<_CreateStadiumSheet> createState() => _CreateStadiumSheetState();
}

class _CreateStadiumSheetState extends State<_CreateStadiumSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationTextController = TextEditingController();
  final _googleMapsUrlController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _priceController = TextEditingController(text: '10000');
  
  String _surfaceType = 'artificial';
  Set<int> _selectedSizes = {10};
  
  bool _hasParking = false;
  bool _hasLighting = true;
  bool _hasBathroom = false;
  bool _hasWater = true;
  bool _hasShowers = false;
  
  // Image
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _locationTextController.dispose();
    _googleMapsUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;
    
    try {
      return await ImageUploadService.uploadImage(_selectedImage!);
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _createStadium() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى اختيار حجم واحد على الأقل'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
      }
      
      final sortedSizes = _selectedSizes.toList()..sort();
      
      await FirebaseFirestore.instance.collection('stadiums').add({
        'name': _nameController.text,
        'address': _addressController.text,
        'locationText': _locationTextController.text.isNotEmpty ? _locationTextController.text : null,
        'googleMapsUrl': _googleMapsUrlController.text.isNotEmpty ? _googleMapsUrlController.text : null,
        'surfaceType': _surfaceType,
        'availableSizes': sortedSizes,
        'pricePerHour': double.parse(_priceController.text),
        'hasParking': _hasParking,
        'hasLighting': _hasLighting,
        'hasBathroom': _hasBathroom,
        'hasWater': _hasWater,
        'hasShowers': _hasShowers,
        'rating': 0.0,
        'totalRatings': 0,
        'ownerId': 'test_admin',
        'isActive': true,
        'location': GeoPoint(
          double.parse(_latitudeController.text),
          double.parse(_longitudeController.text),
        ),
        'imageUrl': imageUrl,
        'images': imageUrl != null ? [imageUrl] : [],
        'createdAt': Timestamp.now(),
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ تم إضافة الملعب بنجاح'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('âŒ خطأ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'إضافة ملعب جديد',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: _selectedImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'اضغط لإضافة صورة',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Stadium Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الملعب',
                  hintText: 'مثال: ملعب الشعب الدولي',
                  prefixIcon: const Icon(Icons.stadium),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              
              // Address
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'العنوان',
                  hintText: 'مثال: بغداد - الشعب',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              
              // Location Text (detailed directions)
              TextFormField(
                controller: _locationTextController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'وصف الموقع (اختياري)',
                  hintText: 'مثال: قرب مول بغداد - الشارع الثاني - مقابل محطة الوقود',
                  prefixIcon: const Icon(Icons.near_me),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Google Maps URL
              TextFormField(
                controller: _googleMapsUrlController,
                decoration: InputDecoration(
                  labelText: 'رابط خرائط جوجل (اختياري)',
                  hintText: 'https://maps.app.goo.gl/...',
                  prefixIcon: const Icon(Icons.map),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Coordinates
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: 'خط العرض (Latitude)',
                        hintText: '33.3152',
                        prefixIcon: const Icon(Icons.my_location),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        final lat = double.tryParse(v);
                        if (lat == null || lat < -90 || lat > 90) return 'غير صحيح';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: 'خط الطول (Longitude)',
                        hintText: '44.3661',
                        prefixIcon: const Icon(Icons.my_location),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        final lng = double.tryParse(v);
                        if (lng == null || lng < -180 || lng > 180) return 'غير صحيح';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '💡 للحصول على الإحداثيات: افتح خرائط جوجل > اضغط مطولاً على الموقع > انسخ الأرقام',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              
              // Surface Type
              DropdownButtonFormField<String>(
                value: _surfaceType,
                decoration: InputDecoration(
                  labelText: 'نوع الأرضية',
                  prefixIcon: const Icon(Icons.grass),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'natural', child: Text('عشب طبيعي')),
                  DropdownMenuItem(value: 'artificial', child: Text('عشب صناعي')),
                  DropdownMenuItem(value: 'indoor', child: Text('ملعب داخلي')),
                ],
                onChanged: (v) => setState(() => _surfaceType = v!),
              ),
              const SizedBox(height: 16),
              
              // Available Sizes
              const Text('أحجام الملاعب المتوفرة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildSizeChip(10, '5v5'),
                  const SizedBox(width: 12),
                  _buildSizeChip(14, '7v7'),
                  const SizedBox(width: 12),
                  _buildSizeChip(22, '11v11'),
                ],
              ),
              const SizedBox(height: 16),
              
              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'السعر بالساعة (د.ع)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              
              // Amenities
              const Text('الخدمات المتوفرة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAmenityChip('موقف', Icons.local_parking, _hasParking, (v) => setState(() => _hasParking = v)),
                  _buildAmenityChip('إضاءة', Icons.lightbulb, _hasLighting, (v) => setState(() => _hasLighting = v)),
                  _buildAmenityChip('دورة مياه', Icons.wc, _hasBathroom, (v) => setState(() => _hasBathroom = v)),
                  _buildAmenityChip('ماء', Icons.water_drop, _hasWater, (v) => setState(() => _hasWater = v)),
                  _buildAmenityChip('دش', Icons.shower, _hasShowers, (v) => setState(() => _hasShowers = v)),
                ],
              ),
              const SizedBox(height: 24),
              
              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createStadium,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('إضافة الملعب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmenityChip(String label, IconData icon, bool selected, Function(bool) onChanged) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onChanged,
      selectedColor: Colors.deepPurple,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
    );
  }

  Widget _buildSizeChip(int size, String label) {
    final isSelected = _selectedSizes.contains(size);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedSizes.remove(size);
            } else {
              _selectedSizes.add(size);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.deepPurple : Colors.grey,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.people, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : null),
              ),
              Text(
                '$size لاعب',
                style: TextStyle(fontSize: 11, color: isSelected ? Colors.white70 : Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}