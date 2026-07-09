import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:khomasi/providers/auth_provider.dart';
import 'package:khomasi/providers/user_provider.dart';
import 'package:khomasi/pages/root_page.dart';
import 'package:khomasi/pages/referee_page.dart';
import 'package:khomasi/l10n/app_localizations.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  String selectedRole = 'player'; // 'player' or 'referee'

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
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

  Future<void> signUserUp() async {
    // Validate inputs
    if (nameController.text.trim().isEmpty) {
      _showError(tr(context, 'pleaseEnterName'));
      return;
    }
    if (emailController.text.trim().isEmpty) {
      _showError(tr(context, 'pleaseEnterEmail'));
      return;
    }
    if (phoneController.text.trim().isEmpty) {
      _showError(tr(context, 'pleaseEnterPhone'));
      return;
    }
    if (passwordController.text.isEmpty) {
      _showError(tr(context, 'pleaseEnterPassword'));
      return;
    }
    if (passwordController.text.length < 6) {
      _showError(tr(context, 'passwordMinLength'));
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showError(tr(context, 'passwordsDoNotMatch'));
      return;
    }

    setState(() => isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.signUpWithEmail(
      email: emailController.text.trim(),
      password: passwordController.text,
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      role: selectedRole,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (success && authProvider.userId != null) {
      // Initialize UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.init(authProvider.userId!);
      
      // Wait for user data to load
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Navigate based on selected role
      if (selectedRole == 'referee') {
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
      _showError(tr(context, authProvider.errorMessage ?? 'accountCreationFailed'));
      authProvider.clearError();
    }
  }

  Future<void> signUpWithGoogle() async {
    setState(() => isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();

    if (!mounted) return;

    setState(() => isLoading = false);

    if (success && authProvider.userId != null) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.init(authProvider.userId!);
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Google signup defaults to player
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootPage()),
        (route) => false,
      );
    } else {
      _showError(tr(context, authProvider.errorMessage ?? 'googleSignupFailed'));
      authProvider.clearError();
    }
  }

  void goToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF121212)]
                    : [Colors.deepPurple.shade50, Colors.grey[100]!],
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
                      SizedBox(height: screenHeight * 0.05),

                      // Animated icon
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(isDark ? 0.4 : 0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_add,
                            size: 56,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              Text(
                                tr(context, 'appName'),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tr(context, 'joinKhomasiFamily'),
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      // Role selector
                      SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 25),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F1F1F) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: isLoading ? null : () => setState(() => selectedRole = 'player'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedRole == 'player' 
                                          ? Colors.deepPurple 
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.sports_soccer,
                                          size: 20,
                                          color: selectedRole == 'player'
                                              ? Colors.white
                                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          tr(context, 'player'),
                                          style: TextStyle(
                                            color: selectedRole == 'player'
                                                ? Colors.white
                                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                            fontWeight: selectedRole == 'player' 
                                                ? FontWeight.bold 
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: isLoading ? null : () => setState(() => selectedRole = 'referee'),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedRole == 'referee' 
                                          ? Colors.deepPurple 
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.sports,
                                          size: 20,
                                          color: selectedRole == 'referee'
                                              ? Colors.white
                                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          tr(context, 'referee'),
                                          style: TextStyle(
                                            color: selectedRole == 'referee'
                                                ? Colors.white
                                                : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                            fontWeight: selectedRole == 'referee' 
                                                ? FontWeight.bold 
                                                : FontWeight.w500,
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
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Name field
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildTextField(
                          controller: nameController,
                          hintText: tr(context, 'fullName'),
                          prefixIcon: Icons.person_outline,
                          isDark: isDark,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Email field
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildTextField(
                          controller: emailController,
                          hintText: tr(context, 'email'),
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          isDark: isDark,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Phone field
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildTextField(
                          controller: phoneController,
                          hintText: tr(context, 'phoneNumber'),
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          isDark: isDark,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Password field
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildTextField(
                          controller: passwordController,
                          hintText: tr(context, 'password'),
                          prefixIcon: Icons.lock_outline,
                          obscureText: obscurePassword,
                          isDark: isDark,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.015),

                      // Confirm Password field
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildTextField(
                          controller: confirmPasswordController,
                          hintText: tr(context, 'confirmPassword'),
                          prefixIcon: Icons.lock_outline,
                          obscureText: obscureConfirmPassword,
                          isDark: isDark,
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                            onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.025),

                      // Sign Up Button
                      SlideTransition(
                        position: _slideAnimation,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isLoading ? 60 : double.infinity,
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 25),
                          child: isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.deepPurple,
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: signUserUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: Text(
                                    tr(context, 'createAccount'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Divider with text
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

                      // Google Sign Up
                      SlideTransition(
                        position: _slideAnimation,
                        child: GestureDetector(
                          onTap: isLoading ? null : signUpWithGoogle,
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
                                  tr(context, 'registerWithGoogle'),
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

                      // Already have account
                      SlideTransition(
                        position: _slideAnimation,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tr(context, 'haveAccount'),
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                            TextButton(
                              onPressed: isLoading ? null : goToLogin,
                              child: Text(
                                tr(context, 'signInHere'),
                                style: const TextStyle(
                                  color: Colors.deepPurple,
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
        color: isDark ? const Color(0xFF1F1F1F) : Colors.grey[100],
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
          fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.grey[100],
        ),
      ),
    );
  }
}