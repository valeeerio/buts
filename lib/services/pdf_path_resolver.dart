import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Cartella, relativa alla Application Documents Directory, dove
/// `PdfImportService` copia i PDF importati.
const pdfBusteDirName = 'buste_paga_pdf';

/// Risolve un percorso di PDF busta paga (salvato in `BustaPaga.fileOrigine`)
/// nel path assoluto valido nella sessione corrente dell'app.
///
/// I path salvati possono essere relativi (`buste_paga_pdf/<file>.pdf`, il
/// formato usato dagli import più recenti) oppure assoluti "vecchio stile"
/// da import precedenti a questo fix, che includevano il prefisso della
/// Application Documents Directory di allora — su iOS quel prefisso
/// contiene l'UUID del container sandbox, che cambia ad ogni
/// reinstallazione dell'app, rendendo il path salvato invalido anche se il
/// file fisico esiste ancora (sotto un nuovo prefisso). Per essere
/// resilienti a questo, estraiamo sempre la parte relativa (a partire da
/// `buste_paga_pdf/`) e la ricomponiamo con la Documents Directory
/// ATTUALE, ignorando qualunque prefisso assoluto eventualmente salvato —
/// funziona sia per i path già relativi sia per quelli vecchi assoluti,
/// senza bisogno di alcuna migrazione dei dati esistenti.
Future<String> resolvePdfAbsolutePath(String storedPath) async {
  final documentsDir = await getApplicationDocumentsDirectory();
  return p.join(documentsDir.path, _relativePart(storedPath));
}

String _relativePart(String storedPath) {
  final normalized = storedPath.replaceAll('\\', '/');
  const marker = '$pdfBusteDirName/';
  final idx = normalized.indexOf(marker);
  if (idx == -1) {
    return p.join(pdfBusteDirName, p.basename(storedPath));
  }
  return normalized.substring(idx);
}
