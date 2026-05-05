import 'dart:ui';
import 'package:flutter/material.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
const kSeed   = Color(0xFF22C55E); // vibrant green
const kBg     = Color(0xFF070F09); // near-black with green tint
const kGlow   = Color(0xFF14532D); // dark green for gradient

// Glass surface tokens
const kGlassFill   = Color(0x0FFFFFFF); // white 6%
const kGlassBorder = Color(0x1AFFFFFF); // white 10%
const kGlassBorderStrong = Color(0x26FFFFFF); // white 15%

// ── Dark theme ────────────────────────────────────────────────────────────────
final appDarkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kSeed,
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF0D0D1A),
    surfaceContainerLow: kGlassFill,
    surfaceContainerHigh: const Color(0x1AFFFFFF),
    outline: kGlassBorder,
    outlineVariant: const Color(0x14FFFFFF),
    onSurface: const Color(0xF2FFFFFF),
    onSurfaceVariant: const Color(0x99FFFFFF),
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: kBg,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Color(0xF2FFFFFF),
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
    iconTheme: IconThemeData(color: Color(0xCCFFFFFF)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Color(0x337C6CF8),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected ? kSeed : const Color(0x66FFFFFF),
        size: 22,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontSize: 9,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: 0.6,
        color: selected ? kSeed : const Color(0x66FFFFFF),
      );
    }),
  ),
  dividerTheme: const DividerThemeData(color: Color(0x14FFFFFF), space: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kSeed,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xCCFFFFFF),
      side: const BorderSide(color: kGlassBorderStrong),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kSeed,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kGlassFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGlassBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGlassBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kSeed, width: 1.5),
    ),
    hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF10101E),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: kGlassBorder),
    ),
    titleTextStyle: const TextStyle(
      color: Color(0xF2FFFFFF),
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ),
    contentTextStyle: const TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFF1A1A2E),
    contentTextStyle: const TextStyle(color: Color(0xF2FFFFFF)),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: kGlassBorder),
    ),
    behavior: SnackBarBehavior.floating,
  ),
);

// ── GlassCard ─────────────────────────────────────────────────────────────────
/// Semi-transparent blurred card — use anywhere over the gradient background.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20.0,
    this.blur = 20.0,
    this.fillOpacity = 0.06,
    this.borderOpacity = 0.10,
    this.borderWidth = 1.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double fillOpacity;
  final double borderOpacity;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: fillOpacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── AppGradient ───────────────────────────────────────────────────────────────
/// Radial indigo glow behind the app content.
class AppGradient extends StatelessWidget {
  const AppGradient({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.1, -1.0),
                radius: 1.4,
                colors: [
                  kGlow.withValues(alpha: 0.45),
                  kBg,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
