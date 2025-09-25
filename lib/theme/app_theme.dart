import 'package:flutter/material.dart';

class AppColors {
  static const redPrimary = Color(0xFFD32F2F);
  static const redDark = Color(0xFFB71C1C);
  static const redLight = Color(0xFFFFEBEE);
  static const greyText = Color(0xFF616161);
  static const greyLight = Color(0xFFF5F5F5);
}

class AppSpacing {
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
}

final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: AppColors.redPrimary,
  foregroundColor: Colors.white,
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
);

final ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(vertical: 16),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  side: const BorderSide(color: AppColors.redPrimary, width: 1.2),
  textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
);
