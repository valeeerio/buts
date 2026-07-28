import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Le 4 aree di budget (Buste Paga NON è un'area di budget: è un modulo
/// separato, vedi CLAUDE.md e navigation/app_tab.dart).
enum AreaType {
  contoPrincipale,
  risparmioPrincipale,
  piccoloRisparmio,
  impegniFissi;

  String get label {
    switch (this) {
      case AreaType.contoPrincipale:
        return 'Conto Principale';
      case AreaType.risparmioPrincipale:
        return 'Risparmio Principale';
      case AreaType.piccoloRisparmio:
        return 'Piccolo Risparmio';
      case AreaType.impegniFissi:
        return 'Impegni Fissi';
    }
  }

  String get shortLabel {
    switch (this) {
      case AreaType.contoPrincipale:
        return 'Principale';
      case AreaType.risparmioPrincipale:
        return 'Risparmio';
      case AreaType.piccoloRisparmio:
        return 'Piccolo Risp.';
      case AreaType.impegniFissi:
        return 'Impegni Fissi';
    }
  }

  CupertinoDynamicColor get color {
    switch (this) {
      case AreaType.contoPrincipale:
        return AppColors.contoPrincipale;
      case AreaType.risparmioPrincipale:
        return AppColors.risparmioPrincipale;
      case AreaType.piccoloRisparmio:
        return AppColors.piccoloRisparmio;
      case AreaType.impegniFissi:
        return AppColors.impegniFissi;
    }
  }

  /// Per Conto Principale e Risparmi: un aumento/andamento positivo è favorevole (verde).
  /// Per Impegni Fissi: un aumento è sfavorevole (rosso) — costa di più al mese.
  bool isIncreaseFavorable() => this != AreaType.impegniFissi;
}
