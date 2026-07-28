import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../models/area_type.dart';

/// Le 5 destinazioni della tab bar inferiore, in ordine di visualizzazione.
/// Ordine fisso concordato: 2 aree a sinistra, Dashboard al centro, 2 a destra.
///   Impegni Fissi — Risparmio Principale — [ Dashboard ] — Conto Principale — Piccolo Risparmio
///
/// Buste Paga NON è in questa tab bar: è un modulo separato (vedi CLAUDE.md),
/// raggiungibile da un ingresso secondario (es. icona nell'header della Dashboard).
enum AppTab {
  impegniFissi,
  risparmioPrincipale,
  dashboard,
  contoPrincipale,
  piccoloRisparmio;

  static const List<AppTab> orderedTabs = [
    AppTab.impegniFissi,
    AppTab.risparmioPrincipale,
    AppTab.dashboard,
    AppTab.contoPrincipale,
    AppTab.piccoloRisparmio,
  ];

  String get label {
    switch (this) {
      case AppTab.impegniFissi:
        return 'Impegni Fissi';
      case AppTab.risparmioPrincipale:
        return 'Risparmio';
      case AppTab.dashboard:
        return 'Dashboard';
      case AppTab.contoPrincipale:
        return 'Principale';
      case AppTab.piccoloRisparmio:
        return 'Piccolo Risp.';
    }
  }

  /// Icona SF Symbols-style (CupertinoIcons), non emoji.
  IconData get icon {
    switch (this) {
      case AppTab.impegniFissi:
        return CupertinoIcons.doc_text_fill;
      case AppTab.risparmioPrincipale:
        return CupertinoIcons.arrow_up_circle_fill;
      case AppTab.dashboard:
        return CupertinoIcons.square_grid_2x2_fill;
      case AppTab.contoPrincipale:
        return CupertinoIcons.creditcard_fill;
      case AppTab.piccoloRisparmio:
        return CupertinoIcons.star_fill;
    }
  }

  CupertinoDynamicColor get activeColor {
    switch (this) {
      case AppTab.impegniFissi:
        return AreaType.impegniFissi.color;
      case AppTab.risparmioPrincipale:
        return AreaType.risparmioPrincipale.color;
      case AppTab.dashboard:
        return AppColors.labelPrimary;
      case AppTab.contoPrincipale:
        return AreaType.contoPrincipale.color;
      case AppTab.piccoloRisparmio:
        return AreaType.piccoloRisparmio.color;
    }
  }
}
