import 'package:flutter/cupertino.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../services/pdf_path_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_alert_dialog.dart';
import 'pulse_icon.dart';
import 'pulse_surface.dart';

/// Riga compatta per il PDF di origine: icona documento e nome file. L'intera
/// card è tappabile (nessuna etichetta/icona "Apri" separata, il tap ovunque
/// sulla riga apre direttamente l'anteprima di sistema — Quick Look su iOS —
/// tramite `open_filex`. L'anteprima include già un bottone di condivisione
/// nativo, quindi non serve un'azione di condivisione separata in questo
/// widget. Sempre tappabile (dettaglio e form di import: il file è già
/// copiato su disco prima ancora che il form sia visibile, vedi
/// `PdfImportService`).
class BustaPagaDocumentoChip extends StatelessWidget {
  final String filePath;

  const BustaPagaDocumentoChip({super.key, required this.filePath});

  Future<void> _apri(BuildContext context) async {
    try {
      final absolutePath = await resolvePdfAbsolutePath(filePath);
      final result = await OpenFilex.open(absolutePath);
      if (result.type != ResultType.done && context.mounted) {
        _mostraErroreApertura(
          context,
          result.message.isNotEmpty
              ? result.message
              : 'Il PDF non è disponibile o non può essere aperto.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _mostraErroreApertura(
          context,
          'Il PDF non è disponibile o non può essere aperto.',
        );
      }
    }
  }

  void _mostraErroreApertura(BuildContext context, String messaggio) {
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    showAppAlertDialog<void>(
      context: context,
      title: 'Impossibile aprire il documento',
      message: messaggio,
      actions: [
        AppAlertAction(
          icon: CupertinoIcons.checkmark_alt,
          label: 'OK',
          color: accent,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        CupertinoDynamicColor.resolve(AppColors.pulseAccent, context);
    final textPrimary =
        CupertinoDynamicColor.resolve(AppColors.pulseTextPrimary, context);

    return Semantics(
      label: 'Apri documento PDF',
      button: true,
      child: PulseSurface(
        borderRadius: AppRadius.pulseSmall,
        onTap: () => _apri(context),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            PulseIcon(glyph: PulseIconGlyph.document, size: 20, color: accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                p.basename(filePath),
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.pulseBody.copyWith(color: textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
