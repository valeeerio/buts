import 'package:buts/models/busta_paga.dart';
import 'package:buts/services/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Costruisce una [BustaPaga] minimale, valorizzando solo i campi rilevanti
/// per questi test ([periodo]/[tipo]) e riempiendo gli altri required con
/// valori neutri.
BustaPaga _busta({
  required DateTime periodo,
  TipoBustaPaga tipo = TipoBustaPaga.mensile,
}) {
  return BustaPaga(
    id: 'periodo-${periodo.year}-${periodo.month}-$tipo',
    periodo: periodo,
    lordo: 0,
    netto: 0,
    trattenute: const {},
    straordinari: 0,
    ferieMaturate: 0,
    ferieGodute: 0,
    ferieResidue: 0,
    rolMaturati: 0,
    rolGoduti: 0,
    rolResidui: 0,
    permessiGoduti: 0,
    oreLavorate: 0,
    tipo: tipo,
  );
}

void main() {
  group('targetPerCiclo', () {
    test('punta al mese precedente nello stesso anno', () {
      expect(
        targetPerCiclo(DateTime(2026, 8, 1)),
        equals((anno: 2026, mese: 7)),
      );
    });

    test('gennaio punta a dicembre dell\'anno precedente', () {
      expect(
        targetPerCiclo(DateTime(2027, 1, 1)),
        equals((anno: 2026, mese: 12)),
      );
    });

    test('non dipende dal giorno del mese, solo da anno/mese', () {
      expect(
        targetPerCiclo(DateTime(2026, 8, 20, 15, 30)),
        equals((anno: 2026, mese: 7)),
      );
    });
  });

  group('periodiMensiliImportati', () {
    test('archivio vuoto produce un set vuoto', () {
      expect(periodiMensiliImportati(const []), isEmpty);
    });

    test('include solo le buste di tipo mensile', () {
      final buste = [
        _busta(periodo: DateTime(2026, 6, 27)),
        _busta(periodo: DateTime(2026, 7, 28)),
      ];

      expect(
        periodiMensiliImportati(buste),
        equals({(anno: 2026, mese: 6), (anno: 2026, mese: 7)}),
      );
    });

    test(
        'una tredicesima o quattordicesima non compare nel set, anche se '
        'il suo periodo coincide con un mese cercato', () {
      final buste = [
        _busta(periodo: DateTime(2026, 8, 15), tipo: TipoBustaPaga.tredicesima),
        _busta(
            periodo: DateTime(2026, 8, 20),
            tipo: TipoBustaPaga.quattordicesima),
      ];

      expect(periodiMensiliImportati(buste), isEmpty);
      expect(
        periodiMensiliImportati(buste).contains((anno: 2026, mese: 8)),
        isFalse,
      );
    });
  });

  group('promemoriaDaSchedulare', () {
    test(
        'a inizio mese, prima delle 9, tutte e tre le date del ciclo '
        'corrente sono incluse se il target non è importato', () {
      final ora = DateTime(2026, 8, 1, 0, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      final cicloAgosto =
          risultato.where((d) => d.year == 2026 && d.month == 8).toList();

      expect(
        cicloAgosto,
        equals([
          DateTime(2026, 8, 1, 9),
          DateTime(2026, 8, 8, 9),
          DateTime(2026, 8, 15, 9),
        ]),
      );
    });

    test(
        'dopo il giorno 15, il ciclo del mese corrente è esaurito (nessuna '
        'data) e NON conta come uno dei cicliAvanti: l\'orizzonte si '
        'allunga di un mese per compensare, invece di accorciarsi', () {
      final ora = DateTime(2026, 8, 20, 12, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      final cicloAgosto =
          risultato.where((d) => d.year == 2026 && d.month == 8);
      expect(cicloAgosto, isEmpty);

      // Con il ciclo di agosto "non utile" (esaurito solo per il tempo
      // trascorso), l'orizzonte si allunga a settembre + ottobre +
      // novembre (i tre cicli utili successivi), 3 date ciascuno: 9 in
      // tutto, non 6 — altrimenti l'orizzonte reale scenderebbe sotto i
      // due mesi dichiarati da cicliAvanti.
      expect(risultato.length, 9);
      expect(risultato.first, DateTime(2026, 9, 1, 9));
      expect(risultato.last, DateTime(2026, 11, 15, 9));
    });

    test(
        'anche a fine mese (dopo il 15) l\'orizzonte reale copre sempre '
        'cicliAvanti cicli utili, non meno', () {
      // Regressione del bug per cui l'orizzonte si accorciava
      // progressivamente nella seconda metà di ogni mese.
      final ora = DateTime(2026, 8, 31, 23, 59);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      final mesiConDate =
          risultato.map((d) => (anno: d.year, mese: d.month)).toSet();
      expect(mesiConDate.length, cicliAvanti);
      expect(risultato.length, cicliAvanti * giorniPromemoria.length);
    });

    test(
        'lo stesso giorno di un promemoria, prima delle 9, la data è '
        'inclusa perché ancora strettamente futura', () {
      final ora = DateTime(2026, 8, 1, 8, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      expect(risultato, contains(DateTime(2026, 8, 1, 9)));
    });

    test(
        'lo stesso giorno di un promemoria, dopo le 9, la data è esclusa '
        '(non più strettamente futura), le successive restano', () {
      final ora = DateTime(2026, 8, 1, 10, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      expect(risultato, isNot(contains(DateTime(2026, 8, 1, 9))));
      expect(risultato, contains(DateTime(2026, 8, 8, 9)));
      expect(risultato, contains(DateTime(2026, 8, 15, 9)));
    });

    test(
        'all\'istante esatto delle 9:00 la data non è strettamente futura '
        '(isAfter esclude l\'uguaglianza) ed è quindi esclusa', () {
      final ora = DateTime(2026, 8, 1, 9, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      expect(risultato, isNot(contains(DateTime(2026, 8, 1, 9))));
      expect(risultato, contains(DateTime(2026, 8, 8, 9)));
      expect(risultato, contains(DateTime(2026, 8, 15, 9)));
    });

    test(
        'un ciclo esaurito per il tempo e un ciclo saltato per import già '
        'presente si distinguono: solo il secondo conta come utile, il '
        'primo allunga comunque l\'orizzonte', () {
      final ora = DateTime(2026, 8, 20, 12, 0);
      // Target del ciclo di ottobre è settembre 2026: lo segniamo come già
      // importato, quindi ottobre viene saltato deliberatamente (conta
      // comunque come ciclo utile). Il ciclo di agosto, invece, non conta
      // perché è solo esaurito per il tempo trascorso (dopo il 15): la
      // combinazione dei due effetti allunga l'orizzonte fino a novembre.
      final periodiImportati = {(anno: 2026, mese: 9)};

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: periodiImportati,
      );

      final cicloAgosto =
          risultato.where((d) => d.year == 2026 && d.month == 8);
      final cicloOttobre =
          risultato.where((d) => d.year == 2026 && d.month == 10);
      expect(cicloAgosto, isEmpty);
      expect(cicloOttobre, isEmpty);

      final cicloSettembre =
          risultato.where((d) => d.year == 2026 && d.month == 9).toList();
      final cicloNovembre =
          risultato.where((d) => d.year == 2026 && d.month == 11).toList();
      expect(
          cicloSettembre,
          equals([
            DateTime(2026, 9, 1, 9),
            DateTime(2026, 9, 8, 9),
            DateTime(2026, 9, 15, 9),
          ]));
      expect(
          cicloNovembre,
          equals([
            DateTime(2026, 11, 1, 9),
            DateTime(2026, 11, 8, 9),
            DateTime(2026, 11, 15, 9),
          ]));
      expect(risultato.length, 6);
    });

    test(
        'se la busta target del ciclo è già importata, l\'intero ciclo è '
        'saltato, ma i cicli successivi restano', () {
      final ora = DateTime(2026, 8, 1, 0, 0);
      // Cicli in finestra: agosto (target luglio 2026), settembre (target
      // agosto 2026), ottobre (target settembre 2026). Segniamo come
      // importato il target di settembre.
      final periodiImportati = {(anno: 2026, mese: 8)};

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: periodiImportati,
      );

      final cicloSettembre =
          risultato.where((d) => d.year == 2026 && d.month == 9);
      expect(cicloSettembre, isEmpty);

      final cicloAgosto =
          risultato.where((d) => d.year == 2026 && d.month == 8).toList();
      final cicloOttobre =
          risultato.where((d) => d.year == 2026 && d.month == 10).toList();

      expect(
          cicloAgosto,
          equals([
            DateTime(2026, 8, 1, 9),
            DateTime(2026, 8, 8, 9),
            DateTime(2026, 8, 15, 9),
          ]));
      expect(
          cicloOttobre,
          equals([
            DateTime(2026, 10, 1, 9),
            DateTime(2026, 10, 8, 9),
            DateTime(2026, 10, 15, 9),
          ]));
    });

    test(
        'se la busta target del ciclo non è importata, tutte e tre le date '
        'future del ciclo sono schedulate', () {
      final ora = DateTime(2026, 8, 1, 0, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      final cicloSettembre =
          risultato.where((d) => d.year == 2026 && d.month == 9).toList();

      expect(
          cicloSettembre,
          equals([
            DateTime(2026, 9, 1, 9),
            DateTime(2026, 9, 8, 9),
            DateTime(2026, 9, 15, 9),
          ]));
    });

    test('la finestra di 3 cicli attraversa correttamente il cambio d\'anno',
        () {
      final ora = DateTime(2026, 11, 1, 0, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: const {},
      );

      // Cicli attesi: novembre 2026, dicembre 2026, gennaio 2027.
      expect(risultato.length, 9);
      expect(risultato, contains(DateTime(2026, 11, 1, 9)));
      expect(risultato, contains(DateTime(2026, 12, 15, 9)));
      expect(risultato, contains(DateTime(2027, 1, 1, 9)));
      expect(risultato, contains(DateTime(2027, 1, 15, 9)));
      expect(risultato.last, DateTime(2027, 1, 15, 9));
    });

    test(
        'una tredicesima/quattordicesima in archivio per il mese target non '
        'fa saltare il ciclo mensile corrispondente', () {
      final buste = [
        _busta(periodo: DateTime(2026, 8, 15), tipo: TipoBustaPaga.tredicesima),
      ];
      final periodiImportati = periodiMensiliImportati(buste);
      final ora = DateTime(2026, 8, 1, 0, 0);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: periodiImportati,
      );

      // Il ciclo di settembre punta al target (2026, 8): la sola presenza
      // di una tredicesima con quel periodo non deve saltarlo.
      final cicloSettembre =
          risultato.where((d) => d.year == 2026 && d.month == 9);
      expect(cicloSettembre, isNotEmpty);
    });

    test('archivio vuoto: nessun ciclo viene saltato', () {
      final ora = DateTime(2026, 8, 1, 0, 0);
      final periodiImportati = periodiMensiliImportati(const []);

      final risultato = promemoriaDaSchedulare(
        ora: ora,
        periodiImportati: periodiImportati,
      );

      expect(risultato.length, 9);
    });
  });
}
