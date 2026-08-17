import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'liquid_glass_surface.dart';

/// Hero card in cima al dettaglio/form busta paga: mese, badge di stato e
/// netto in massima evidenza. In modalità modifica il mese/tipo sono
/// tap-to-edit (aprono i picker del chiamante); il badge di stato resta
/// sempre di sola lettura, non è modificabile direttamente. Il netto è
/// sempre un valore di sola lettura (derivato da lordo meno trattenute, mai
/// un campo editabile diretto).
///
/// Layout: la prima riga mostra il periodo (`periodoLabel`, es. "Luglio
/// 2026" o "14esima 2026" — il tipo, quando non è "Mensile", è già incluso
/// nel testo del periodo lato chiamante) con il badge di stato a destra. Il
/// testo del tipo non è mai mostrato separatamente accanto al periodo (per
/// ogni tipo, non solo "Mensile": mostrarlo di nuovo sarebbe sempre
/// ridondante col titolo). In modalità modifica (`onTapTipo != null`)
/// l'affordance di tap per cambiare tipo resta comunque raggiungibile per
/// qualunque tipo: al posto del testo compare solo la chevron tappabile,
/// mai testo. Sotto, una riga a due
/// colonne
/// centrate separate da un divisore verticale sottile (stesso stile di
/// `BustaPagaStatRow`) mostra il Lordo (sinistra, sempre di sola lettura — è
/// un valore derivato da `competenze`, mai un campo editabile diretto, vedi
/// CLAUDE.md) e il Netto (destra, il valore "hero" vero e proprio, anch'esso
/// sempre derivato/di sola lettura). Entrambe le colonne hanno la stessa
/// struttura (etichetta sopra, valore sotto); Lordo e Netto sono
/// visivamente identici in tutto (stesso stile `AppTextStyles.sectionTitle`,
/// 22pt, colore `labelPrimary`) — nessuna differenziazione tra i due, si
/// distinguono solo tramite l'etichetta sopra.
///
/// Non richiede un `BustaPaga` intero: solo `isConfermato` per il badge
/// (il form di import, che non ha ancora una busta paga salvata, può così
/// passare `isConfermato: false` senza fabbricare un modello fittizio),
/// `lordoDisplay` e `nettoDisplay` per i due valori — già formattati
/// COMPLETI di simbolo "€" e segno (`formatEuroConSegno` lato chiamante,
/// vedi `lib/utils/busta_paga_formatting.dart`): questo widget si limita a
/// mostrarli così come arrivano, senza anteporre un proprio "€ " fisso. Un
/// prefisso "€ " fisso qui produrrebbe un doppio segno per i valori
/// negativi (es. "€ -1.411,00" invece di "− € 1.411,00") — sia
/// `computeNetto` che `computeLordo` possono risultare negativi per
/// costruzione (trattenute superiori al lordo, storni/conguagli), non è
/// un caso ipotetico — bug reale corretto qui, non un'ipotesi.
class BustaPagaHeroCard extends StatelessWidget {
  final bool isConfermato;
  final String periodoLabel;
  final bool isEditing;
  final String lordoDisplay;
  final String nettoDisplay;
  final VoidCallback? onTapPeriodo;
  final VoidCallback? onTapTipo;

  const BustaPagaHeroCard({
    super.key,
    required this.isConfermato,
    required this.periodoLabel,
    required this.isEditing,
    required this.lordoDisplay,
    required this.nettoDisplay,
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
    final separator =
        CupertinoDynamicColor.resolve(AppColors.separator, context);
    final amountValueStyle =
        AppTextStyles.sectionTitle.copyWith(color: labelPrimary);

    final labelStyle =
        AppTextStyles.cardLabel.copyWith(color: labelSecondary);

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
                  children: [
                    Flexible(
                      child: onTapPeriodo == null
                          ? Text(
                              periodoLabel,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AppTextStyles.sectionTitle.copyWith(
                                color: labelPrimary,
                              ),
                            )
                          : Semantics(
                              label: 'Cambia periodo',
                              button: true,
                              child: GestureDetector(
                                onTap: onTapPeriodo,
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        periodoLabel,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: AppTextStyles.sectionTitle
                                            .copyWith(color: labelPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Icon(CupertinoIcons.chevron_down,
                                        size: 16, color: labelSecondary),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    if (onTapTipo != null)
                      Semantics(
                        label: 'Cambia tipo busta paga',
                        button: true,
                        child: GestureDetector(
                          onTap: onTapTipo,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(CupertinoIcons.chevron_down,
                                size: 12, color: labelSecondary),
                          ),
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lordo',
                        textAlign: TextAlign.center,
                        style: labelStyle,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          lordoDisplay,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: amountValueStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 0.5,
                  margin:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  color: separator,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Netto',
                        textAlign: TextAlign.center,
                        style: labelStyle,
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          nettoDisplay,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: amountValueStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
