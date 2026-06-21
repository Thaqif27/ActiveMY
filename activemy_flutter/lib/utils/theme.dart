import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Primary Sports Orange ────────────────────────────────────
  static const Color primary = Color(0xFFFF6B35);       // Energetic coral-orange
  static const Color primaryLight = Color(0xFFFF8C61);  // Lighter orange
  static const Color primaryDark = Color(0xFFE84E15);   // Deeper orange

  // ── Nature Green ─────────────────────────────────────────────
  static const Color green = Color(0xFF00C853);         // Vibrant green
  static const Color greenDark = Color(0xFF00796B);     // Deep teal-green
  static const Color greenDeep = Color(0xFF004D40);     // Forest deep

  // ── Dark Backgrounds ─────────────────────────────────────────
  static const Color darkBg = Color(0xFF0D1117);        // Near-black
  static const Color darkCard = Color(0xFF161B22);      // Card dark
  static const Color darkSurface = Color(0xFF21262D);   // Surface dark

  // ── Light Backgrounds ────────────────────────────────────────
  static const Color background = Color(0xFFF5F6FA);    // Soft lavender-white
  static const Color surface = Colors.white;

  // ── Accent / Keep for compat ─────────────────────────────────
  static const Color accent = Color(0xFF00BCD4);
  static const Color secondary = Color(0xFF1E3A8A);

  // ── Category Colors ──────────────────────────────────────────
  static const Color running = Color(0xFFFF5252);
  static const Color cycling = Color(0xFF448AFF);
  static const Color hiking = Color(0xFF00E676);
  static const Color adventure = Color(0xFFFFAB40);
  static const Color triathlon = Color(0xFFE040FB);

  // ── Text ────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF0D1117);
  static const Color textMid = Color(0xFF4A5568);
  static const Color textLight = Color(0xFF718096);
  static const Color textWhite = Color(0xFFF8FAFC);
}

class AppAdminColors {
  // Ultra-premium dark theme colors specifically for Admin Panel
  static const Color bgDark = Color(0xFF0F172A);        // Tailwind Slate 900
  static const Color cardDark = Color(0xFF1E293B);      // Tailwind Slate 800
  static const Color cardLight = Color(0xFF334155);     // Tailwind Slate 700
  static const Color border = Color(0x33FFFFFF);        // More visible white border (20% opacity)
  static const Color primaryNeon = Color(0xFFFF4500);   // Very vibrant neon orange (Orange Red)
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textSub = Color(0xFF94A3B8);
}

class AppGradients {
  // Main orange-to-red sports gradient
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFFFF6B35), Color(0xFFE84E15)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hero banner: dark top → orange bottom
  static const LinearGradient hero = LinearGradient(
    colors: [Color(0xFF1A0A00), Color(0xFF8B2500), Color(0xFFFF6B35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Green nature gradient
  static const LinearGradient green = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00796B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark login background
  static const LinearGradient dark = LinearGradient(
    colors: [Color(0xFF0D1117), Color(0xFF1A0A00)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Image card overlay
  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xE6000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppDecorations {
  static BoxDecoration glassCard = BoxDecoration(
    color: Colors.white.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.18),
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 20,
      ),
    ],
  );

  static BoxDecoration surfaceCard = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static const BoxDecoration gradientButton = BoxDecoration(
    gradient: AppGradients.primary,
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  static const BoxDecoration greenButton = BoxDecoration(
    gradient: AppGradients.green,
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.green,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.textDark),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textDark,
            fontWeight: FontWeight.w500),
        secondaryLabelStyle: GoogleFonts.inter(
            fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
        brightness: Brightness.light,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle:
            GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.green,
      ),
    );
  }

  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'running':
        return AppColors.running;
      case 'cycling':
        return AppColors.cycling;
      case 'hiking':
        return AppColors.hiking;
      case 'adventure':
        return AppColors.adventure;
      case 'triathlon':
        return AppColors.triathlon;
      default:
        return AppColors.primary;
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'cycling':
        return Icons.directions_bike;
      case 'hiking':
        return Icons.terrain;
      case 'adventure':
        return Icons.explore;
      case 'triathlon':
        return Icons.pool;
      default:
        return Icons.sports;
    }
  }

  static String formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
