import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFfdb913);
  static const Color secondary = Color(0xFF005587);
  static const Color lightbg = Color(0xFFF9F9F9);
  static const Color darkbg = Color(0xFF151515);
  static const Color lightcolor = Color(0xFFF0F0F0);
  static const Color darkcolor = Color(0xFF000000);
}

class AppFontStyle {
  // Font Sizes
  static const double _titleSize = 28;
  static const double _subTitleSize = 24;
  static const double _textSize = 18;
  static const double _descriptionSize = 12;

  // Font Weights
  static const FontWeight _light = FontWeight.w300;
  static const FontWeight _regular = FontWeight.w400;
  static const FontWeight _medium = FontWeight.w500;
  static const FontWeight _semiBold = FontWeight.w600;
  static const FontWeight _bold = FontWeight.w700;

  // Private method to build text style with optional color
  static TextStyle _style(double size, FontWeight weight, [Color? color]) =>
      TextStyle(fontSize: size, fontWeight: weight, color: color);

  // Title
  static TextStyle titleLight([Color? color]) =>
      _style(_titleSize, _light, color);
  static TextStyle titleRegular([Color? color]) =>
      _style(_titleSize, _regular, color);
  static TextStyle titleMedium([Color? color]) =>
      _style(_titleSize, _medium, color);
  static TextStyle titleSemiBold([Color? color]) =>
      _style(_titleSize, _semiBold, color);
  static TextStyle titleBold([Color? color]) =>
      _style(_titleSize, _bold, color);

  // Subtitle
  static TextStyle subTitleLight([Color? color]) =>
      _style(_subTitleSize, _light, color);
  static TextStyle subTitleRegular([Color? color]) =>
      _style(_subTitleSize, _regular, color);
  static TextStyle subTitleMedium([Color? color]) =>
      _style(_subTitleSize, _medium, color);
  static TextStyle subTitleSemiBold([Color? color]) =>
      _style(_subTitleSize, _semiBold, color);
  static TextStyle subTitleBold([Color? color]) =>
      _style(_subTitleSize, _bold, color);

  // Text
  static TextStyle textLight([Color? color]) =>
      _style(_textSize, _light, color);
  static TextStyle textRegular([Color? color]) =>
      _style(_textSize, _regular, color);
  static TextStyle textMedium([Color? color]) =>
      _style(_textSize, _medium, color);
  static TextStyle textSemiBold([Color? color]) =>
      _style(_textSize, _semiBold, color);
  static TextStyle textBold([Color? color]) => _style(_textSize, _bold, color);

  // Description
  static TextStyle descriptionLight([Color? color]) =>
      _style(_descriptionSize, _light, color);
  static TextStyle descriptionRegular([Color? color]) =>
      _style(_descriptionSize, _regular, color);
  static TextStyle descriptionMedium([Color? color]) =>
      _style(_descriptionSize, _medium, color);
  static TextStyle descriptionSemiBold([Color? color]) =>
      _style(_descriptionSize, _semiBold, color);
  static TextStyle descriptionBold([Color? color]) =>
      _style(_descriptionSize, _bold, color);
}

class AppVersion {
  static const String version = "1.0.0";
}
