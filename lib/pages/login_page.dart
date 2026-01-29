// ignore_for_file: use_build_context_synchronously

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
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUser();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png'),
            const SizedBox(height: 16),
            Text(
              'Login',
              style: AppFontStyle.titleMedium().copyWith(
                // Ensure text is visible in dark mode
                color: isDark ? Colors.white : AppColors.darkcolor,
              ),
            ),
            const SizedBox(height: 24),
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
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CustomLoader(size: 24,)
                  : const Text('Login', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.darkcolor,
                  ).copyWith(fontSize: 14),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegisterPage()),
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
