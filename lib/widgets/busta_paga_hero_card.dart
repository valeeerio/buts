import 'package:flutter/cupertino.dart';

import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'liquid_glass_surface.dart';

/// Etichette del tipo busta paga usate per la visualizzazione nella hero
/// card. Stessa mappa duplicata nei picker `_pickTipo` di
/// `busta_paga_detail_screen.dart`/`busta_paga_form_screen.dart` (nessun
/// modulo condiviso per 3 stringhe).
const _tipoLabels = {
  TipoBustaPaga.mensile: 'Mensile',
  TipoBustaPaga.tredicesima: '13esima',
  TipoBustaPaga.quattordicesima: '14esima',
};

/// Hero card in cima al dettaglio/form busta paga: mese, badge di stato e
/// netto in massima evidenza. In modalità modifica il netto diventa un
/// campo di testo e il mese/tipo sono tap-to-edit (aprono i picker del
/// chiamante); il badge di stato resta sempre di sola lettura, non è
/// modificabile direttamente.
///
/// Layout: la prima riga affianca periodo e tipo inline (es. "Luglio 2026 ·
/// Mensile") con il badge di stato a destra; sotto, una riga a due colonne
/// mostra il Lordo (sinistra, sempre di sola lettura — è un valore derivato
/// da `competenze`, mai un campo editabile diretto, vedi CLAUDE.md) e il
/// Netto (destra, il valore "hero" vero e proprio, l'unico editabile in
/// modalità modifica).
///
/// Non richiede un `BustaPaga` intero: solo `isConfermato` per il badge
/// (il form di import, che non ha ancora una busta paga salvata, può così
/// passare `isConfermato: false` senza fabbricare un modello fittizio),
/// `lordoDisplay` e `nettoDisplay` (già formattati, senza simbolo "€") per
/// i valori di sola lettura — quest'ultimo mostrato solo quando
/// `nettoController` è `null`.
class BustaPagaHeroCard extends StatelessWidget {
  final bool isConfermato;
  final String periodoLabel;
  final TipoBustaPaga tipo;
  final bool isEditing;
  final String lordoDisplay;
  final String nettoDisplay;
  final TextEditingController? nettoController;
  final VoidCallback? onTapPeriodo;
  final VoidCallback? onTapTipo;

  const BustaPagaHeroCard({
    super.key,
    required this.isConfermato,
    required this.periodoLabel,
    required this.tipo,
    required this.isEditing,
    required this.lordoDisplay,
    required this.nettoDisplay,
    this.nettoController,
    this.onTapPeriodo,
    this.onTapTipo,
  });

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final badgeColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.systemGreen : AppColors.systemRed,
      context,
    );
    final heroAmountStyle =
        AppTextStyles.heroAmount.copyWith(color: labelPrimary);

    final lordoValueStyle = AppTextStyles.cardAmount.copyWith(
      color: labelPrimary,
      fontWeight: FontWeight.w400,
    );

    return LiquidGlassSurface(
      radius: AppRadius.glass,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    onTapPeriodo == null
                        ? Text(
                            periodoLabel,
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: labelPrimary,
                            ),
                          )
                        : GestureDetector(
                            onTap: onTapPeriodo,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  periodoLabel,
                                  style: AppTextStyles.sectionTitle.copyWith(
                                    color: labelPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Icon(CupertinoIcons.chevron_down,
                                    size: 16, color: labelSecondary),
                              ],
                            ),
                          ),
                    Text(
                      ' · ',
                      style:
                          AppTextStyles.cardLabel.copyWith(color: labelSecondary),
                    ),
                    onTapTipo == null
                        ? Text(
                            _tipoLabels[tipo]!,
                            style: AppTextStyles.cardLabel
                                .copyWith(color: labelSecondary),
                          )
                        : GestureDetector(
                            onTap: onTapTipo,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _tipoLabels[tipo]!,
                                  style: AppTextStyles.cardLabel
                                      .copyWith(color: labelSecondary),
                                ),
                                const SizedBox(width: 4),
                                Icon(CupertinoIcons.chevron_down,
                                    size: 12, color: labelSecondary),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  isConfermato ? 'Confermato' : 'Da confermare',
                  style: AppTextStyles.changeBadge.copyWith(color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lordo',
                      style: AppTextStyles.cardLabel
                          .copyWith(color: labelSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '€ $lordoDisplay',
                      style: lordoValueStyle,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: nettoController == null
                    ? Text(
                        '€ $nettoDisplay',
                        textAlign: TextAlign.right,
                        style: heroAmountStyle,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('€ ', style: heroAmountStyle),
                          Expanded(
                            child: CupertinoTextField(
                              controller: nettoController,
                              placeholder: '0',
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: false),
                              decoration: const BoxDecoration(),
                              padding: EdgeInsets.zero,
                              style: heroAmountStyle,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
