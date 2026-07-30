import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'liquid_glass_surface.dart';
import 'spring_button.dart';

/// Card in evidenza per l'ultima busta paga in archivio: periodo formattato
/// e netto ben visibile. Tap-only, apre il dettaglio.
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

  String get _periodoLabel {
    final formatted =
        DateFormat('MMMM yyyy', 'it_IT').format(bustaPaga.periodo);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);
    final labelSecondary =
        CupertinoDynamicColor.resolve(AppColors.labelSecondary, context);
    final accent = CupertinoDynamicColor.resolve(AppColors.bustePaga, context);

    return SpringButton(
      onPressed: onTap,
      child: LiquidGlassSurface(
        radius: AppRadius.glass,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.doc_text, size: 18, color: accent),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Ultima busta paga',
                    style: AppTextStyles.cardLabel.copyWith(
                      color: labelSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _periodoLabel,
                style: AppTextStyles.subtitle.copyWith(
                  color: labelSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '€ ${bustaPaga.netto.toStringAsFixed(2)}',
                style: AppTextStyles.greeting.copyWith(color: labelPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
