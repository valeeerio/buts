import 'package:flutter/cupertino.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../services/pdf_path_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_alert_dialog.dart';
import 'liquid_glass_surface.dart';
import 'spring_button.dart';

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
        CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
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
    final accent = CupertinoDynamicColor.resolve(AppColors.systemBlue, context);
    final labelPrimary =
        CupertinoDynamicColor.resolve(AppColors.labelPrimary, context);

    return SpringButton(
      onPressed: () => _apri(context),
      child: LiquidGlassSurface(
        radius: AppRadius.glassSmall,
        blurSigma: 22,
        elevation: 4,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.doc_text, size: 20, color: accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                p.basename(filePath),
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.subtitle.copyWith(color: labelPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
