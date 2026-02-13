// ignore_for_file: deprecated_member_use, unused_field

import '../../core/imports.dart';

class AddClient extends StatefulWidget {
  final bool isRoot; // Logic to determine if this is a main tab in Navbar
  const AddClient({super.key, this.isRoot = false});

  @override
  State<AddClient> createState() => _AddClientState();
}

class _AddClientState extends State<AddClient> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;

  Future<void> _saveClient() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Please fill all fields',
          color: AppColors.red,
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.from('clients').insert({
        'name': name,
        'email': email,
        'phone': phone,
      });
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Client saved successfully',
          color: AppColors.green,
        );
      }
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          'Error saving client: $e',
          color: AppColors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          text: "Add Client",
          // Show PFP/Initials ONLY if this page is a root tab in Navbar
          showPfp: widget.isRoot,
        ),
        body: Stack(
          children: [
            const CustomBgSvg(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  CustomTextfield(
                    textEditingController: _nameController,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.name,
                    labelText: 'Name',
                  ),
                  const SizedBox(height: 16),
                  CustomTextfield(
                    textEditingController: _emailController,
                    textCapitalization: TextCapitalization.none,
                    keyboardType: TextInputType.emailAddress,
                    labelText: 'Email',
                  ),
                  const SizedBox(height: 16),
                  CustomTextfield(
                    textEditingController: _phoneController,
                    textCapitalization: TextCapitalization.none,
                    keyboardType: TextInputType.phone,
                    labelText: 'Phone Number',
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    onPressed: _saveClient,
                    color: WidgetStateProperty.all(AppColors.primary),
                    height: 50,
                    child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(AppIcons.save, color: Colors.white,),
                              SizedBox(width: 6),
                              Text(
                                "Save",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
