import 'package:flutter/cupertino.dart';

import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'pulse_icon.dart';
import 'pulse_section_card.dart';
import 'spring_button.dart';
import 'voce_competenza_edit_row.dart';

/// Tabella delle voci di competenza individuali (Retribuzione ordinaria, Edr
/// contrattuale, Straordinario per fascia, ecc.), colonne fisse
/// "Descrizione | Quantità | Importo" — SEMPRE VISIBILE, mai collassabile,
/// stesso impianto di `BustaPagaMaturazioniSection`. In sola lettura mostra
/// [competenze]; in editing mostra [righeEdit] con swipe-to-delete e un
/// bottone "+ Aggiungi voce" in fondo.
class BustaPagaCompetenzeSection extends StatelessWidget {
  final bool isEditing;
  final List<VoceCompetenza> competenze;
  final List<VoceCompetenzaEditRow>? righeEdit;
  final VoidCallback? onAggiungi;
  final void Function(int index)? onRimuovi;

  const BustaPagaCompetenzeSection({
    super.key,
    required this.isEditing,
    required this.competenze,
    this.righeEdit,
    this.onAggiungi,
    this.onRimuovi,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);

    final rows = <Widget>[
      _tableHeaderRow(textSecondary),
      if (isEditing) ...[
        for (var i = 0; i < (righeEdit?.length ?? 0); i++)
          voceCompetenzaEditRow(
            righeEdit![i],
            onDismissed: () => onRimuovi?.call(i),
          ),
        _aggiungiVoceButton(accent),
      ] else if (competenze.isEmpty)
        _readOnlyMessageRow(context, 'Nessuna competenza dettagliata')
      else
        for (final voce in competenze) _readOnlyRow(context, voce),
    ];

    return PulseSectionCard(rows: rows);
  }

  Widget _tableHeaderRow(Color textSecondary) {
    final style = AppTextStyles.pulseLabel.copyWith(color: textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Descrizione',
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Quantità',
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Importo',
              style: style,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyRow(BuildContext context, VoceCompetenza voce) {
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    final valueStyle = AppTextStyles.pulseDisplaySmall.copyWith(
      color: textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              voce.descrizione,
              style: AppTextStyles.pulseBodyEmphasis.copyWith(
                color: textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              // `—`: quantità ASSENTE (nessun tag GIORNI/ORE/RATEI sul PDF
              // per questa riga, es. "930 Trattamento integrativo"), distinta
              // da 0 stampato esplicitamente — vedi `VoceCompetenza.quantita`.
              // Mostrare "0" sarebbe fuorviante ("zero giorni/ore" invece di
              // "nessuna quantità associata").
              voce.quantita == null ? '—' : formatNumber(voce.quantita!),
              style: valueStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              voce.importo == 0 ? '—' : formatEuroConSegno(voce.importo),
              style: valueStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyMessageRow(BuildContext context, String message) {
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Text(
        message,
        style: AppTextStyles.pulseBody.copyWith(color: textSecondary),
      ),
    );
  }

  Widget _aggiungiVoceButton(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: SpringButton(
        onPressed: onAggiungi ?? () {},
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseIcon(glyph: PulseIconGlyph.add, color: accent, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text('Aggiungi voce',
                style: AppTextStyles.pulseBodyEmphasis.copyWith(color: accent)),
          ],
        ),
      ),
    );
  }
}
