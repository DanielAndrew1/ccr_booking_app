import 'package:flutter/material.dart';
import 'package:ccr_booking/core/app_theme.dart';

class CustomTextfield extends StatelessWidget {
  final TextEditingController textEditingController;
  final TextInputType keyboardType;
  final bool isObsecure;
  final String? labelText;
  final String? hintText;
  final TextCapitalization textCapitalization;

  const CustomTextfield({
    super.key,
    required this.textEditingController,
    required this.keyboardType,
    required this.isObsecure,
    this.labelText,
    this.hintText,
    required this.textCapitalization,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textEditingController,
      keyboardType: keyboardType,
      obscureText: isObsecure,
      textCapitalization: textCapitalization,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,

        // Active underline
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),

        // Label color (active)
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
      ),
    );
  }
}
