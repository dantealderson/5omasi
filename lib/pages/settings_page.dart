import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/auth_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/providers/theme_provider.dart';
import 'package:khomasi/providers/locale_provider.dart';
import 'package:khomasi/l10n/app_localizations.dart';
import 'package:khomasi/auth_wrapper.dart';
import 'package:khomasi/pages/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Referee-specific local settings
  String preferredMatchType = '5v5';
  int maxDistanceKm = 10;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isReferee = userProvider.isReferee;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(tr(context, 'settings')),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Account Settings Section
            _buildSectionHeader(tr(context, 'accountSettings'), isDark),
            _buildCard(
              isDark,
              Column(
                children: [
                  _buildListTile(
                    icon: Icons.lock_outline,
                    title: tr(context, 'changePassword'),
                    isDark: isDark,
                    onTap: () => _showChangePasswordDialog(),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    icon: Icons.email_outlined,
                    title: tr(context, 'changeEmail'),
                    isDark: isDark,
                    onTap: () => _showChangeEmailDialog(),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    icon: Icons.phone_outlined,
                    title: tr(context, 'changePhone'),
                    isDark: isDark,
                    onTap: () => _showChangePhoneDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notifications Section
            _buildSectionHeader(tr(context, 'notifications'), isDark),
            _buildCard(
              isDark,
              Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: tr(context, 'notifications'),
                    subtitle: isReferee
                        ? tr(context, 'notificationsSubReferee')
                        : tr(context, 'notificationsSubPlayer'),
                    value: userProvider.settings.notificationsEnabled,
                    isDark: isDark,
                    onChanged: (value) {
                      userProvider.updateSettings(notificationsEnabled: value);
                    },
                  ),
                  _buildDivider(isDark),
                  _buildSwitchTile(
                    icon: Icons.volume_up_outlined,
                    title: tr(context, 'sound'),
                    subtitle: tr(context, 'soundSubtitle'),
                    value: userProvider.settings.soundEnabled,
                    isDark: isDark,
                    onChanged: (value) {
                      userProvider.updateSettings(soundEnabled: value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // App Preferences Section
            _buildSectionHeader(tr(context, 'appPreferences'), isDark),
            _buildCard(
              isDark,
              Column(
                children: [
                  _buildDropdownTile(
                    icon: Icons.language,
                    title: tr(context, 'language'),
                    value: localeProvider.isArabic ? 'العربية' : 'English',
                    items: const ['العربية', 'English'],
                    isDark: isDark,
                    onChanged: (value) {
                      final newLocale = value == 'العربية' ? 'ar' : 'en';
                      localeProvider.setLocale(newLocale);
                      userProvider.updateSettings(language: newLocale);
                    },
                  ),
                  _buildDivider(isDark),
                  _buildSwitchTile(
                    icon: Icons.dark_mode_outlined,
                    title: tr(context, 'darkMode'),
                    subtitle: tr(context, 'darkModeSubtitle'),
                    value: themeProvider.isDarkMode,
                    isDark: isDark,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                  ),
                  _buildDivider(isDark),
                  _buildSwitchTile(
                    icon: Icons.location_on_outlined,
                    title: tr(context, 'locationLabel'),
                    subtitle: tr(context, 'locationSubtitle'),
                    value: userProvider.settings.locationEnabled,
                    isDark: isDark,
                    onChanged: (value) {
                      userProvider.updateSettings(locationEnabled: value);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Section
            _buildSectionHeader(tr(context, 'payment'), isDark),
            _buildCard(
              isDark,
              Column(
                children: [
                  _buildListTile(
                    icon: Icons.credit_card,
                    title: tr(context, 'paymentMethods'),
                    subtitle: tr(context, 'paymentMethodsSub'),
                    isDark: isDark,
                    onTap: () => _showPaymentMethodsSheet(),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    icon: Icons.receipt_long,
                    title: tr(context, 'paymentHistory'),
                    subtitle: tr(context, 'paymentHistorySub'),
                    isDark: isDark,
                    onTap: () => _showPaymentHistorySheet(),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    icon: Icons.account_balance_wallet,
                    title: tr(context, 'balance'),
                    subtitle: '0 ${tr(context, 'currency')}',
                    isDark: isDark,
                    onTap: () => _showWalletSheet(),
                  ),
                ],
              ),
            ),

            // ==========================================
            // PLAYER-SPECIFIC SETTINGS
            // ==========================================
            if (!isReferee) ...[
              const SizedBox(height: 20),
              _buildSectionHeader(tr(context, 'playerSettings'), isDark),
              _buildCard(
                isDark,
                Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.visibility,
                      title: tr(context, 'publicProfileLabel'),
                      subtitle: tr(context, 'publicProfileSub'),
                      value: userProvider.settings.showProfilePublicly,
                      isDark: isDark,
                      onChanged: (value) {
                        userProvider.updateSettings(showProfilePublicly: value);
                      },
                    ),
                  ],
                ),
              ),
            ],

            // ==========================================
            // REFEREE-SPECIFIC SETTINGS
            // ==========================================
            if (isReferee) ...[
              const SizedBox(height: 20),
              _buildSectionHeader(tr(context, 'refereeSettings'), isDark),
              _buildCard(
                isDark,
                Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.sports,
                      title: tr(context, 'availableForMatches'),
                      subtitle: tr(context, 'availableForMatchesSub'),
                      value: userProvider.refereeProfile?.availableForMatches ?? true,
                      isDark: isDark,
                      onChanged: (value) {
                        userProvider.updateRefereeProfile(availableForMatches: value);
                      },
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      icon: Icons.flash_on,
                      title: tr(context, 'instantBooking'),
                      subtitle: tr(context, 'instantBookingSub'),
                      value: userProvider.refereeProfile?.instantBooking ?? false,
                      isDark: isDark,
                      onChanged: (value) {
                        userProvider.updateRefereeProfile(instantBooking: value);
                      },
                    ),
                    _buildDivider(isDark),
                    _buildListTile(
                      icon: Icons.schedule,
                      title: tr(context, 'availabilitySchedule'),
                      isDark: isDark,
                      onTap: () => _showAvailabilitySchedule(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // About Section
            _buildSectionHeader(tr(context, 'aboutApp'), isDark),
            _buildCard(
              isDark,
              Column(
                children: [
                  _buildListTile(
                    icon: Icons.help_outline,
                    title: tr(context, 'faq'),
                    isDark: isDark,
                    onTap: () {},
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    icon: Icons.privacy_tip_outlined,
                    title: tr(context, 'privacyPolicy'),
                    isDark: isDark,
                    onTap: () {},
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    icon: Icons.article_outlined,
                    title: tr(context, 'termsAndConditions'),
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Danger Zone
            _buildSectionHeader(tr(context, 'dangerZone'), isDark, isRed: true),
            _buildCard(
              isDark,
              Column(
                children: [
                  _buildListTile(
                    icon: Icons.logout,
                    title: tr(context, 'logout'),
                    textColor: Colors.red,
                    isDark: isDark,
                    onTap: () => _showLogoutConfirmation(),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    icon: Icons.delete_forever,
                    title: tr(context, 'deleteAccount'),
                    textColor: Colors.red,
                    isDark: isDark,
                    onTap: () => _showDeleteAccountDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // UI BUILDER METHODS
  // ==========================================

  Widget _buildSectionHeader(String title, bool isDark, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isRed ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 56,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isDark,
    Color? textColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? Colors.deepPurple,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: textColor ?? (isDark ? Colors.white : Colors.black87),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            )
          : null,
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.deepPurple,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: (newValue) {
          HapticFeedback.lightImpact();
          onChanged(newValue);
        },
        activeColor: Colors.deepPurple,
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.deepPurple,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
        onChanged: onChanged,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // DIALOG METHODS
  // ==========================================

  void _showChangePasswordDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            tr(context, 'changePassword'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                tr(context, 'currentPassword'),
                isDark,
                controller: currentPasswordController,
                obscure: true,
              ),
              const SizedBox(height: 16),
              _buildDialogTextField(
                tr(context, 'newPassword'),
                isDark,
                controller: newPasswordController,
                obscure: true,
              ),
              const SizedBox(height: 16),
              _buildDialogTextField(
                tr(context, 'confirmPassword'),
                isDark,
                controller: confirmPasswordController,
                obscure: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(tr(context, 'cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text != confirmPasswordController.text) {
                        _showErrorSnackBar(tr(context, 'passwordsDoNotMatch'));
                        return;
                      }
                      if (newPasswordController.text.length < 6) {
                        _showErrorSnackBar(tr(context, 'passwordMinLength'));
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final success = await authProvider.updatePassword(
                        currentPassword: currentPasswordController.text,
                        newPassword: newPasswordController.text,
                      );

                      if (success) {
                        Navigator.pop(dialogContext);
                        _showSuccessSnackBar(tr(context, 'passwordChanged'));
                      } else {
                        setDialogState(() => isLoading = false);
                        _showErrorSnackBar(tr(context, authProvider.errorMessage ?? 'authDefaultError'));
                        authProvider.clearError();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(tr(context, 'save'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeEmailDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            tr(context, 'changeEmail'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                tr(context, 'newEmail'),
                isDark,
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildDialogTextField(
                tr(context, 'passwordToConfirm'),
                isDark,
                controller: passwordController,
                obscure: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(tr(context, 'cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.trim().isEmpty) {
                        _showErrorSnackBar(tr(context, 'pleaseEnterEmail'));
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final success = await authProvider.updateEmail(
                        newEmail: emailController.text.trim(),
                        password: passwordController.text,
                      );

                      if (success) {
                        Navigator.pop(dialogContext);
                        _showSuccessSnackBar(tr(context, 'emailChanged'));
                      } else {
                        setDialogState(() => isLoading = false);
                        _showErrorSnackBar(tr(context, authProvider.errorMessage ?? 'authDefaultError'));
                        authProvider.clearError();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(tr(context, 'save'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePhoneDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final phoneController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            tr(context, 'changePhone'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: _buildDialogTextField(
            tr(context, 'newPhone'),
            isDark,
            controller: phoneController,
            keyboardType: TextInputType.phone,
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(tr(context, 'cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (phoneController.text.trim().isEmpty) {
                        _showErrorSnackBar(tr(context, 'pleaseEnterPhone'));
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      final success = await userProvider.updateProfile(
                        phoneNumber: phoneController.text.trim(),
                      );

                      if (success) {
                        Navigator.pop(dialogContext);
                        _showSuccessSnackBar(tr(context, 'phoneChanged'));
                      } else {
                        setDialogState(() => isLoading = false);
                        _showErrorSnackBar(userProvider.errorMessage ?? tr(context, 'phoneChangeFailed'));
                        userProvider.clearError();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(tr(context, 'save'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            tr(context, 'logout'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            tr(context, 'logoutConfirm'),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(tr(context, 'cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setDialogState(() => isLoading = true);
                      
                      try {
                        final authProvider = Provider.of<AuthProvider>(this.context, listen: false);
                        final userProvider = Provider.of<UserProvider>(this.context, listen: false);
                        
                        // Clear user data
                        userProvider.clear();
                        
                        // Sign out from Firebase
                        await authProvider.signOut();
                        
                        // Close dialog and navigate to AuthWrapper (which will show login)
                        if (mounted) {
                          Navigator.of(this.context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const AuthWrapper()),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('${tr(this.context, 'logoutError')}: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(tr(context, 'exit'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                tr(context, 'deleteAccount'),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(context, 'deleteAccountWarning'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildDialogTextField(
                tr(context, 'passwordToConfirm'),
                isDark,
                controller: passwordController,
                obscure: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: Text(tr(context, 'cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        _showErrorSnackBar(tr(context, 'pleaseEnterPassword'));
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final authProvider = Provider.of<AuthProvider>(this.context, listen: false);
                      final success = await authProvider.deleteAccount(passwordController.text);

                      if (success) {
                        Navigator.pushAndRemoveUntil(
                          this.context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                          (route) => false,
                        );
                      } else {
                        setDialogState(() => isLoading = false);
                        _showErrorSnackBar(tr(context, authProvider.errorMessage ?? 'authDefaultError'));
                        authProvider.clearError();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(tr(context, 'delete'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvailabilitySchedule() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final days = [
      tr(context, 'saturday'), tr(context, 'sunday'), tr(context, 'monday'),
      tr(context, 'tuesday'), tr(context, 'wednesday'), tr(context, 'thursday'),
      tr(context, 'friday'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr(context, 'availabilitySchedule'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: days.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.calendar_today, color: Colors.deepPurple),
                    title: Text(
                      days[index],
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    subtitle: Text(
                      '6:00 ${tr(context, 'pm')} - 11:00 ${tr(context, 'pm')}',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    trailing: CupertinoSwitch(
                      value: true,
                      onChanged: (value) {},
                      activeColor: Colors.deepPurple,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAYMENT METHODS
  // ==========================================

  void _showPaymentMethodsSheet() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr(context, 'paymentMethods'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card_off,
                      size: 64,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(context, 'noPaymentMethods'),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showComingSoonSnackBar();
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(tr(context, 'addCard'), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentHistorySheet() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr(context, 'paymentHistory'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(context, 'noPaymentHistory'),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalletSheet() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                tr(context, 'wallet'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    tr(context, 'currentBalance'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '0 ${tr(context, 'currency')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showComingSoonSnackBar();
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(tr(context, 'topUpBalance'), style: const TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'comingSoon'), textAlign: TextAlign.center),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Widget _buildDialogTextField(
    String label,
    bool isDark, {
    TextEditingController? controller,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}