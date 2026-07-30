import 'package:flutter/cupertino.dart';

/// Colori semantici stile Apple (system colors), con varianti Light/Dark.
class AppColors {
  AppColors._();

  // --- System semantic colors (Light / Dark) ---
  static const systemGreen = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF34C759),
    darkColor: Color(0xFF30D158),
  );
  static const systemBlue = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF007AFF),
    darkColor: Color(0xFF0A84FF),
  );
  static const systemPurple = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFAF52DE),
    darkColor: Color(0xFFBF5AF2),
  );
  static const systemOrange = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF9500),
    darkColor: Color(0xFFFF9F0A),
  );
  static const systemRed = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF3B30),
    darkColor: Color(0xFFFF453A),
  );

  // --- Backgrounds & surfaces ---
  static const backgroundPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF000000),
  );
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );
  static const surfaceSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF2C2C2E),
  );

  // --- Labels (testo) ---
  static const labelPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF000000),
    darkColor: Color(0xFFFFFFFF),
  );
  static const labelSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0x993C3C43), // 60% opacity black
    darkColor: Color(0x99EBEBF5), // 60% opacity white
  );
  static const labelTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0x4D3C3C43), // 30% opacity black
    darkColor: Color(0x4DEBEBF5), // 30% opacity white
  );

  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0x4A3C3C43),
    darkColor: Color(0x99545458),
  );

  /// Colore neutro di accento per la sezione Buste Paga (icone, CTA).
  static const bustePaga = CupertinoDynamicColor.withBrightness(
    color: Color(0x803C3C43),
    darkColor: Color(0x80EBEBF5),
  );

  // --- Liquid Glass ---
  // Palette volutamente sobria/neutra: il materiale vetro è la fonte di
  // profondità, il colore resta riservato ad accenti puntuali (badge di
  // stato, CTA primaria) — coerente con le linee guida Apple sul Liquid
  // Glass ("usa il colore con parsimonia sopra il vetro"). Usati solo da
  // `LiquidGlassSurface`/`LiquidGlassButton`.

  /// Riempimento della superficie di vetro, sopra il blur. Resta chiaro e
  /// leggermente più opaco in light mode, più scuro/trasparente in dark
  /// mode senza mai diventare nero pieno (il vetro "regular" di Apple
  /// schiarisce leggermente anche sopra sfondi scuri).
  static const glassFill = CupertinoDynamicColor.withBrightness(
    color: Color(0xB3FFFFFF),
    darkColor: Color(0x40FFFFFF),
  );

  /// Riflesso speculare sul bordo (angolo in cui la luce "colpisce" il
  /// vetro): usato solo per lo stroke con gradiente del bordo, mai come
  /// riempimento pieno.
  static const glassHighlight = CupertinoDynamicColor.withBrightness(
    color: Color(0xCCFFFFFF),
    darkColor: Color(0x66FFFFFF),
  );

  /// Bordo in ombra, lato opposto al riflesso speculare.
  static const glassShadowEdge = CupertinoDynamicColor.withBrightness(
    color: Color(0x14000000),
    darkColor: Color(0x4D000000),
  );
}
