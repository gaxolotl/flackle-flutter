import 'package:flutter/material.dart';

import 'prefs.dart';

@immutable
class FlackleColors extends ThemeExtension<FlackleColors> {
  const FlackleColors({
    required this.bg,
    required this.bgSoft,
    required this.rail,
    required this.sidebar,
    required this.chat,
    required this.panel,
    required this.panel2,
    required this.panel3,
    required this.card,
    required this.input,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textDim,
    required this.muted,
    required this.accent,
    required this.accentDim,
    required this.green,
    required this.yellow,
    required this.hover,
    required this.active,
    required this.danger,
    required this.shadow,
  });

  final Color bg;
  final Color bgSoft;
  final Color rail;
  final Color sidebar;
  final Color chat;
  final Color panel;
  final Color panel2;
  final Color panel3;
  final Color card;
  final Color input;
  final Color line;
  final Color lineStrong;
  final Color text;
  final Color textDim;
  final Color muted;
  final Color accent;
  final Color accentDim;
  final Color green;
  final Color yellow;
  final Color hover;
  final Color active;
  final Color danger;
  final Color shadow;

  static FlackleColors dark(Color accent) => FlackleColors(
        bg: const Color(0xFF08080B),
        bgSoft: const Color(0xFF0B0B0F),
        rail: const Color(0xFF060609),
        sidebar: const Color(0xFF0D0D0F),
        chat: const Color(0xFF0F0F14),
        panel: const Color(0xFF14141B),
        panel2: const Color(0xFF17171D),
        panel3: const Color(0xFF1A1A21),
        card: const Color(0xFF121218),
        input: const Color(0xFF0B0B0F),
        line: Colors.white.withValues(alpha: 0.07),
        lineStrong: Colors.white.withValues(alpha: 0.12),
        text: Colors.white,
        textDim: const Color(0xFFB7B7C1),
        muted: const Color(0xFF7B7B87),
        accent: accent,
        accentDim: accent.withValues(alpha: 0.12),
        green: const Color(0xFF34D399),
        yellow: const Color(0xFFFBBF24),
        hover: Colors.white.withValues(alpha: 0.045),
        active: Colors.white.withValues(alpha: 0.075),
        danger: const Color(0xFFEF5252),
        shadow: Colors.black.withValues(alpha: 0.45),
      );

  static FlackleColors light(Color accent) => FlackleColors(
        bg: const Color(0xFFF4F2EE),
        bgSoft: const Color(0xFFECE9E3),
        rail: const Color(0xFFE9E6E0),
        sidebar: const Color(0xFFF7F5F1),
        chat: const Color(0xFFFBFAF7),
        panel: const Color(0xFFFBFAF7),
        panel2: const Color(0xFFFFFFFF),
        panel3: const Color(0xFFEEECE6),
        card: const Color(0xFFFFFFFF),
        input: const Color(0xFFF7F5F1),
        line: const Color(0x13121318),
        lineStrong: const Color(0x25121318),
        text: const Color(0xFF15161B),
        textDim: const Color(0xFF4D5260),
        muted: const Color(0xFF767B89),
        accent: Color.lerp(accent, const Color(0xFFD94040), 0.25)!,
        accentDim: accent.withValues(alpha: 0.1),
        green: const Color(0xFF179B74),
        yellow: const Color(0xFFB87912),
        hover: const Color(0x0B121318),
        active: const Color(0x13121318),
        danger: const Color(0xFFD94040),
        shadow: const Color(0x24282319),
      );

  @override
  FlackleColors copyWith({Color? accent}) => FlackleColors(
        bg: bg,
        bgSoft: bgSoft,
        rail: rail,
        sidebar: sidebar,
        chat: chat,
        panel: panel,
        panel2: panel2,
        panel3: panel3,
        card: card,
        input: input,
        line: line,
        lineStrong: lineStrong,
        text: text,
        textDim: textDim,
        muted: muted,
        accent: accent ?? this.accent,
        accentDim: accent == null ? accentDim : accent.withValues(alpha: 0.12),
        green: green,
        yellow: yellow,
        hover: hover,
        active: active,
        danger: danger,
        shadow: shadow,
      );

  @override
  FlackleColors lerp(ThemeExtension<FlackleColors>? other, double t) {
    if (other is! FlackleColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FlackleColors(
      bg: mix(bg, other.bg),
      bgSoft: mix(bgSoft, other.bgSoft),
      rail: mix(rail, other.rail),
      sidebar: mix(sidebar, other.sidebar),
      chat: mix(chat, other.chat),
      panel: mix(panel, other.panel),
      panel2: mix(panel2, other.panel2),
      panel3: mix(panel3, other.panel3),
      card: mix(card, other.card),
      input: mix(input, other.input),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      text: mix(text, other.text),
      textDim: mix(textDim, other.textDim),
      muted: mix(muted, other.muted),
      accent: mix(accent, other.accent),
      accentDim: mix(accentDim, other.accentDim),
      green: mix(green, other.green),
      yellow: mix(yellow, other.yellow),
      hover: mix(hover, other.hover),
      active: mix(active, other.active),
      danger: mix(danger, other.danger),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension FlackleThemeContext on BuildContext {
  FlackleColors get c => Theme.of(this).extension<FlackleColors>()!;

  TextStyle get body => Theme.of(this).textTheme.bodyMedium!;

  TextStyle display(double size,
          {FontWeight weight = FontWeight.w600,
          Color? color,
          double? height,
          double? letterSpacing}) =>
      TextStyle(
        fontFamily: 'Satoshi',
        fontSize: size,
        fontWeight: weight,
        color: color ?? c.text,
        height: height,
        letterSpacing: letterSpacing,
      );

  TextStyle label(double size,
          {FontWeight weight = FontWeight.w500,
          Color? color,
          double? height,
          double? letterSpacing}) =>
      TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: weight,
        color: color ?? c.text,
        height: height,
        letterSpacing: letterSpacing,
      );
}

ThemeData buildFlackleTheme(Brightness brightness, Color accent) {
  final colors = brightness == Brightness.dark
      ? FlackleColors.dark(accent)
      : FlackleColors.light(accent);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: Colors.white,
    secondary: colors.accent,
    onSecondary: Colors.white,
    secondaryContainer: colors.accentDim,
    onSecondaryContainer: colors.accent,
    surface: colors.chat,
    onSurface: colors.text,
    surfaceContainerHighest: colors.panel3,
    error: colors.danger,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    dividerColor: colors.line,
    fontFamily: 'Manrope',
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: colors.text,
      displayColor: colors.text,
      fontFamily: 'Manrope',
    ),
    extensions: [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.bg,
      foregroundColor: colors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Satoshi',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.text,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: colors.textDim, size: 20),
    ),
    iconTheme: IconThemeData(color: colors.textDim, size: 20),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.input,
      hintStyle: TextStyle(color: colors.muted, fontSize: 14),
      labelStyle: TextStyle(color: colors.muted, fontSize: 13),
      helperStyle: TextStyle(color: colors.muted, fontSize: 11),
      errorStyle: TextStyle(color: colors.danger, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.accent, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.lineStrong),
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titleTextStyle: TextStyle(
        fontFamily: 'Satoshi',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.text,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        height: 1.45,
        color: colors.textDim,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.panel,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.panel2,
      contentTextStyle: TextStyle(color: colors.text, fontSize: 13),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : colors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accent
            : colors.panel3,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.textDim,
      textColor: colors.text,
      subtitleTextStyle: TextStyle(color: colors.muted, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.panel2,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: colors.text, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.lineStrong),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.panel2,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: colors.lineStrong),
      ),
      textStyle: TextStyle(color: colors.text, fontSize: 11),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.panel3,
      circularTrackColor: colors.panel3,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.panel2,
      selectedColor: colors.accentDim,
      checkmarkColor: colors.accent,
      side: BorderSide(color: colors.line),
      labelStyle: TextStyle(color: colors.textDim, fontSize: 11),
      secondaryLabelStyle: TextStyle(
          color: colors.accent, fontSize: 11, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : colors.textDim,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : colors.muted,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? colors.accent
                : colors.lineStrong,
          ),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    ),
  );
}

extension DensitySpacing on AppPrefs {
  double get messageGap => compact ? 2 : 8;
  double get listGap => compact ? 1 : 4;
}
