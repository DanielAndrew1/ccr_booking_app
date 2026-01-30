// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import '../core/imports.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _login() {
    setState(() => _isLoading = true);

    return _authService
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        )
        .then((_) {
          return Provider.of<UserProvider>(context, listen: false).loadUser();
        })
        .then((_) {
          if (!mounted) return;

          CustomSnackBar.show(
            context,
            "Login Successful!",
            color: AppColors.green,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomNavbar()),
          );
        })
        .catchError((e) {
          if (mounted) {
            CustomSnackBar.show(
              context,
              "Login Failed: ${e.toString()}",
              color: AppColors.red,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png'),
            const SizedBox(height: 16),
            Text(
              'Login',
              style: AppFontStyle.titleMedium().copyWith(
                color: isDark ? Colors.white : AppColors.darkcolor,
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 36),
            CustomButton(
              // Pass the external loading state to the button
              onPressed: _isLoading ? null : _login,
              text: 'Login', // Passing text here ensures the loader finds it
              imagePath: "assets/login.svg",
              color: WidgetStateProperty.all(AppColors.primary),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
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
                        builder: (context) => const RegisterPage(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Create Account',
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
    );
  }
}
