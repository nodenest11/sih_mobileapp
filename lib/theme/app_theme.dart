import 'package:flutter/material.dart';

class AppColors {
  // Professional corporate colors
  static const primary = Color(0xFF1E40AF); // Professional blue
  static const primaryDark = Color(0xFF1E3A8A);
  static const primaryLight = Color(0xFF3B82F6);
  
  // Accent colors
  static const accent = Color(0xFF0F172A); // Dark slate
  static const success = Color(0xFF10B981); // Emerald
  static const warning = Color(0xFFF59E0B); // Amber
  static const error = Color(0xFFDC2626); // Red
  
  // Text colors
  static const textPrimary = Color(0xFF0F172A); // Dark slate
  static const textSecondary = Color(0xFF64748B); // Slate gray
  static const textTertiary = Color(0xFF94A3B8); // Light slate
  
  // Background colors
  static const background = Color(0xFFF8FAFC); // Very light gray
  static const surface = Color(0xFFFFFFFF); // White
  static const surfaceVariant = Color(0xFFF1F5F9); // Light gray
  
  // Border colors
  static const border = Color(0xFFE2E8F0);
  static const borderFocus = Color(0xFF1E40AF);
}

class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const s = 12.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppRadius {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const full = 999.0;
}

final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.m),
  ),
  textStyle: const TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    letterSpacing: 0.2,
  ),
);

final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.surfaceVariant,
  foregroundColor: AppColors.textPrimary,
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.m),
  ),
  textStyle: const TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    letterSpacing: 0.2,
  ),
);

final ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
  side: const BorderSide(color: AppColors.border, width: 1.5),
  foregroundColor: AppColors.textPrimary,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.m),
  ),
  textStyle: const TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    letterSpacing: 0.2,
  ),
);

final ButtonStyle textButtonStyle = TextButton.styleFrom(
  foregroundColor: AppColors.primary,
  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  textStyle: const TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    letterSpacing: 0.2,
  ),
);
