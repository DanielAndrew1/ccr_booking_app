// ignore_for_file: deprecated_member_use

import 'package:ccr_booking/core/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ccr_booking/localization/app_localizations.dart';

class CustomAlertDialogue extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final String confirm;

  const CustomAlertDialogue({
    super.key,
    required this.icon,
    required this.title,
    required this.body, 
    required this.confirm,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return CupertinoAlertDialog(
      title: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(icon, color: AppColors.red),
          ),
          SizedBox(height: 14),
          Text(loc.tr(title), style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
        ],
      ),
      content: Text(
        loc.tr(body),
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        CupertinoDialogAction(
          child: Text(
            loc.tr("Cancel"),
            style: TextStyle(color: Colors.blue),
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
        CupertinoDialogAction(
          child: Text(
            loc.tr(confirm),
            style: TextStyle(color: AppColors.red),
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
