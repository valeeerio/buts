import 'package:flutter/cupertino.dart';

/// Gerarchia tipografica system-style (SF Pro / system font).
/// Font family lasciata vuota: su iOS Flutter usa già .SF UI Text/.SF UI Display
/// tramite CupertinoTheme; su Android è consigliato mappare a "SF Pro Text" custom
/// se si vuole coerenza cross-platform (vedi CLAUDE.md).
class AppTextStyles {
  AppTextStyles._();

  static const greeting = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
    height: 1.15,
  );

  static const subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  /// Titolo di sezione (es. "Archivio buste paga"): un gradino sotto
  /// `greeting`, usato per intestazioni di contenuto interne a una sezione.
  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const cardAmountLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  /// Cifra netta in evidenza massima nella hero card del dettaglio busta paga.
  static const heroAmount = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
  );

  static const cardAmount = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const cardLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const changeBadge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const insightText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // --- Pulse ---
  // Ruoli tipografici della nuova direzione "Pulse" (vedi CLAUDE.md, "Stile
  // visivo"): Space Grotesk per titoli/numeri/valori ("tipografia da
  // protagonista"), Inter per corpo/label/UI. Entrambi bundlati offline
  // (`assets/fonts/`, dichiarati in `pubspec.yaml`), con fallback esplicito
  // al font di sistema/`.notoSans` così l'app non crasha mai se un peso
  // dovesse mancare a runtime. Migrazione schermata per schermata — i ruoli
  // sopra restano finché tutte le schermate non sono state migrate.

  /// Titoli/numeri di massimo rilievo (es. netto del mese in evidenza).
  static const pulseDisplayLarge = TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: [
      '.notoSans',
      'CupertinoSystemDisplay',
    ],
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
  );

  /// Titoli di sezione e valori numerici secondari (es. importi in tessere).
  static const pulseDisplay = TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: [
      '.notoSans',
      'CupertinoSystemDisplay',
    ],
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.15,
  );

  /// Valori numerici compatti (es. celle di tabella, badge di variazione).
  static const pulseDisplaySmall = TextStyle(
    fontFamily: 'Space Grotesk',
    fontFamilyFallback: [
      '.notoSans',
      'CupertinoSystemDisplay',
    ],
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Corpo testo standard (Inter, peso regular).
  static const pulseBody = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: [
      '.notoSans',
      'CupertinoSystemText',
    ],
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Corpo testo enfatizzato (Inter, peso medium).
  static const pulseBodyEmphasis = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: [
      '.notoSans',
      'CupertinoSystemText',
    ],
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Label/UI compatta (es. etichette sopra i valori nelle tessere).
  static const pulseLabel = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: [
      '.notoSans',
      'CupertinoSystemText',
    ],
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );
}
