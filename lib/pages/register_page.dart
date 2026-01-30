// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import '../core/imports.dart';

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

  bool _isLoading = false;

  // Fixed the non-nullable error by returning the Future chain directly
  Future<void> _register() {
    setState(() => _isLoading = true);

    return _authService
        .register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        )
        .then((_) {
          if (!mounted) return;

          CustomSnackBar.show(
            context,
            "Account Created Successfully!",
            color: AppColors.green,
          );

          // Using the same navigation style as login
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        })
        .catchError((e) {
          if (mounted) {
            CustomSnackBar.show(
              context,
              "Registration Failed: ${e.toString()}",
            );
          }
        })
        .whenComplete(() {
          if (mounted) setState(() => _isLoading = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png'),
                const SizedBox(height: 16),
                Text(
                  'Create Account',
                  style: AppFontStyle.titleMedium().copyWith(
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
                  // Pass null when loading to let the button handle the loader UI
                  onPressed: _isLoading ? null : _register,
                  text: 'Create Account',
                  color: WidgetStateProperty.all(AppColors.primary),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account? ",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.darkcolor,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
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
