import 'package:flutter/material.dart';

/// Built-in notebook cover styles (gradient + accent), selected by index.
class CoverStyle {
  const CoverStyle(this.name, this.colors);
  final String name;
  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

const List<CoverStyle> kCoverStyles = [
  CoverStyle('Indigo', [Color(0xFF4F6DF5), Color(0xFF2A3EB1)]),
  CoverStyle('Teal', [Color(0xFF19B8A6), Color(0xFF0E7C74)]),
  CoverStyle('Coral', [Color(0xFFFF7A6B), Color(0xFFE24C60)]),
  CoverStyle('Amber', [Color(0xFFFFC24B), Color(0xFFF39422)]),
  CoverStyle('Violet', [Color(0xFF9B6DF5), Color(0xFF6B3FC0)]),
  CoverStyle('Slate', [Color(0xFF54606E), Color(0xFF2C333C)]),
  CoverStyle('Forest', [Color(0xFF3FA96B), Color(0xFF1F7A45)]),
  CoverStyle('Rose', [Color(0xFFF56D9B), Color(0xFFC03F6B)]),
];

CoverStyle coverStyleAt(int index) =>
    kCoverStyles[index % kCoverStyles.length];
