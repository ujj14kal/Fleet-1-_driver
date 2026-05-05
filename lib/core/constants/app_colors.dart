import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Brand Colors ──────────────────────────────────
  static const Color primaryNavy  = Color(0xFF1F2F58); // Primary – splash, nav bars, headers
  static const Color primaryAmber = Color(0xFFFFa800); // Primary – CTAs, buttons, highlights

  // ── Secondary ─────────────────────────────────────────────
  static const Color secondaryRed = Color(0xFFAF0000); // Errors, cancelled, danger

  // ── Background ────────────────────────────────────────────
  static const Color background   = Color(0xFFF8FAFC); // All screen backgrounds

  // ── Supportive ────────────────────────────────────────────
  static const Color supportGreen = Color(0xFF00BF63); // Success, delivered, active
  static const Color supportDark  = Color(0xFF0F172A); // Dark surfaces, body text

  // ── Derived / Utility ─────────────────────────────────────
  static const Color white        = Color(0xFFFFFFFF);
  static const Color cardBg       = Color(0xFFFFFFFF);
  static const Color textPrimary  = Color(0xFF0F172A);  // supportDark
  static const Color textSecondary= Color(0xFF475569);
  static const Color textMuted    = Color(0xFF94A3B8);
  static const Color border       = Color(0xFFE2E8F0);
  static const Color borderMedium = Color(0xFFCBD5E1);
  static const Color divider      = Color(0xFFF1F5F9);

  // ── Status Badge Colors ───────────────────────────────────
  static const Color statusPending    = Color(0xFFFFa800); // primaryAmber
  static const Color statusAssigned   = Color(0xFF3B82F6);
  static const Color statusInTransit  = Color(0xFF8B5CF6);
  static const Color statusAtHub      = Color(0xFF3B82F6);
  static const Color statusPickedUp   = Color(0xFFFFa800);
  static const Color statusDelivered  = Color(0xFF00BF63); // supportGreen
  static const Color statusCancelled  = Color(0xFFAF0000); // secondaryRed
  static const Color statusHandover   = Color(0xFFFFa800);

  // ── Amber shades (for overlays, chips) ────────────────────
  static const Color amberLight  = Color(0xFFFFF7E6);
  static const Color amberBorder = Color(0xFFFFD37A);

  // ── Navy shades ───────────────────────────────────────────
  static const Color navyLight   = Color(0xFFEEF1F9);
  static const Color navyMid     = Color(0xFF2D4070);

  // ── Green shades ──────────────────────────────────────────
  static const Color greenLight  = Color(0xFFE6F9EF);
  static const Color greenBorder = Color(0xFF5CE09A);

  // ── Red shades ────────────────────────────────────────────
  static const Color redLight    = Color(0xFFFCEBEB);
  static const Color redBorder   = Color(0xFFD97E7E);

  // ── Shadow ────────────────────────────────────────────────
  static const Color shadow      = Color(0x0D0F172A);
  static const Color shadowMedium= Color(0x1A0F172A);
}
