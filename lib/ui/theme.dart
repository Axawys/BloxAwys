import 'package:flutter/material.dart';

/// Цвета, которых нет в [ColorScheme].
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.successContainer,
    required this.record,
    required this.selectedCard,
    required this.selectedCardBorder,
    required this.controlBorder,
    required this.bar,
  });

  /// «В игре», «выполняется», включённый анти-AFK.
  final Color success;
  final Color successContainer;

  /// Точка записи макроса.
  final Color record;
  final Color selectedCard;
  final Color selectedCardBorder;

  /// Рамка выпадающих списков.
  final Color controlBorder;

  /// Фон панели макросов внизу главного экрана.
  final Color bar;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Тема в духе Windows 11: системный фон, белые или серые карточки
/// с тонкой рамкой, синий акцент Windows, скругления 6–8 пикселей.
ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final accent = light ? const Color(0xFF0067C0) : const Color(0xFF60CDFF);
  final onAccent = light ? Colors.white : Colors.black;
  final background = light ? const Color(0xFFF3F3F3) : const Color(0xFF202020);
  final card = light ? Colors.white : const Color(0xFF2B2B2B);
  final text = light ? const Color(0xFF1B1B1B) : Colors.white;
  final muted = light ? const Color(0xFF5F6368) : const Color(0xFFA8A8A8);
  final stroke = light ? const Color(0xFFE5E5E5) : const Color(0xFF333333);
  final control = light ? Colors.white : const Color(0xFF2D2D2D);
  final controlStroke = light
      ? const Color(0xFFD1D1D1)
      : const Color(0xFF3A3A3A);
  final flyout = light ? const Color(0xFFF9F9F9) : const Color(0xFF2C2C2C);
  final error = light ? const Color(0xFFC42B1C) : const Color(0xFFFF99A4);
  final soft = light ? const Color(0xFFE5EFFA) : const Color(0xFF1F3A4A);
  final onSoft = light ? const Color(0xFF00427A) : const Color(0xFFBFE9FF);

  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: accent,
        onPrimary: onAccent,
        primaryContainer: soft,
        onPrimaryContainer: onSoft,
        secondaryContainer: soft,
        onSecondaryContainer: onSoft,
        surface: background,
        onSurface: text,
        onSurfaceVariant: muted,
        surfaceContainerLowest: card,
        surfaceContainerLow: card,
        surfaceContainer: flyout,
        surfaceContainerHigh: control,
        surfaceContainerHighest: controlStroke,
        surfaceTint: Colors.transparent,
        outline: muted,
        outlineVariant: stroke,
        error: error,
        errorContainer: light
            ? const Color(0xFFFDE7E9)
            : const Color(0xFF442726),
        onErrorContainer: light
            ? const Color(0xFF8A1C10)
            : const Color(0xFFFFDAD6),
      );

  final small = BorderRadius.circular(6);
  final medium = BorderRadius.circular(8);
  const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  const buttonSize = Size(0, 36);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 14);

  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: 'Segoe UI Variable Text',
    fontFamilyFallback: const ['Segoe UI'],
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: text,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: medium,
        side: BorderSide(color: stroke),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: small),
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: small),
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: buttonText,
        backgroundColor: control,
        foregroundColor: text,
        side: BorderSide(color: controlStroke),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: small),
        minimumSize: buttonSize,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: small),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: small),
        side: BorderSide(color: controlStroke),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: control,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: small,
        borderSide: BorderSide(color: controlStroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: small,
        borderSide: BorderSide(color: controlStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: small,
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: muted, width: 1.5),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: flyout,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      menuPadding: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: medium,
        side: BorderSide(color: stroke),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: medium),
    ),
    dividerTheme: DividerThemeData(color: stroke, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: small),
    ),
    extensions: [
      AppColors(
        success: light ? const Color(0xFF0F7B0F) : const Color(0xFF6CCB5F),
        successContainer: light
            ? const Color(0xFFDFF6DD)
            : const Color(0xFF2E3B2C),
        record: error,
        selectedCard: light ? const Color(0xFFF0F6FD) : const Color(0xFF2C3742),
        selectedCardBorder: light
            ? const Color(0xFFA9CBEC)
            : const Color(0xFF3B6386),
        controlBorder: controlStroke,
        bar: light ? const Color(0xFFFBFBFB) : const Color(0xFF272727),
      ),
    ],
  );
}
