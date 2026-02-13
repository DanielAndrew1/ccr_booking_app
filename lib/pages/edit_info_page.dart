// lib/pages/edit_info_page.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:path/path.dart' as p;
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
  bool _uploadingImage = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser != null) {
      _nameController.text = userProvider.currentUser!.name;
      _emailController.text = userProvider.currentUser!.email;
      _avatarUrl = userProvider.currentUser!.avatarUrl;
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingImage) return;
    String? userId = Supabase.instance.client.auth.currentUser?.id;
    userId ??= Provider.of<UserProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    if (userId == null) {
      CustomSnackBar.show(context, "No user ID");
      return;
    }

    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, "Image picker error: $e");
      }
      return;
    }
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final ext = p.extension(picked.name).toLowerCase();
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}";
      final filePath = "$userId/$fileName";
      final file = File(picked.path);
      try {
        await Supabase.instance.client.storage
            .from('profile-pics')
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                upsert: true,
                cacheControl: '3600',
              ),
            );
      } catch (e) {
        if (mounted) {
          CustomSnackBar.show(context, "Upload failed: $e");
        }
        return;
      }

      final publicUrl = Supabase.instance.client.storage
          .from('profile-pics')
          .getPublicUrl(filePath);
      if (publicUrl.isEmpty) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            "Upload failed: could not get image URL",
          );
        }
        return;
      }

      await _authService.updateUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        avatarUrl: publicUrl,
      );

      await Provider.of<UserProvider>(context, listen: false).refreshUser();

      if (!mounted) return;
      setState(() => _avatarUrl = publicUrl);
      CustomSnackBar.show(
        context,
        "Profile photo updated",
        color: AppColors.green,
      );
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, "Upload failed: $e");
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
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
        CustomSnackBar.show(context, "Update failed: $e");
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
                            imageUrlOverride: _avatarUrl,
                            onTapOverride: _pickAndUploadAvatar,
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
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomLoader(
                                  size: 24,
                                  color: AppColors.secondary,
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
                            )
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
