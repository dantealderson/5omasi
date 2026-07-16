import 'package:flutter/material.dart';
import 'package:khomasi/theme/app_colors.dart';
import 'package:khomasi/theme/app_text.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/auth_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/pages/signup_page.dart';
import 'package:khomasi/pages/root_page.dart';
import 'package:khomasi/pages/referee_page.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.clearSnackBars();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> signUserIn() async {
    // Validate inputs
    if (emailController.text.trim().isEmpty) {
      _showError(tr(context, 'pleaseEnterEmail'));
      return;
    }
    if (passwordController.text.isEmpty) {
      _showError(tr(context, 'pleaseEnterPassword'));
      return;
    }

    setState(() => isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    bool success = false;
    try {
      success = await authProvider.signInWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } catch (e) {
      success = false;
    }

    if (!mounted) return;
    setState(() => isLoading = false);

    if (success && authProvider.userId != null) {
      // Initialize UserProvider and wait for user data
      userProvider.init(authProvider.userId!);
      
      // Wait a moment for user data to load
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Navigate based on role
      if (userProvider.isReferee) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RefereePage()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootPage()),
          (route) => false,
        );
      }
    } else {
      // Show error dialog
      _showErrorDialog(tr(context, authProvider.errorMessage ?? 'loginFailed'));
      authProvider.clearError();
    }
  }
  
  void _showErrorDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              tr(context, 'error'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(tr(context, 'ok'), style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message, String? subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('حسناً', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    final success = await authProvider.signInWithGoogle();

    if (!mounted) return;

    if (success && authProvider.userId != null) {
      userProvider.init(authProvider.userId!);
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      setState(() => isLoading = false);
      
      // Google sign-in defaults to player
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootPage()),
        (route) => false,
      );
    } else {
      setState(() => isLoading = false);
      _showError(tr(context, authProvider.errorMessage ?? 'googleLoginFailed'));
      authProvider.clearError();
    }
  }

  Future<void> forgotPassword() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resetEmailController = TextEditingController(text: emailController.text.trim());
    
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.dSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr(context, 'resetPassword'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'resetPasswordDesc'),
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr(context, 'email'),
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.brand),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brand, width: 2),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              tr(context, 'cancel'),
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.pop(context, email);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(tr(context, 'send'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (email == null || email.isEmpty) return;

    setState(() => isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    bool success = false;
    try {
      success = await authProvider.sendPasswordResetEmail(email);
    } catch (e) {
      success = false;
    }

    if (!mounted) return;
    setState(() => isLoading = false);

    if (success) {
      // Show success dialog using helper
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppColors.dSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                tr(context, 'sent'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'resetLinkSent'),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'checkEmail'),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(tr(context, 'ok'), style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    } else {
      _showErrorDialog(tr(context, authProvider.errorMessage ?? 'resetLinkFailed'));
      authProvider.clearError();
    }
  }

  void goToSignUp() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SignUpPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          // Floodlit night backdrop
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF10201C), p.background]
                      : [AppColors.brandTint, p.background],
                ),
              ),
            ),
          ),
          // Floodlight glow behind the wordmark
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 340,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.9,
                    colors: [
                      p.emerald.withOpacity(isDark ? 0.22 : 0.16),
                      p.background.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.08),

                      // Logo
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          height: 106,
                          width: 106,
                          decoration: BoxDecoration(
                            color: p.emerald,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: p.gold.withOpacity(0.6), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: p.emerald.withOpacity(0.4),
                                blurRadius: 34,
                                spreadRadius: -4,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.sports_soccer,
                            size: 54,
                            color: AppColors.onBrand,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      // Wordmark — Reem Kufi
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          tr(context, 'appName'),
                          style: AppText.kufi(
                            size: 44,
                            weight: 700,
                            color: p.textHi,
                            letterSpacing: 1,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.01),

                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          tr(context, 'welcomeBack'),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.05),

                      // Email field
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildTextField(
                          controller: emailController,
                          hintText: tr(context, 'email'),
                          prefixIcon: Icons.email_outlined,
                          isDark: isDark,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Password field
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildTextField(
                          controller: passwordController,
                          hintText: tr(context, 'password'),
                          prefixIcon: Icons.lock_outline,
                          isDark: isDark,
                          obscureText: obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() => obscurePassword = !obscurePassword);
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Forgot password
                      SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isLoading ? null : forgotPassword,
                                child: Text(
                                  tr(context, 'forgotPassword'),
                                  style: TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Login button
                      SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          width: double.infinity,
                          height: 55,
                          margin: const EdgeInsets.symmetric(horizontal: 25),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : signUserIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.emerald,
                              foregroundColor: p.onEmerald,
                              disabledBackgroundColor: p.emerald,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: p.onEmerald,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    tr(context, 'login'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Divider
                      SlideTransition(
                        position: _slideAnimation,
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: isDark ? Colors.grey[700] : Colors.grey[400],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: Text(
                                tr(context, 'or'),
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: isDark ? Colors.grey[700] : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Google Sign In
                      SlideTransition(
                        position: _slideAnimation,
                        child: GestureDetector(
                          onTap: isLoading ? null : signInWithGoogle,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(horizontal: 25),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'images/google_logo.jpg',
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.g_mobiledata, size: 24);
                                  },
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  tr(context, 'loginWithGoogle'),
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Sign up row
                      SlideTransition(
                        position: _slideAnimation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr(context, 'notKhomasiFamily'),
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                            TextButton(
                              onPressed: isLoading ? null : goToSignUp,
                              child: Text(
                                tr(context, 'createAccountHere'),
                                style: TextStyle(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required bool isDark,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: !isLoading,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          suffixIcon: suffixIcon,
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
          filled: true,
          fillColor: isDark ? AppColors.dSurface : Colors.grey[100],
        ),
      ),
    );
  }
}