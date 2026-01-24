import 'package:ccr_booking/core/app_theme.dart';
import 'package:ccr_booking/core/theme.dart';
import 'package:ccr_booking/pages/login_page.dart';
import 'package:ccr_booking/widgets/custom_button.dart';
import 'package:ccr_booking/widgets/custom_loader.dart';
import 'package:ccr_booking/widgets/custom_textfield.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;

  Future<void> _register() async {
    setState(() => _loading = true);

    try {
      await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect dark mode
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      // Toggle background color
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          // Added to prevent overflow when keyboard appears
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png'),

                const SizedBox(height: 16),
                Text(
                  'Create Account',
                  style: AppFontStyle.titleMedium().copyWith(
                    // Toggle title color
                    color: isDark ? Colors.white : AppColors.darkcolor,
                  ),
                ),
                const SizedBox(height: 24),

                CustomTextfield(
                  textEditingController: _nameController,
                  keyboardType: TextInputType.text,
                  isObsecure: false,
                  labelText: 'Name',
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 12),

                CustomTextfield(
                  textEditingController: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  isObsecure: false,
                  labelText: 'Email',
                  textCapitalization: TextCapitalization.none,
                ),

                const SizedBox(height: 12),

                CustomTextfield(
                  textEditingController: _passwordController,
                  keyboardType: TextInputType.visiblePassword,
                  isObsecure: true,
                  labelText: 'Password',
                  textCapitalization: TextCapitalization.none,
                ),

                const SizedBox(height: 32),

                CustomButton(
                  onPressed: _loading ? null : _register,
                  color: WidgetStateProperty.all(AppColors.primary),
                  child: _loading
                      ? const CustomLoader(size: 24, color: AppColors.secondary)
                      : const Text(
                          'Create Account',
                          style: TextStyle(color: Colors.white),
                        ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.darkcolor,
                      ).copyWith(fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginPage(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Login',
                        style: AppFontStyle.descriptionSemiBold(
                          AppColors.primary,
                        ).copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
