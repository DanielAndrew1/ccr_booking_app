// lib/pages/edit_info_page.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:path/path.dart' as p;
import 'package:image_cropper/image_cropper.dart';
import 'package:ccr_booking/core/imports.dart';

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

  String? _extractStoragePathFromPublicUrl(String? publicUrl) {
    if (publicUrl == null || publicUrl.isEmpty) return null;
    const marker = '/storage/v1/object/public/profile-pics/';
    final idx = publicUrl.indexOf(marker);
    if (idx == -1) return null;
    return Uri.decodeComponent(publicUrl.substring(idx + marker.length));
  }

  Future<CroppedFile?> _pickAndCropImage({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return null;

    return ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 92,
      uiSettings: [
        AndroidUiSettings(
          cropStyle: CropStyle.circle,
          toolbarTitle: 'Crop Image',
          toolbarColor: AppColors.darkbg,
          toolbarWidgetColor: Colors.white,
          hideBottomControls: false,
          lockAspectRatio: false,
          initAspectRatio: CropAspectRatioPreset.original,
        ),
        IOSUiSettings(
          cropStyle: CropStyle.circle,
          title: 'Crop Image',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          rotateButtonsHidden: false,
          rotateClockwiseButtonHidden: false,
        ),
      ],
    );
  }

  Future<void> _pickAndUploadAvatar({required ImageSource source}) async {
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

    CroppedFile? cropped;
    try {
      cropped = await _pickAndCropImage(source: source);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, "Image processing error: $e");
      }
      return;
    }
    if (cropped == null) return;

    setState(() => _uploadingImage = true);
    try {
      final oldPath = _extractStoragePathFromPublicUrl(_avatarUrl);
      final ext = p.extension(cropped.path).toLowerCase();
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}";
      final filePath = "$userId/$fileName";
      final file = File(cropped.path);
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

      if (oldPath != null && oldPath != filePath) {
        try {
          await Supabase.instance.client.storage.from('profile-pics').remove([
            oldPath,
          ]);
        } catch (_) {}
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

  Future<void> _removeAvatar() async {
    if (_uploadingImage) return;
    if (_avatarUrl == null || _avatarUrl!.isEmpty) return;

    setState(() => _uploadingImage = true);
    try {
      final oldPath = _extractStoragePathFromPublicUrl(_avatarUrl);
      if (oldPath != null) {
        try {
          await Supabase.instance.client.storage.from('profile-pics').remove([
            oldPath,
          ]);
        } catch (_) {}
      }

      await _authService.updateUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        avatarUrl: '',
      );

      await Provider.of<UserProvider>(context, listen: false).refreshUser();

      if (!mounted) return;
      setState(() => _avatarUrl = null);
      CustomSnackBar.show(
        context,
        "Profile photo removed",
        color: AppColors.green,
      );
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, "Failed to remove photo: $e");
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Widget _buildImageSourceOption({
    required bool isDark,
    Color? color,
    required String imgPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color ?? (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 2),
              IconHandler.buildIcon(
                size: 35,
                color: color ?? (isDark ? Colors.white : Colors.black),
                imagePath: imgPath,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: color ?? (isDark ? Colors.white : Colors.black),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAvatarOptionsSheet() async {
    if (_uploadingImage) return;
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = sheetContext.isDarkMode;
        final sheetColor = isDark ? AppColors.darkbg : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Container(
            width: double.infinity,
            color: sheetColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Select Image Source',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildImageSourceOption(
                        isDark: isDark,
                        imgPath: AppIcons.camera,
                        label: 'Camera',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndUploadAvatar(source: ImageSource.camera);
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildImageSourceOption(
                        isDark: isDark,
                        imgPath: AppIcons.photo,
                        label: 'Photos',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickAndUploadAvatar(source: ImageSource.gallery);
                        },
                      ),
                      if (hasAvatar) const SizedBox(width: 16),
                      if (hasAvatar)
                        _buildImageSourceOption(
                          isDark: isDark,
                          imgPath: AppIcons.trash,
                          label: 'Remove',
                          color: AppColors.red,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _removeAvatar();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveChanges() async {
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
    final isDark = context.isDarkMode;

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
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPfp(
                                dimentions: 140,
                                fontSize: 60,
                                nameOverride: _nameController.text,
                                imageUrlOverride: _avatarUrl,
                                onTapOverride: _showAvatarOptionsSheet,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -2,
                                child: GestureDetector(
                                  onTap: _showAvatarOptionsSheet,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.pfpGradient(isDark),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF2B2F37)
                                            : Colors.white,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                      onPressed: _saveChanges,
                      height: 45,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconHandler.buildIcon(
                            imagePath: AppIcons.save,
                            color: Colors.white,
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
