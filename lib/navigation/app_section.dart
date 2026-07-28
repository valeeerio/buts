import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Le 2 sezioni principali dell'app, navigabili via swipe orizzontale o
/// tramite la freccia nell'header globale (vedi app_root_scaffold.dart).
/// L'ordine corrisponde alle pagine del PageView: indice 0 = sezione di
/// apertura predefinita.
enum AppSection {
  bustePaga,
  budget;

  static const List<AppSection> orderedSections = [
    AppSection.bustePaga,
    AppSection.budget,
  ];

  String get label {
    switch (this) {
      case AppSection.bustePaga:
        return 'Buste Paga';
      case AppSection.budget:
        return 'Budget';
    }
  }

  IconData get icon {
    switch (this) {
      case AppSection.bustePaga:
        return CupertinoIcons.doc_text_fill;
      case AppSection.budget:
        return CupertinoIcons.square_grid_2x2_fill;
    }
  }

  CupertinoDynamicColor get accentColor {
    switch (this) {
      case AppSection.bustePaga:
        return AppColors.bustePaga;
      case AppSection.budget:
        return AppColors.labelPrimary;
    }
  }
}
