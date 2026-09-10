import 'package:flutter/cupertino.dart';

import '../models/busta_paga.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/busta_paga_formatting.dart';
import 'busta_paga_hero_card.dart';
import 'pulse_surface.dart';
import 'spring_button.dart';

/// Bottom sheet di sola lettura con i dati essenziali di una busta paga,
/// aperto al tap su un punto/barra/anello dei grafici in Statistiche
/// (drill-down, vedi CLAUDE.md/spec redesign 2026-09-08). Stesso pattern
/// `showCupertinoModalPopup` + `PulseSurface` già usato per i picker in
/// `busta_paga_detail_screen.dart` (`_pickPeriodo`/`_pickTipo`), non un
/// nuovo pattern di overlay.
Future<void> showBustaPagaDrilldown(
  BuildContext context,
  BustaPaga busta,
) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => _BustaPagaDrilldownSheet(busta: busta),
  );
}

class _BustaPagaDrilldownSheet extends StatelessWidget {
  final BustaPaga busta;

  const _BustaPagaDrilldownSheet({required this.busta});

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextSecondary, context);
    final accent = CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final isConfermato =
        busta.statoVerifica == StatoVerificaBustaPaga.confermato;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: SafeArea(
        top: false,
        child: PulseSurface(
          borderRadius: AppRadius.pulse,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BustaPagaHeroCard(
                isConfermato: isConfermato,
                periodoLabel: bustaPagaPeriodoDisplay(busta),
                lordoDisplay: formatEuroConSegno(busta.lordo),
                nettoDisplay: formatEuroConSegno(busta.netto),
              ),
              const SizedBox(height: AppSpacing.md),
              _RigaResiduo(
                label: 'Ferie residue',
                value: formatNumber(busta.ferieResidue),
                textSecondary: textSecondary,
              ),
              _RigaResiduo(
                label: 'Permessi residui',
                value: formatNumber(busta.rolResidui),
                textSecondary: textSecondary,
              ),
              _RigaResiduo(
                label: 'Ex festività residue',
                value: formatNumber(busta.exFestivitaResidue),
                textSecondary: textSecondary,
              ),
              const SizedBox(height: AppSpacing.lg),
              SpringButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.mdMinus,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppRadius.pulseSmall),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Chiudi',
                    style: AppTextStyles.pulseBodyEmphasis.copyWith(
                      color: accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RigaResiduo extends StatelessWidget {
  final String label;
  final String value;
  final Color textSecondary;

  const _RigaResiduo({
    required this.label,
    required this.value,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.pulseBody.copyWith(color: textSecondary)),
          Text(
            value,
            style: AppTextStyles.pulseBodyEmphasis.copyWith(color: textPrimary),
          ),
        ],
      ),
    );
  }
}
