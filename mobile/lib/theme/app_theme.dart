import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Brand token ───────────────────────────────────────────────────────────────
const kSeed = Color(0xFF22C55E);

// ── Neumorphism palette constants ─────────────────────────────────────────────
// Dark mineral
const kBg          = Color(0xFF13161E);
const kNeuroHiDark = Color(0xFF1C2C28);
const kNeuroShDark = Color(0xFF07080C);

// Light mineral
const kBgLight      = Color(0xFFE4EDE8);
const kNeuroHiLight = Color(0xB8FFFFFF);
const kNeuroShLight = Color(0x99B5C3BC);

// Legacy aliases (kept for backward compat)
const kGlow              = kNeuroHiDark;
const kGlassFill         = Color(0x0F1C2C28);
const kGlassBorder       = Color(0x1A1C2C28);
const kGlassBorderStrong = Color(0x261C2C28);

// ── NeuroSize ─────────────────────────────────────────────────────────────────
enum NeuroSize {
  sm(blur: 7.0, offset: 3.0),
  md(blur: 14.0, offset: 7.0),
  lg(blur: 18.0, offset: 9.0);

  const NeuroSize({required this.blur, required this.offset});
  final double blur;
  final double offset;
}

// ── AppColors ThemeExtension ──────────────────────────────────────────────────
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.shadowHi,
    required this.shadowSh,
    required this.glowColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textMedium,
    required this.glassBorderBase,
    required this.dividerColor,
    required this.overlayStyle,
  });

  final Color bg;
  final Color shadowHi;
  final Color shadowSh;
  final Color glowColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;
  final Color textMedium;
  final Color glassBorderBase;
  final Color dividerColor;
  final SystemUiOverlayStyle overlayStyle;

  static const dark = AppColors(
    bg:             Color(0xFF13161E),
    shadowHi:       Color(0xFF1C2C28),
    shadowSh:       Color(0xFF07080C),
    glowColor:      Color(0xFF1C2C28),
    textPrimary:    Color(0xFFF1F5F2),
    textSecondary:  Color(0xFF9BB5A7),
    textMuted:      Color(0xFF6B8577),
    textDisabled:   Color(0xFF4A6056),
    textMedium:     Color(0xFFCDE0D6),
    glassBorderBase: Color(0xFF1C2C28),
    dividerColor:   Color(0x1A1C2C28),
    overlayStyle:   SystemUiOverlayStyle.light,
  );

  static const light = AppColors(
    bg:             Color(0xFFE4EDE8),
    shadowHi:       Color(0xB8FFFFFF),
    shadowSh:       Color(0x99B5C3BC),
    glowColor:      Color(0xFF22C55E),
    textPrimary:    Color(0xFF1A1F2E),
    textSecondary:  Color(0xFF4B5563),
    textMuted:      Color(0xFF9CA3AF),
    textDisabled:   Color(0xFFBBC8C0),
    textMedium:     Color(0xFF374151),
    glassBorderBase: Color(0xFFC8D5CF),
    dividerColor:   Color(0x14C8D5CF),
    overlayStyle:   SystemUiOverlayStyle.dark,
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? AppColors.dark;

  // helpers
  List<BoxShadow> raised(NeuroSize size) => [
    BoxShadow(color: shadowHi, blurRadius: size.blur, offset: Offset(-size.offset, -size.offset)),
    BoxShadow(color: shadowSh, blurRadius: size.blur, offset: Offset(size.offset, size.offset)),
  ];

  List<BoxShadow> pressed(NeuroSize size) => [
    BoxShadow(color: shadowSh, blurRadius: size.blur, offset: Offset(-size.offset, -size.offset)),
    BoxShadow(color: shadowHi, blurRadius: size.blur, offset: Offset(size.offset, size.offset)),
  ];

  List<BoxShadow> floatNav() => [
    BoxShadow(color: shadowHi, blurRadius: 20, offset: const Offset(0, -8)),
    BoxShadow(color: shadowSh, blurRadius: 10, offset: const Offset(0, 4)),
  ];

  @override
  AppColors copyWith({
    Color? bg,
    Color? shadowHi,
    Color? shadowSh,
    Color? glowColor,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? textMedium,
    Color? glassBorderBase,
    Color? dividerColor,
    SystemUiOverlayStyle? overlayStyle,
  }) => AppColors(
    bg:             bg ?? this.bg,
    shadowHi:       shadowHi ?? this.shadowHi,
    shadowSh:       shadowSh ?? this.shadowSh,
    glowColor:      glowColor ?? this.glowColor,
    textPrimary:    textPrimary ?? this.textPrimary,
    textSecondary:  textSecondary ?? this.textSecondary,
    textMuted:      textMuted ?? this.textMuted,
    textDisabled:   textDisabled ?? this.textDisabled,
    textMedium:     textMedium ?? this.textMedium,
    glassBorderBase: glassBorderBase ?? this.glassBorderBase,
    dividerColor:   dividerColor ?? this.dividerColor,
    overlayStyle:   overlayStyle ?? this.overlayStyle,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg:             Color.lerp(bg, other.bg, t)!,
      shadowHi:       Color.lerp(shadowHi, other.shadowHi, t)!,
      shadowSh:       Color.lerp(shadowSh, other.shadowSh, t)!,
      glowColor:      Color.lerp(glowColor, other.glowColor, t)!,
      textPrimary:    Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary:  Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:      Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled:   Color.lerp(textDisabled, other.textDisabled, t)!,
      textMedium:     Color.lerp(textMedium, other.textMedium, t)!,
      glassBorderBase: Color.lerp(glassBorderBase, other.glassBorderBase, t)!,
      dividerColor:   Color.lerp(dividerColor, other.dividerColor, t)!,
      overlayStyle:   t < 0.5 ? overlayStyle : other.overlayStyle,
    );
  }
}

// ── Dark theme ────────────────────────────────────────────────────────────────
final appDarkTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kSeed,
    brightness: Brightness.dark,
  ).copyWith(
    surface: kBg,
    surfaceContainerLow: const Color(0xFF161B22),
    surfaceContainerHigh: const Color(0xFF1C2330),
    outline: kGlassBorder,
    outlineVariant: const Color(0x141C2C28),
    onSurface: const Color(0xFFF1F5F2),
    onSurfaceVariant: const Color(0xFF9BB5A7),
  ),
  extensions: const [AppColors.dark],
  useMaterial3: true,
  scaffoldBackgroundColor: kBg,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Color(0xFFF1F5F2),
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
    iconTheme: IconThemeData(color: Color(0xFFCDE0D6)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Colors.transparent,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected ? kSeed : const Color(0xFF4A6056),
        size: 22,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontSize: 9,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: 0.6,
        color: selected ? kSeed : const Color(0xFF4A6056),
      );
    }),
  ),
  dividerTheme: const DividerThemeData(color: Color(0x1A1C2C28), space: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kSeed,
      foregroundColor: const Color(0xFF0F2318),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFCDE0D6),
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
    fillColor: const Color(0xFF161B22),
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
    hintStyle: const TextStyle(color: Color(0xFF4A6056)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: kBg,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: kGlassBorder),
    ),
    titleTextStyle: const TextStyle(
      color: Color(0xFFF1F5F2),
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ),
    contentTextStyle: const TextStyle(color: Color(0xFF9BB5A7), fontSize: 14),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFF161B22),
    contentTextStyle: const TextStyle(color: Color(0xFFF1F5F2)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
);

// ── Light theme ───────────────────────────────────────────────────────────────
final appLightTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: kSeed,
    brightness: Brightness.light,
  ).copyWith(
    surface: kBgLight,
    surfaceContainerLow: const Color(0xFFDCE8E2),
    surfaceContainerHigh: const Color(0xFFD1DDD7),
    outline: const Color(0x22C8D5CF),
    outlineVariant: const Color(0x14C8D5CF),
    onSurface: const Color(0xFF1A1F2E),
    onSurfaceVariant: const Color(0xFF4B5563),
  ),
  extensions: const [AppColors.light],
  useMaterial3: true,
  scaffoldBackgroundColor: kBgLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      color: Color(0xFF1A1F2E),
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
    iconTheme: IconThemeData(color: Color(0xFF1A1F2E)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.transparent,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Colors.transparent,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected ? kSeed : const Color(0xFF9CA3AF),
        size: 22,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      final selected = states.contains(WidgetState.selected);
      return TextStyle(
        fontSize: 9,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: 0.6,
        color: selected ? kSeed : const Color(0xFF9CA3AF),
      );
    }),
  ),
  dividerTheme: const DividerThemeData(color: Color(0x14C8D5CF), space: 1),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: kSeed,
      foregroundColor: const Color(0xFF0F2318),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF1A1F2E),
      side: const BorderSide(color: Color(0x33C8D5CF)),
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
    fillColor: const Color(0xFFDCE8E2),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x22C8D5CF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x22C8D5CF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kSeed, width: 1.5),
    ),
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    labelStyle: const TextStyle(color: Color(0xFF4B5563)),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: kBgLight,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0x22C8D5CF)),
    ),
    titleTextStyle: const TextStyle(
      color: Color(0xFF1A1F2E),
      fontWeight: FontWeight.w700,
      fontSize: 18,
    ),
    contentTextStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: kBgLight,
    contentTextStyle: const TextStyle(color: Color(0xFF1A1F2E)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
);

// ── NeuroCard ─────────────────────────────────────────────────────────────────
class NeuroCard extends StatelessWidget {
  const NeuroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20.0,
    this.size = NeuroSize.md,
    this.pressed = false,
    this.accent = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final NeuroSize size;
  final bool pressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadows = pressed ? ac.pressed(size) : ac.raised(size);
    if (accent && isDark) {
      shadows.add(BoxShadow(
        color: kSeed.withValues(alpha: 0.14),
        blurRadius: 28,
      ));
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

// ── GlassCard — now renders as NeuroCard (backward-compat API) ────────────────
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
    this.size = NeuroSize.md,
    this.accent = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double fillOpacity;
  final double borderOpacity;
  final double borderWidth;
  final NeuroSize size;
  final bool accent;

  @override
  Widget build(BuildContext context) => NeuroCard(
    padding: padding,
    radius: radius,
    size: size,
    accent: accent,
    child: child,
  );
}

// ── AppGradient — flat pass-through for neumorphism ───────────────────────────
class AppGradient extends StatelessWidget {
  const AppGradient({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
