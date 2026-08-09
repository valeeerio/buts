import 'package:flutter/cupertino.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'liquid_glass_surface.dart';
import 'spring_button.dart';

/// Card in evidenza per l'ultima busta paga in archivio: mese e netto
/// impilati a sinistra (pallino di stato + mese sopra, netto in evidenza
/// sotto), gruppetto compatto Ferie/Permessi/Ex fest. (`_StatTrio`, con
/// divisori verticali sottili tra le 3 colonne) a destra, centrato
/// verticalmente rispetto all'altezza combinata di mese+netto. Tap-only,
/// apre il dettaglio.
///
/// Usa `LiquidGlassSurface`, vedi `liquid_glass_surface.dart` per i dettagli
/// del materiale approssimato.
class BustaPagaSummaryHero extends StatelessWidget {
  final BustaPaga bustaPaga;
  final VoidCallback onTap;

  const BustaPagaSummaryHero({
    super.key,
    required this.bustaPaga,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final isConfermato =
        bustaPaga.statoVerifica == StatoVerificaBustaPaga.confermato;
    final statoColor = CupertinoDynamicColor.resolve(
      isConfermato ? AppColors.systemGreen : AppColors.systemRed,
      context,
    );

    return SpringButton(
      onPressed: onTap,
      child: LiquidGlassSurface(
        radius: AppRadius.glass,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin:
                              const EdgeInsets.only(right: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: statoColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bustaPagaMeseDisplay(bustaPaga),
                            style: AppTextStyles.subtitle.copyWith(
                              color: labelPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '€ ${formatNumber(bustaPaga.netto)}',
                      style: AppTextStyles.greeting.copyWith(
                        color: labelPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _StatTrio(
                items: [
                  ('Ferie', formatNumber(bustaPaga.ferieResidue)),
                  ('Permessi', formatNumber(bustaPaga.rolResidui)),
                  ('Ex fest.', formatNumber(bustaPaga.exFestivitaResidue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gruppetto compatto di 3 colonne (label sopra, valore sotto, entrambi
/// centrati), separate da divisori verticali sottili — dimensionato al
/// proprio contenuto (`MainAxisSize.min`), non a piena larghezza come
/// `BustaPagaStatRow`/`StatColumns`, pensati per un blocco a piena larghezza
/// con padding generoso.
class _StatTrio extends StatelessWidget {
  final List<(String label, String value)> items;

  const _StatTrio({required this.items});

  @override
  Widget build(BuildContext context) {
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final separator =
        CupertinoDynamicColor.resolve(AppColors.separator, context);

    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: separator,
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  items[i].$1,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardLabel.copyWith(
                    color: labelSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  items[i].$2,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardAmount.copyWith(
                    color: labelPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
