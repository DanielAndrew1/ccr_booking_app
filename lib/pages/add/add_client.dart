import '../../core/imports.dart';

class AddClient extends StatefulWidget {
  const AddClient({super.key});

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Client saved successfully')),
        );
      }

      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving client: $e')));
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
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkbg : AppColors.lightcolor,
        extendBodyBehindAppBar: true,
        appBar: const CustomAppBar(text: "Add a Client", showPfp: false),
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
                    keyboardType: TextInputType.name,
                    isObsecure: false,
                    textCapitalization: TextCapitalization.words,
                    labelText: 'Name',
                  ),
                  const SizedBox(height: 16),
                  CustomTextfield(
                    textEditingController: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    isObsecure: false,
                    textCapitalization: TextCapitalization.none,
                    labelText: 'Email',
                  ),
                  const SizedBox(height: 16),
                  CustomTextfield(
                    textEditingController: _phoneController,
                    keyboardType: TextInputType.phone,
                    isObsecure: false,
                    textCapitalization: TextCapitalization.none,
                    labelText: 'Phone Number',
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    onPressed: _loading ? null : _saveClient,
                    text: _loading ? "Saving..." : "Save",
                    color: WidgetStateProperty.all(AppColors.primary),
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
