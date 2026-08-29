import 'package:buts/models/busta_paga.dart';
import 'package:buts/widgets/busta_paga_documento_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Regressione: `bustaPagaDocumentoLabel` deve usare la forma abbreviata
/// "13esima"/"14esima" (coerente con `tipoMensilitaLabel`/`periodoDisplayFor`
/// in `utils/busta_paga_formatting.dart` e con `buste_paga_archivio_view
/// .dart`), non la forma estesa "Tredicesima"/"Quattordicesima" usata da
/// nessun'altra parte dell'app.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  group('bustaPagaDocumentoLabel', () {
    test('mensile produce "Cedolino <Mese> <Anno>"', () {
      final label = bustaPagaDocumentoLabel(
        periodo: DateTime(2026, 8, 1),
        tipo: TipoBustaPaga.mensile,
      );
      expect(label, 'Cedolino Agosto 2026');
    });

    test('tredicesima usa la forma abbreviata "13esima"', () {
      final label = bustaPagaDocumentoLabel(
        periodo: DateTime(2026, 12, 1),
        tipo: TipoBustaPaga.tredicesima,
      );
      expect(label, 'Cedolino 13esima 2026');
      expect(label, isNot(contains('Tredicesima')));
    });

    test('quattordicesima usa la forma abbreviata "14esima"', () {
      final label = bustaPagaDocumentoLabel(
        periodo: DateTime(2026, 7, 1),
        tipo: TipoBustaPaga.quattordicesima,
      );
      expect(label, 'Cedolino 14esima 2026');
      expect(label, isNot(contains('Quattordicesima')));
    });
  });
}
