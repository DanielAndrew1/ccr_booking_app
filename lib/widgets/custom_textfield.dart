import '../core/imports.dart';

class CustomTextfield extends StatelessWidget {
  final TextEditingController textEditingController;
  final TextInputType keyboardType;
  final bool? isObsecure;
  final String? labelText;
  final String? hintText;
  final TextCapitalization textCapitalization;

  const CustomTextfield({
    super.key,
    required this.textEditingController,
    required this.keyboardType,
    this.isObsecure = false,
    this.labelText,
    this.hintText,
    required this.textCapitalization,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;

    // Set colors based on Dark Mode state
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color hintColor = isDark ? Colors.white60 : Colors.black54;
    final Color inactiveUnderlineColor = isDark ? Colors.white60 : Colors.black26;

    return TextField(
      controller: textEditingController,
      keyboardType: keyboardType,
      obscureText: isObsecure!,
      textCapitalization: textCapitalization,
      cursorColor: AppColors.primary,

      // This controls the input text color
      style: TextStyle(color: textColor),

      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,

        // This controls the hint text color
        hintStyle: TextStyle(color: hintColor),

        // Label color when not focused
        labelStyle: TextStyle(color: hintColor),

        // Active (Focused) underline
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),

        // Inactive (Enabled) underline
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: inactiveUnderlineColor, width: 2),
        ),

        // Label color (When focused/floating)
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
      ),
    );
  }
}
