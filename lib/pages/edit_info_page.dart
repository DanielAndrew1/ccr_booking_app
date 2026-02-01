// lib/pages/edit_info_page.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import '../core/imports.dart';

class EditInfoPage extends StatefulWidget {
  final VoidCallback? onSaved;
  const EditInfoPage({super.key, this.onSaved});

  @override
  State<EditInfoPage> createState() => _EditInfoPageState();
}

class _EditInfoPageState extends State<EditInfoPage> {
  final _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser != null) {
      _nameController.text = userProvider.currentUser!.name;
      _emailController.text = userProvider.currentUser!.email;
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _loading = true);
    try {
      await _authService.updateUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
      );

      // Refresh the user data in the provider
      await Provider.of<UserProvider>(context, listen: false).refreshUser();

      if (mounted) {
        CustomSnackBar.show(context, "Profile Updated", color: AppColors.green);

        // EXECUTION FIX:
        // We only trigger the onSaved callback.
        // In your ProfilePage, the onSaved callback already handles the Navigator.pop.
        // If we pop here AND there, it pops twice, leading to a black screen.
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, "Update failed: $e", color: AppColors.red);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      // This ensures the background color matches the theme under the SVG
      color: isDark ? AppColors.darkbg : AppColors.lightcolor,
      child: Stack(
        children: [
          // The background SVG pinned to the top/fill
          const CustomBgSvg(),
          Scaffold(
            // Make Scaffold transparent so the Stack background and SVG show through
            backgroundColor: Colors.transparent,
            appBar: const CustomAppBar(
              text: "Edit Personal Info",
              showPfp: false,
            ),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // REAL-TIME UPDATE HERO
                  ValueListenableBuilder(
                    valueListenable: _nameController,
                    builder: (context, value, child) {
                      return Hero(
                        tag: 'profile_image',
                        child: Material(
                          type: MaterialType.transparency,
                          child: CustomPfp(
                            dimentions: 120,
                            fontSize: 50,
                            nameOverride: _nameController.text,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  CustomTextfield(
                    labelText: "Name",
                    textEditingController: _nameController,
                    isObsecure: false,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  CustomTextfield(
                    labelText: "Email",
                    textEditingController: _emailController,
                    isObsecure: false,
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 16),
                  CustomTextfield(
                    labelText: "Password (Leave empty to keep current)",
                    textEditingController: _passwordController,
                    isObsecure: true,
                    keyboardType: TextInputType.visiblePassword,
                    textCapitalization: TextCapitalization.none,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      color: WidgetStateProperty.all(AppColors.primary),
                      onPressed: _loading ? null : _saveChanges,
                      height: 45,
                      child: _loading
                          ? CustomLoader(size: 24, color: AppColors.secondary)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  AppIcons.save,
                                  color: Colors.white,
                                  width: 22,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Save Changes',
                                  style: AppFontStyle.textMedium().copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
