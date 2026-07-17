// Visual preview harness (not a real test): renders the redesigned Midnight
// Club components with the bundled fonts in Arabic RTL, and writes PNGs via
// `flutter test --update-goldens test/design_preview_test.dart` so the design
// can be eyeballed without a device.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:khomasi/theme/app_theme.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';
import 'package:khomasi/providers/locale_provider.dart';
import 'package:khomasi/components/match_card.dart';
import 'package:khomasi/components/my_button.dart';
import 'package:khomasi/components/my_textfield.dart';
import 'package:khomasi/components/score_board.dart';

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final a in assets) {
    loader.addFont(rootBundle.load(a));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _loadFont('ReemKufi', ['assets/fonts/ReemKufi-VariableFont_wght.ttf']);
  await _loadFont('PlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
  await _loadFont('PlexMono', [
    'assets/fonts/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono-Medium.ttf',
    'assets/fonts/IBMPlexMono-SemiBold.ttf',
    'assets/fonts/IBMPlexMono-Bold.ttf',
  ]);
}

Widget _wordmark(BuildContext context) {
  final p = context.palette;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 28),
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topCenter,
        radius: 1.1,
        colors: [p.emerald.withOpacity(0.22), p.background.withOpacity(0)],
      ),
    ),
    child: Column(
      children: [
        Container(
          height: 96,
          width: 96,
          decoration: BoxDecoration(
            color: p.emerald,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: p.gold.withOpacity(0.6), width: 1.5),
          ),
          child: Icon(Icons.sports_soccer, size: 50, color: AppColors.onBrand),
        ),
        const SizedBox(height: 18),
        Text('خماسي',
            style: AppText.kufi(size: 44, weight: 700, color: p.textHi)),
        const SizedBox(height: 6),
        Text('مرحباً بك مجدداً',
            style: TextStyle(color: p.textMid, fontSize: 16)),
      ],
    ),
  );
}

/// Faithful proxy of the redesigned referee header (same tokens/widgets).
Widget _refereeHeader(BuildContext context) {
  final p = context.palette;
  Widget tile(String label, String value, IconData icon, {Color? accent}) {
    return Expanded(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: accent ?? p.textLow),
        const SizedBox(height: 7),
        Text(value,
            style: AppText.mono(
                size: 20, color: accent ?? p.textHi, weight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: p.textMid, fontSize: 11)),
      ]),
    );
  }

  Widget div() => Container(width: 1, color: p.line);

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.gold, width: 2)),
          child: CircleAvatar(
              radius: 26,
              backgroundColor: p.surfaceRaised,
              child: Icon(Icons.sports, color: p.gold, size: 26)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.sports, size: 13, color: p.gold),
              const SizedBox(width: 5),
              Text('حكم',
                  style: TextStyle(
                      color: p.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
            ]),
            const SizedBox(height: 3),
            Text('علي الحكم',
                style: AppText.kufi(size: 24, weight: 700, color: p.textHi)),
          ]),
        ),
        Icon(Icons.settings_outlined, color: p.textMid),
      ]),
      const SizedBox(height: 18),
      Container(
        decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: IntrinsicHeight(
          child: Row(children: [
            tile('اليوم', '2', Icons.today_outlined),
            div(),
            tile('هذا الأسبوع', '9', Icons.date_range_outlined),
            div(),
            tile('الإجمالي', '34', Icons.workspace_premium_outlined),
            div(),
            tile('تقييم', '4.8', Icons.star_rounded, accent: p.gold),
          ]),
        ),
      ),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('المباريات المتاحة',
            style: AppText.kufi(size: 20, weight: 700, color: p.textHi)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: p.emeraldSoft,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: p.emerald.withOpacity(0.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('5',
                style: AppText.mono(
                    size: 13, color: p.emerald, weight: FontWeight.w700)),
            const SizedBox(width: 4),
            Text('مباراة',
                style: TextStyle(
                    color: p.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    ]),
  );
}

Widget _gallery() {
  return Builder(builder: (context) {
    final p = context.palette;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _refereeHeader(context),
          const SizedBox(height: 12),
          const MatchCard(
            index: 0,
            venue: 'ملعب المجمع',
            date: 'اليوم',
            time: '23:00 - 00:00',
            price: 5000,
            currentPlayers: 3,
            maxPlayers: 10,
            surfaceType: 'عشب صناعي',
            distance: 0.4,
          ),
          const MatchCard(
            index: 1,
            venue: 'ملعب نديم',
            date: 'غداً',
            time: '20:00 - 21:00',
            price: 7000,
            currentPlayers: 10,
            maxPlayers: 10,
            surfaceType: 'عشب طبيعي',
            distance: 2.6,
            isBooked: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: MyTextfield(
              controller: TextEditingController(text: ''),
              hintText: 'ابحث عن ملعب أو منطقة...',
              obscureText: false,
            ),
          ),
          const SizedBox(height: 8),
          MyButton(onTap: () {}, text: 'احجز الآن', width: double.infinity),
          const SizedBox(height: 12),
          MyButton(
            onTap: () {},
            text: 'إلغاء الحجز',
            width: double.infinity,
            backgroundColor: p.danger,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  });
}

Widget _app(ThemeData theme) {
  return ChangeNotifierProvider<LocaleProvider>(
    create: (_) => LocaleProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: _gallery(),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  testWidgets('preview dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1560));
    await tester.pumpWidget(_app(AppTheme.dark()));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_dark.png'),
    );
  });

  testWidgets('preview light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1560));
    await tester.pumpWidget(_app(AppTheme.light()));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/preview_light.png'),
    );
  });
}
