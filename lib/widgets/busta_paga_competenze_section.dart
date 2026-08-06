import 'package:flutter/cupertino.dart';

import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'glass_form_section.dart';
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
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);

    return GlassFormSection(
      children: [
        _tableHeaderRow(labelSecondary),
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
      ],
    );
  }

  Widget _tableHeaderRow(Color labelSecondary) {
    final style = AppTextStyles.cardLabel.copyWith(color: labelSecondary);
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
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final valueStyle = AppTextStyles.cardAmount.copyWith(
      color: labelPrimary,
      fontWeight: FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              voce.descrizione,
              style: AppTextStyles.subtitle.copyWith(
                color: labelPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatNumber(voce.quantita),
              style: valueStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              voce.importo == 0 ? '—' : '€ ${formatNumber(voce.importo)}',
              style: valueStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyMessageRow(BuildContext context, String message) {
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      child: Text(
        message,
        style: AppTextStyles.subtitle.copyWith(color: labelSecondary),
      ),
    );
  }

  Widget _aggiungiVoceButton(Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onAggiungi,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.add_circled, color: accent, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text('Aggiungi voce',
                style: AppTextStyles.subtitle.copyWith(color: accent)),
          ],
        ),
      ),
    );
  }
}
