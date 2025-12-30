import 'package:ccr_booking/core/user_provider.dart';
import 'package:ccr_booking/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_loader.dart';
import '../widgets/custom_textfield.dart';

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
    final currentUser = userProvider.currentUser;

    if (currentUser != null) {
      _nameController.text = currentUser.name;
      _emailController.text = currentUser.email;
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

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile updated',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onSaved?.call();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }

    if (mounted) setState(() => _loading = false);
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
    // Detect dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Background adjusts to theme
      backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
      appBar: CustomAppBar(text: "Edit Personal Info", showPfp: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),
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
              labelText: "Password (leave empty to keep current)",
              textEditingController: _passwordController,
              isObsecure: true,
              keyboardType: TextInputType.visiblePassword,
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 32),
            CustomButton(
              // Button color swaps to primary in dark mode for better visibility
              color: WidgetStateProperty.all(
                isDark ? AppColors.primary : AppColors.secondary,
              ),
              onPressed: _loading ? null : _saveChanges,
              child: _loading
                  ? const CustomLoader(size: 24)
                  : Text(
                      'Save Changes',
                      style: AppFontStyle.textMedium().copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
