import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:site_lapse/core/app_theme.dart';

class ProjectCommercialFields extends StatelessWidget {
  const ProjectCommercialFields({
    super.key,
    required this.isDark,
    required this.priceController,
    required this.installmentController,
    required this.downPaymentController,
    required this.paymentPlanType,
    required this.paymentFrequency,
    required this.paymentInterval,
    required this.contractImage,
    required this.onPaymentPlanChanged,
    required this.onPaymentFrequencyChanged,
    required this.onPaymentIntervalChanged,
    required this.onContractChanged,
    this.onDownPaymentChanged,
    this.showPayment = true,
    this.showPrice = true,
    this.showContract = true,
    this.allowAtEnd = true,
  });

  final bool isDark;
  final TextEditingController priceController;
  final TextEditingController installmentController;
  final TextEditingController downPaymentController;
  final String? paymentPlanType;
  final String paymentFrequency;
  final int paymentInterval;
  final File? contractImage;
  final ValueChanged<String> onPaymentPlanChanged;
  final ValueChanged<String> onPaymentFrequencyChanged;
  final ValueChanged<int> onPaymentIntervalChanged;
  final ValueChanged<File?> onContractChanged;
  final ValueChanged<String>? onDownPaymentChanged;
  final bool showPayment;
  final bool showPrice;
  final bool showContract;
  final bool allowAtEnd;

  Future<void> _pickContract(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image != null) onContractChanged(File(image.path));
  }

  Future<void> _pickContractFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path != null) onContractChanged(File(path));
  }

  bool get _contractIsImage {
    final path = contractImage?.path.toLowerCase() ?? '';
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.heic');
  }

  @override
  Widget build(BuildContext context) {
    final foreground = isDark ? Colors.white : Colors.black;
    final muted = isDark ? Colors.white70 : Colors.black54;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPayment && showPrice)
          Text(
            'Project price',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        if (showPayment && showPrice)
          TextField(
            controller: priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [CurrencyAmountFormatter()],
            cursorColor: AppColors.primary,
            style: TextStyle(color: foreground),
            decoration: const InputDecoration(
              labelText: 'Total project price',
              suffixText: 'EGP',
            ),
          ),
        if (showPayment && showPrice) const SizedBox(height: 24),
        if (showPayment)
          Text(
            'Payment plan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        if (showPayment) const SizedBox(height: 8),
        if (showPayment)
          _PaymentPlanSelector(
            isDark: isDark,
            selectedValue: paymentPlanType,
            allowAtEnd: allowAtEnd,
            onChanged: onPaymentPlanChanged,
          ),
        if (showPayment && paymentPlanType == 'down_payment_installments') ...[
          const SizedBox(height: 12),
          TextField(
            controller: downPaymentController,
            onChanged: onDownPaymentChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            cursorColor: AppColors.primary,
            style: TextStyle(color: foreground),
            decoration: const InputDecoration(
              labelText: 'Down payment',
              suffixText: 'EGP',
            ),
          ),
        ],
        if (showContract) const SizedBox(height: 24),
        if (showContract)
          Text(
            'Signed contract',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        if (showContract) const SizedBox(height: 8),
        if (showContract)
          InkWell(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (sheetContext) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: muted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upload signed contract',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text('Take Photo'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickContract(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.photo_library_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text('Choose Photo'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickContract(ImageSource.gallery);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.folder_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text('Choose File'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickContractFile();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 112,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                image: contractImage == null || !_contractIsImage
                    ? null
                    : DecorationImage(
                        image: FileImage(contractImage!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: contractImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, color: muted),
                        const SizedBox(height: 6),
                        Text(
                          'Take or upload a signed contract',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    )
                  : !_contractIsImage
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          contractImage!.path
                              .split(Platform.pathSeparator)
                              .last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: foreground),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Tap to change file',
                          style: TextStyle(color: muted),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .62),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Change photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class CurrencyAmountFormatter extends TextInputFormatter {
  const CurrencyAmountFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleanValue = newValue.text.replaceAll(',', '');
    if (cleanValue.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(cleanValue)) return oldValue;

    final parts = cleanValue.split('.');
    final whole = parts.first.isEmpty ? '0' : parts.first;
    final grouped = whole.replaceAllMapped(
      RegExp(r'(?<!^)(?=(\d{3})+$)'),
      (_) => ',',
    );
    final text = parts.length == 2 ? '$grouped.${parts[1]}' : grouped;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _PaymentPlanSelector extends StatelessWidget {
  const _PaymentPlanSelector({
    required this.isDark,
    required this.selectedValue,
    required this.allowAtEnd,
    required this.onChanged,
  });

  final bool isDark;
  final String? selectedValue;
  final bool allowAtEnd;
  final ValueChanged<String> onChanged;

  static const _options = [
    (
      'one_time_start',
      'At start',
      'Single payment before work begins',
      Icons.play_circle_outline,
    ),
    (
      'one_time_end',
      'At end',
      'Single payment when work is complete',
      Icons.flag_outlined,
    ),
    (
      'monthly',
      'Monthly',
      'A fixed amount each month',
      Icons.calendar_month_outlined,
    ),
    (
      'down_payment_installments',
      'Down Payment + Monthly Fee',
      'Deposit, then scheduled payments',
      Icons.account_balance_wallet_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: _options
        .where((option) {
          return option.$1 != 'one_time_end' || allowAtEnd;
        })
        .map((option) {
          final isSelected = option.$1 == selectedValue;
          final textColor = isDark ? Colors.white : Colors.black;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              onTap: () => onChanged(option.$1),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: isDark ? .22 : .1)
                      : (isDark
                            ? Colors.white.withValues(alpha: .05)
                            : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? Colors.white12 : Colors.black12),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      option.$4,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.$2,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option.$3,
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white38 : Colors.black26),
                    ),
                  ],
                ),
              ),
            ),
          );
        })
        .toList(),
  );
}
