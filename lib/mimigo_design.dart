import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _licensesRegistered = false;
void registerMimiFontLicenses() {
  if (_licensesRegistered) return;
  _licensesRegistered = true;
  LicenseRegistry.addLicense(() async* {
    for (final family in ['baloo2', 'nunito']) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$family/OFL.txt'));
    }
  });
}

/// Brand values from the local BR1 board and BA/UI PDF page 7. Action/text shades are
/// deliberately darker than decorative swatches to keep readable contrast.
abstract final class MimiColors {
  static const yellow = Color(0xFFFFD133);
  static const orange = Color(0xFFFF8A00);
  static const blue = Color(0xFF1890FF);
  static const green = Color(0xFF4CAF50);
  static const pink = Color(0xFFFF6FAE);
  static const purple = Color(0xFF9C6BFF);
  static const ink = Color(0xFF102665);
  static const muted = Color(0xFF4F6387);
  static const action = Color(0xFFB71467);
  static const blueText = Color(0xFF075DA9);
  static const border = Color(0xFFDCE4F2);
  static const canvas = Color(0xFFFFFCF6);
  static const sky = Color(0xFFE9F6FF);
  static const rose = Color(0xFFFFF0F6);
}

abstract final class MimiSpace {
  static const small = 8.0;
  static const gap = 12.0;
  static const inset = 20.0;
  static const section = 24.0;
  static const parentWidth = 620.0;
  static const learningWidth = 1120.0;
  static const childTarget = 64.0;
}

ThemeData mimiTheme() {
  const scheme = ColorScheme.light(
    primary: MimiColors.action,
    onPrimary: Colors.white,
    primaryContainer: MimiColors.rose,
    onPrimaryContainer: MimiColors.ink,
    secondary: MimiColors.blueText,
    onSecondary: Colors.white,
    secondaryContainer: MimiColors.sky,
    onSecondaryContainer: MimiColors.ink,
    surface: Colors.white,
    onSurface: MimiColors.ink,
    onSurfaceVariant: MimiColors.muted,
    outline: MimiColors.muted,
    outlineVariant: MimiColors.border,
    error: Color(0xFFAD1939),
    onError: Colors.white,
  );
  TextStyle heading(double size) => TextStyle(
    fontFamily: 'Baloo2',
    fontSize: size,
    height: 1.16,
    fontWeight: FontWeight.w700,
    color: MimiColors.ink,
  );
  const buttonText = TextStyle(
    fontFamily: 'Baloo2',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MimiColors.canvas,
    fontFamily: 'Nunito',
    textTheme: TextTheme(
      displaySmall: heading(40),
      headlineLarge: heading(34),
      headlineMedium: heading(30),
      headlineSmall: heading(26),
      titleLarge: heading(24),
      titleMedium: const TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
      titleSmall: const TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
      bodyLarge: const TextStyle(fontSize: 18, height: 1.45),
      bodyMedium: const TextStyle(fontSize: 16, height: 1.45),
      bodySmall: const TextStyle(
        fontSize: 14,
        height: 1.45,
        color: MimiColors.muted,
      ),
      labelLarge: buttonText,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        disabledBackgroundColor: const Color(0xFFE8EAF0),
        disabledForegroundColor: const Color(0xFF5A6375),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MimiColors.ink,
        minimumSize: const Size(64, 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        textStyle: buttonText,
        side: const BorderSide(color: MimiColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MimiColors.blueText,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: buttonText.copyWith(fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: MimiColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: MimiColors.action, width: 2),
      ),
      errorMaxLines: 4,
      helperMaxLines: 4,
      labelStyle: const TextStyle(color: MimiColors.muted, fontSize: 16),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: MimiColors.border),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.all(16),
      minVerticalPadding: 16,
      iconColor: MimiColors.action,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MimiColors.sky,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: const TextStyle(
        color: MimiColors.ink,
        fontFamily: 'Nunito',
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: MimiColors.ink,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 16),
    ),
  );
}

class MimiPanel extends StatelessWidget {
  const MimiPanel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    elevation: 1,
    shadowColor: const Color(0x18102665),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: MimiColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class MimiNotice extends StatelessWidget {
  const MimiNotice({
    super.key,
    required this.child,
    this.icon = Icons.info_outline,
    this.color = MimiColors.sky,
  });
  final Widget child;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 280 &&
          MediaQuery.textScalerOf(context).scale(16) > 24;
      final content = DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.bodySmall,
        child: child,
      );
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, color: MimiColors.ink, size: 22),
                  ),
                  const SizedBox(height: 8),
                  content,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, color: MimiColors.ink, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: content),
                ],
              ),
      );
    },
  );
}

class MimiAvatar extends StatelessWidget {
  const MimiAvatar({super.key, this.stockKey, this.size = 52});
  final String? stockKey;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: stockKey == 'bee-yellow'
          ? const Color(0xFFFFF3B8)
          : MimiColors.sky,
    ),
    child: Icon(
      stockKey == 'bee-yellow'
          ? Icons.emoji_nature_outlined
          : stockKey == 'bear-blue'
          ? Icons.pets_outlined
          : Icons.child_care_outlined,
      color: MimiColors.ink,
      size: size * .54,
      semanticLabel: 'Predefined child avatar',
    ),
  );
}

class MimiDomainStyle {
  const MimiDomainStyle(this.color, this.icon);
  final Color color;
  final IconData icon;
  static MimiDomainStyle forCode(String code) => switch (code.toUpperCase()) {
    'MATH' => const MimiDomainStyle(
      MimiColors.orange,
      Icons.calculate_outlined,
    ),
    'LANG' || 'LANGUAGE' => const MimiDomainStyle(
      MimiColors.blue,
      Icons.menu_book_outlined,
    ),
    'ENGLISH' || 'ENG' => const MimiDomainStyle(MimiColors.blue, Icons.abc),
    'LIFE' ||
    'LIFESKILLS' => const MimiDomainStyle(MimiColors.green, Icons.eco_outlined),
    'LOGIC' => const MimiDomainStyle(
      MimiColors.purple,
      Icons.psychology_outlined,
    ),
    'ARTS' => const MimiDomainStyle(MimiColors.pink, Icons.palette_outlined),
    _ => const MimiDomainStyle(MimiColors.yellow, Icons.public),
  };
}

class MimiDomainTile extends StatelessWidget {
  const MimiDomainTile({
    super.key,
    required this.label,
    required this.code,
    required this.onPressed,
    this.description,
  });
  final String label, code;
  final String? description;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final style = MimiDomainStyle.forCode(code);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: style.color.withValues(alpha: .10),
        side: BorderSide(color: style.color.withValues(alpha: .45), width: 1.5),
        padding: const EdgeInsets.all(14),
        minimumSize: const Size(64, 132),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(style.icon, size: 32, color: MimiColors.ink),
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Content-driven wrapping rather than fixed aspect ratios: long translated
/// labels and large accessibility text can grow without clipping controls.
class MimiTileGrid extends StatelessWidget {
  const MimiTileGrid({
    super.key,
    required this.children,
    this.minimumWidth = 132,
  });
  final List<Widget> children;
  final double minimumWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final count =
          (constraints.maxWidth / (minimumWidth * scale.clamp(1, 1.8)))
              .floor()
              .clamp(1, children.length.clamp(1, 4));
      final width = (constraints.maxWidth - (count - 1) * 12) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// UI-01: category controls keep their touch area and scroll horizontally on
/// phones rather than shrinking six/seven items into one narrow row.
class MimiDomainRail extends StatelessWidget {
  const MimiDomainRail({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(width: 132 * scale.clamp(1, 1.8), child: child),
            ),
        ],
      ),
    );
  }
}
