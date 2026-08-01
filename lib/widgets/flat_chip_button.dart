import 'package:flutter/cupertino.dart';

import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'spring_button.dart';

/// Chip piatto (icona + etichetta), senza superficie di vetro: componente
/// condiviso tra la barra "Conferma/Modifica" del dettaglio busta paga e i
/// segmenti Archivio/Statistiche della sidecar in basso — stessa identica
/// resa visiva in entrambi i punti dell'app.
///
/// [filled] controlla il riempimento a colore pieno (bassa opacità) più
/// bordo arrotondato: `true` per un'azione sempre "premuta" (es. i due
/// bottoni del dettaglio), `false` per uno stato non selezionato (es. il
/// tab non attivo nella sidecar), che resta solo icona+testo colorati senza
/// sfondo.
///
/// [icon] è opzionale: `null` per i bottoni dei popup (`AppAlertDialog`),
/// che non hanno mai avuto un'icona nello stile nativo iOS che sostituiscono
/// — solo testo colorato sul chip pieno.
class FlatChipButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  const FlatChipButton({
    super.key,
    this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SpringButton(
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 4),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(AppRadius.glassSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTextStyles.cardAmount.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
