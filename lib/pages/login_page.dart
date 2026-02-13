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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() {
    final loc = AppLocalizations.of(context);

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
            loc.tr("Login Successful!"),
            color: AppColors.green,
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CustomNavbar()),
          );
        })
        .catchError((e) {
          if (mounted) {
            CustomSnackBar.show(
              context,
              "${loc.tr("Login Failed")}: ${e.toString()}",
            );
          }
        })
        .whenComplete(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(AppImages.logo),
                      const SizedBox(height: 16),
                      Text(
                        loc.tr('Login'),
                        style: AppFontStyle.titleMedium().copyWith(
                          color: isDark ? Colors.white : AppColors.darkcolor,
                        ),
                      ),
                      const SizedBox(height: 14),
                      CustomTextfield(
                        textEditingController: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        isObsecure: false,
                        labelText: loc.tr('Email'),
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 12),
                      CustomTextfield(
                        textEditingController: _passwordController,
                        keyboardType: TextInputType.visiblePassword,
                        isObsecure: true,
                        labelText: loc.tr('Password'),
                        textCapitalization: TextCapitalization.none,
                      ),
                      const SizedBox(height: 36),
                      CustomButton(
                        onPressed: _login,
                        text: loc.tr('Login'),
                        imagePath: AppIcons.login,
                        color: WidgetStateProperty.all(AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.center,
                      //   children: [
                      //     Text(
                      //       loc.tr("Don't have an account? "),
                      //       style: TextStyle(
                      //         color:
                      //             isDark ? Colors.white70 : AppColors.darkcolor,
                      //         fontSize: 14,
                      //       ),
                      //     ),
                      //     TextButton(
                      //       onPressed: () {
                      //         Navigator.push(
                      //           context,
                      //           MaterialPageRoute(
                      //             builder: (context) => const RegisterPage(),
                      //           ),
                      //         );
                      //       },
                      //       style: TextButton.styleFrom(
                      //         padding: EdgeInsets.zero,
                      //         minimumSize: Size.zero,
                      //         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //       ),
                      //       child: Text(
                      //         loc.tr('Create Account'),
                      //         style: AppFontStyle.descriptionSemiBold(
                      //           AppColors.primary,
                      //         ).copyWith(fontSize: 14),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
