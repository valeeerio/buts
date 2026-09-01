import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'pulse_surface.dart';

/// Pattern condiviso "card di sezione" del materiale Pulse: una singola
/// `PulseSurface` che contiene [rows] separate da un divisore sottile
/// (colore `pulseTextSecondary` a opacità ~0.3, spessore 0.5px, mai prima
/// della prima riga né dopo l'ultima), più un [footer] testuale opzionale
/// sotto la card (stile `pulseLabel`/`pulseTextSecondary`).
///
/// Estratto da tre implementazioni indipendenti che duplicavano lo stesso
/// impianto: `BustaPagaCompetenzeSection`, `BustaPagaMaturazioniSection` e
/// la sezione Trattenute del dettaglio busta paga. La prima riga di ciascuna
/// (header di colonne o riga dati) resta responsabilità del chiamante — qui
/// si gestisce solo il contenitore e la separazione tra righe.
class PulseSectionCard extends StatelessWidget {
  final List<Widget> rows;
  final String? footer;
  final EdgeInsetsGeometry padding;

  const PulseSectionCard({
    super.key,
    required this.rows,
    this.footer,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final separator = textSecondary.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PulseSurface(
          borderRadius: AppRadius.pulse,
          padding: padding,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Container(height: 0.5, color: separator),
                rows[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.xs,
            ),
            child: Text(
              footer!,
              style: AppTextStyles.pulseLabel.copyWith(color: textSecondary),
            ),
          ),
      ],
    );
  }
}
