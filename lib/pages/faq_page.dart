import 'package:flutter/material.dart';
import 'package:khomasi/components/my_button.dart';
import 'package:khomasi/pages/contact_us_page.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class FAQPage extends StatefulWidget {
  const FAQPage({super.key});

  @override
  State<FAQPage> createState() => _FAQPageState();
}

class _FAQPageState extends State<FAQPage> {
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final TextEditingController _searchController = TextEditingController();

  // FAQ data structure - now uses tr() keys
  List<FAQCategory> _buildCategories(BuildContext context) {
    return [
      FAQCategory(
        name: tr(context, 'bookings'),
        icon: Icons.calendar_today,
        faqs: [
          FAQ(
            question: tr(context, 'faqBookStadium'),
            answer: tr(context, 'faqBookStadiumAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqCancelBooking'),
            answer: tr(context, 'faqCancelBookingAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqNotFull'),
            answer: tr(context, 'faqNotFullAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqConfirmBooking'),
            answer: tr(context, 'faqConfirmBookingAnswer'),
          ),
        ],
      ),
      FAQCategory(
        name: tr(context, 'payments'),
        icon: Icons.payment,
        faqs: [
          FAQ(
            question: tr(context, 'faqPaymentMethods'),
            answer: tr(context, 'faqPaymentMethodsAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqPaymentSecure'),
            answer: tr(context, 'faqPaymentSecureAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqPaymentDeducted'),
            answer: tr(context, 'faqPaymentDeductedAnswer'),
          ),
        ],
      ),
      FAQCategory(
        name: tr(context, 'stadiums'),
        icon: Icons.stadium,
        faqs: [
          FAQ(
            question: tr(context, 'faqFacilities'),
            answer: tr(context, 'faqFacilitiesAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqCovered'),
            answer: tr(context, 'faqCoveredAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqSizes'),
            answer: tr(context, 'faqSizesAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqVisit'),
            answer: tr(context, 'faqVisitAnswer'),
          ),
        ],
      ),
      FAQCategory(
        name: tr(context, 'accountSection'),
        icon: Icons.person,
        faqs: [
          FAQ(
            question: tr(context, 'faqCreateAccount'),
            answer: tr(context, 'faqCreateAccountAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqForgotPassword'),
            answer: tr(context, 'faqForgotPasswordAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqChangeInfo'),
            answer: tr(context, 'faqChangeInfoAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqDeleteAccount'),
            answer: tr(context, 'faqDeleteAccountAnswer'),
          ),
        ],
      ),
      FAQCategory(
        name: tr(context, 'matchesSection'),
        icon: Icons.sports_soccer,
        faqs: [
          FAQ(
            question: tr(context, 'faqJoinMatch'),
            answer: tr(context, 'faqJoinMatchAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqRules'),
            answer: tr(context, 'faqRulesAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqReferees'),
            answer: tr(context, 'faqRefereesAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqWhatToBring'),
            answer: tr(context, 'faqWhatToBringAnswer'),
          ),
        ],
      ),
      FAQCategory(
        name: tr(context, 'general'),
        icon: Icons.help_outline,
        faqs: [
          FAQ(
            question: tr(context, 'faqWhatIsKhomasi'),
            answer: tr(context, 'faqWhatIsKhomasiAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqCities'),
            answer: tr(context, 'faqCitiesAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqSupport'),
            answer: tr(context, 'faqSupportAnswer'),
          ),
          FAQ(
            question: tr(context, 'faqFree'),
            answer: tr(context, 'faqFreeAnswer'),
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FAQ> _getFilteredFAQs(List<FAQCategory> categories) {
    List<FAQ> allFAQs = [];

    for (var category in categories) {
      if (_selectedCategory == 'all' || _selectedCategory == category.name) {
        allFAQs.addAll(category.faqs);
      }
    }

    if (_searchQuery.isEmpty) {
      return allFAQs;
    }

    return allFAQs.where((faq) {
      return faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _buildCategories(context);
    final filteredFAQs = _getFilteredFAQs(categories);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(tr(context, 'faq')),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: tr(context, 'searchQuestion'),
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),

          // Category Filter
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip(
                  tr(context, 'all'),
                  Icons.all_inclusive,
                  'all',
                ),
                ...categories.map((category) => _buildCategoryChip(
                  category.name,
                  category.icon,
                  category.name,
                )),
              ],
            ),
          ),

          // FAQs List
          Expanded(
            child: filteredFAQs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr(context, 'noSearchResults'),
                          style: TextStyle(
                            fontSize: 18,
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600])),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(context, 'tryDifferentWords'),
                          style: TextStyle(
                            fontSize: 14,
                            color: (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredFAQs.length,
                    itemBuilder: (context, index) {
                      return _buildFAQCard(filteredFAQs[index]);
                    },
                  ),
          ),

          // Contact Support Button (Replaced with MyButton)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  tr(context, 'didntFindAnswer'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                // --- REPLACED ELEVATED BUTTON WITH MYBUTTON ---
                MyButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactUsPage()),
                    );
                  },
                  text: tr(context, 'contactSupport'),
                  icon: Icons.headset_mic,
                  backgroundColor: Colors.deepPurple,
                  textColor: Colors.white,
                  borderRadius: 12,
                  margin: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, String value) {
    final isSelected = _selectedCategory == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple
              : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurple
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(isDark ? 0.5 : 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.deepPurple[300] : Colors.deepPurple),
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQCard(FAQ faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline,
              color: Colors.deepPurple,
              size: 20,
            ),
          ),
          title: Text(
            faq.question,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                faq.answer,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FAQCategory {
  final String name;
  final IconData icon;
  final List<FAQ> faqs;

  FAQCategory({
    required this.name,
    required this.icon,
    required this.faqs,
  });
}

class FAQ {
  final String question;
  final String answer;

  FAQ({
    required this.question,
    required this.answer,
  });
}
