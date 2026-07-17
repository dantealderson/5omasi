import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:admin/services/image_upload_service.dart';
import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';
import 'package:admin/widgets/ui.dart';

/// Stadium catalog: grid of active stadiums, add via dialog, soft delete.
class StadiumsPage extends StatelessWidget {
  const StadiumsPage({super.key});

  Future<void> _softDelete(
      BuildContext context, String stadiumId, String? name) async {
    final ok = await confirmDanger(
      context,
      title: 'حذف الملعب',
      message:
          'هل تريد حذف ملعب "${name ?? ''}"؟ لن يظهر بعدها للاعبين ولا يمكن إنشاء مباريات عليه.',
    );
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('stadiums')
        .doc(stadiumId)
        .update({'isActive': false});
    if (context.mounted) showAppSnack(context, 'تم حذف الملعب');
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(phone ? 14 : 28, 28, phone ? 14 : 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: PageHeader(
                      title: 'الملاعب',
                      hint: 'كل ملعب هنا يظهر مباشرة في تطبيق اللاعبين',
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const AddStadiumDialog(),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة ملعب'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('stadiums')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.error_outline,
                      title: 'تعذر تحميل الملاعب',
                      hint: '${snapshot.error}',
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const EmptyState(
                      icon: Icons.stadium_outlined,
                      title: 'لا توجد ملاعب بعد',
                      hint: 'أضف أول ملعب ليظهر في تطبيق اللاعبين',
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          (constraints.maxWidth / 340).floor().clamp(1, 3);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 292,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _StadiumCard(
                            data: data,
                            onDelete: () =>
                                _softDelete(context, doc.id, data['name']),
                          );
                        },
                      );
                    },
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

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({required this.data, required this.onDelete});

  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sizes = List<int>.from(data['availableSizes'] ?? []);
    final price = (data['pricePerHour'] ?? 0).toDouble();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 128,
            width: double.infinity,
            child: data['imageUrl'] != null
                ? Image.network(
                    data['imageUrl'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _ImageFallback(p: p),
                  )
                : _ImageFallback(p: p),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['name'] ?? 'بدون اسم',
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: p.danger, size: 19),
                        tooltip: 'حذف الملعب',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: p.textLow),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['address'] ?? '',
                          style:
                              TextStyle(color: p.textLow, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      MiniChip(label: surfaceLabel(data['surfaceType'])),
                      ...sizes
                          .map((s) => MiniChip(label: '${s ~/ 2}v${s ~/ 2}')),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price.toStringAsFixed(0),
                        textDirection: TextDirection.ltr,
                        style: AppText.mono(size: 18, color: p.textHi),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          'د.ع / ساعة',
                          style:
                              TextStyle(color: p.textLow, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.p});

  final AppPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: p.emeraldSoft,
      child: Center(
        child: Icon(Icons.stadium_outlined, size: 36, color: p.emerald),
      ),
    );
  }
}

// ============================================================
// ADD STADIUM DIALOG
// ============================================================

class AddStadiumDialog extends StatefulWidget {
  const AddStadiumDialog({super.key});

  @override
  State<AddStadiumDialog> createState() => _AddStadiumDialogState();
}

class _AddStadiumDialogState extends State<AddStadiumDialog> {
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
  final Set<int> _selectedSizes = {10};

  bool _hasParking = false;
  bool _hasLighting = true;
  bool _hasBathroom = false;
  bool _hasWater = true;
  bool _hasShowers = false;

  Uint8List? _imageBytes;
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
        final bytes = await image.readAsBytes();
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _createStadium() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSizes.isEmpty) {
      showAppSnack(context, 'اختر حجماً واحداً على الأقل', danger: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await ImageUploadService.uploadBytes(_imageBytes!);
        if (imageUrl == null && mounted) {
          showAppSnack(context, 'فشل رفع الصورة — سيُحفظ الملعب بدون صورة',
              danger: true);
        }
      }

      final sortedSizes = _selectedSizes.toList()..sort();
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

      await FirebaseFirestore.instance.collection('stadiums').add({
        'name': _nameController.text,
        'address': _addressController.text,
        'locationText': _locationTextController.text.isNotEmpty
            ? _locationTextController.text
            : null,
        'googleMapsUrl': _googleMapsUrlController.text.isNotEmpty
            ? _googleMapsUrlController.text
            : null,
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
        'ownerId': adminUid,
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
        showAppSnack(context, 'تمت إضافة الملعب');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, 'خطأ: $e', danger: true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'إضافة ملعب جديد',
                      style:
                          AppText.kufi(size: 22, weight: 700, color: p.textHi),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image picker.
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: p.surfaceRaised,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _imageBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(_imageBytes!,
                                        fit: BoxFit.cover),
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: IconButton.filled(
                                        style: IconButton.styleFrom(
                                            backgroundColor: p.danger),
                                        icon: const Icon(Icons.close,
                                            size: 16, color: Colors.white),
                                        onPressed: () => setState(
                                            () => _imageBytes = null),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        size: 40, color: p.textLow),
                                    const SizedBox(height: 8),
                                    Text(
                                      'اضغط لإضافة صورة الملعب',
                                      style: TextStyle(color: p.textMid),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الملعب',
                          hintText: 'مثال: ملعب الشعب الدولي',
                          prefixIcon: Icon(Icons.stadium_outlined),
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'العنوان',
                          hintText: 'مثال: بغداد - الشعب',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _locationTextController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'وصف الموقع (اختياري)',
                          hintText:
                              'مثال: قرب مول بغداد - الشارع الثاني - مقابل محطة الوقود',
                          prefixIcon: Icon(Icons.near_me_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _googleMapsUrlController,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        decoration: const InputDecoration(
                          labelText: 'رابط خرائط جوجل (اختياري)',
                          hintText: 'https://maps.app.goo.gl/...',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: const InputDecoration(
                                labelText: 'خط العرض (Lat)',
                                hintText: '33.3152',
                                prefixIcon:
                                    Icon(Icons.my_location_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'مطلوب';
                                final lat = double.tryParse(v);
                                if (lat == null || lat < -90 || lat > 90) {
                                  return 'غير صحيح';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _longitudeController,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: const InputDecoration(
                                labelText: 'خط الطول (Lng)',
                                hintText: '44.3661',
                                prefixIcon:
                                    Icon(Icons.my_location_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'مطلوب';
                                final lng = double.tryParse(v);
                                if (lng == null ||
                                    lng < -180 ||
                                    lng > 180) {
                                  return 'غير صحيح';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'للحصول على الإحداثيات: افتح خرائط جوجل ثم اضغط مطولاً على الموقع وانسخ الأرقام',
                        style: TextStyle(fontSize: 12, color: p.textLow),
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: _surfaceType,
                        decoration: const InputDecoration(
                          labelText: 'نوع الأرضية',
                          prefixIcon: Icon(Icons.grass),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'natural', child: Text('عشب طبيعي')),
                          DropdownMenuItem(
                              value: 'artificial',
                              child: Text('عشب صناعي')),
                          DropdownMenuItem(
                              value: 'indoor', child: Text('ملعب داخلي')),
                        ],
                        onChanged: (v) => setState(() => _surfaceType = v!),
                      ),
                      const SizedBox(height: 18),

                      Text('أحجام الملاعب المتوفرة',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildSizeTile(10, '5v5'),
                          const SizedBox(width: 12),
                          _buildSizeTile(14, '7v7'),
                          const SizedBox(width: 12),
                          _buildSizeTile(22, '11v11'),
                        ],
                      ),
                      const SizedBox(height: 18),

                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر بالساعة (د.ع)',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'مطلوب';
                          if (double.tryParse(v) == null) {
                            return 'رقم غير صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      Text('الخدمات المتوفرة',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildAmenityChip('موقف', Icons.local_parking,
                              _hasParking,
                              (v) => setState(() => _hasParking = v)),
                          _buildAmenityChip('إضاءة', Icons.lightbulb_outline,
                              _hasLighting,
                              (v) => setState(() => _hasLighting = v)),
                          _buildAmenityChip('دورة مياه', Icons.wc,
                              _hasBathroom,
                              (v) => setState(() => _hasBathroom = v)),
                          _buildAmenityChip('ماء', Icons.water_drop_outlined,
                              _hasWater,
                              (v) => setState(() => _hasWater = v)),
                          _buildAmenityChip('دش', Icons.shower_outlined,
                              _hasShowers,
                              (v) => setState(() => _hasShowers = v)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createStadium,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: const Text('إضافة الملعب'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenityChip(
      String label, IconData icon, bool selected, Function(bool) onChanged) {
    final p = context.palette;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? p.emerald : p.textMid),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onChanged,
    );
  }

  Widget _buildSizeTile(int size, String label) {
    final p = context.palette;
    final isSelected = _selectedSizes.contains(size);
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedSizes.remove(size);
            } else {
              _selectedSizes.add(size);
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? p.emeraldSoft : Colors.transparent,
            border: Border.all(
              color: isSelected ? p.emerald : p.line,
              width: isSelected ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(Icons.people_outline,
                  color: isSelected ? p.emerald : p.textMid),
              const SizedBox(height: 4),
              Text(
                label,
                textDirection: TextDirection.ltr,
                style: AppText.mono(
                  size: 14,
                  color: isSelected ? p.emerald : p.textHi,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$size لاعب',
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? p.emerald : p.textLow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
