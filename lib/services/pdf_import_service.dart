import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum PdfImportStatus { success, cancelled, noExtractableText, error }

/// Esito della selezione/import di un PDF. In v1 sono supportati solo PDF
/// testuali (con testo selezionabile) — i PDF scansionati/immagine sono
/// esplicitamente fuori scope (nessun OCR), segnalati con
/// [PdfImportStatus.noExtractableText] invece di fallire silenziosamente.
class PdfImportResult {
  final PdfImportStatus status;
  final String? filePath;
  final String? extractedText;
  final String? errorMessage;

  const PdfImportResult._(
    this.status, {
    this.filePath,
    this.extractedText,
    this.errorMessage,
  });

  const PdfImportResult.success(String filePath, {String? extractedText})
      : this._(
          PdfImportStatus.success,
          filePath: filePath,
          extractedText: extractedText,
        );

  const PdfImportResult.cancelled() : this._(PdfImportStatus.cancelled);

  const PdfImportResult.noExtractableText()
      : this._(PdfImportStatus.noExtractableText);

  const PdfImportResult.error(String message)
      : this._(PdfImportStatus.error, errorMessage: message);
}

/// Import di un PDF busta paga: selezione tramite file picker di sistema,
/// validazione che il testo sia estraibile (niente OCR in v1, vedi
/// CLAUDE.md), copia nella cartella documenti locale dell'app
/// (`buste_paga_pdf/`, sotto-cartella dedicata dell'Application Documents
/// Directory) così il file resta disponibile anche se l'originale scelto
/// dall'utente viene spostato o cancellato altrove.
class PdfImportService {
  const PdfImportService();

  static const _pdfTypeGroup = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
    uniformTypeIdentifiers: ['com.adobe.pdf'],
  );

  Future<PdfImportResult> pickAndImport() async {
    final XFile? picked = await openFile(
      acceptedTypeGroups: const [_pdfTypeGroup],
    );
    if (picked == null) return const PdfImportResult.cancelled();

    try {
      final bytes = await picked.readAsBytes();

      final text = _extractText(bytes);
      // Soglia minima per distinguere un PDF testuale da uno scansionato
      // (che a volte espone comunque qualche carattere spurio di metadata).
      if (text == null || text.trim().length <= 20) {
        return const PdfImportResult.noExtractableText();
      }

      final targetPath = await _copyToAppDocuments(picked.name, bytes);
      return PdfImportResult.success(targetPath, extractedText: text);
    } catch (e) {
      return PdfImportResult.error(e.toString());
    }
  }

  String? _extractText(List<int> bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  Future<String> _copyToAppDocuments(
    String sourceFileName,
    List<int> bytes,
  ) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(documentsDir.path, 'buste_paga_pdf'));
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourceFileName)}';
    final targetFile = File(p.join(targetDir.path, fileName));
    await targetFile.writeAsBytes(bytes);
    return targetFile.path;
  }

  /// Rinomina (stessa cartella) il PDF di una mensilità supplementare col
  /// testo letterale della busta ("Mens.supplementare MM/YYYY"), "/" → "-"
  /// perché non valido in un nome file — al posto del nome scelto dal
  /// picker di sistema, spesso poco significativo (screenshot, export
  /// generico).
  Future<String> rinominaPerSupplementare(
    String currentPath, {
    required int mese,
    required int anno,
  }) async {
    final nuovoPercorso = p.join(
      p.dirname(currentPath),
      'Mens.supplementare $mese-$anno.pdf',
    );
    final nuovoFile = await File(currentPath).rename(nuovoPercorso);
    return nuovoFile.path;
  }
}
