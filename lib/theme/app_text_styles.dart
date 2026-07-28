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

  static const tabLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );

  static const tabLabelActive = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );
}
