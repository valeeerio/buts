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

  static const cardAmount = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const cardLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  // --- Pulse ---
  // Ruoli tipografici della direzione "Pulse" (vedi CLAUDE.md, "Stile
  // visivo"): font di sistema ovunque (nessun `fontFamily` esplicito — su
  // iOS risolve a SF Pro Text/Display tramite CupertinoTheme). Fino al
  // 2026-09-08 questi ruoli usavano Space Grotesk/Inter bundlati offline;
  // rimossi su richiesta esplicita dell'utente dopo aver visto lo stile del
  // widget home screen (che usa già solo il font di sistema).

  /// Titoli/numeri di massimo rilievo (es. netto del mese in evidenza).
  static const pulseDisplayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    height: 1.1,
  );

  /// Titoli di sezione e valori numerici secondari (es. importi in tessere).
  static const pulseDisplay = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.15,
  );

  /// Valori numerici compatti (es. celle di tabella, badge di variazione).
  static const pulseDisplaySmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Corpo testo standard.
  static const pulseBody = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  /// Corpo testo enfatizzato (peso medium).
  static const pulseBodyEmphasis = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Label/UI compatta (es. etichette sopra i valori nelle tessere).
  static const pulseLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );
}
