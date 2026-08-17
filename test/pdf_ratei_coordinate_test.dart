import 'package:buts/services/pdf_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copre `classificaRateiDaCoordinate` (`lib/services/pdf_import_service.dart`),
/// la parte PURA (nessuna dipendenza da Syncfusion/da un PDF reale) della
/// lettura per coordinate della tabella "RATEI" — l'euristica al centro del
/// fix delle buste paga 2025 che non leggevano Ferie/ROL, verificata finora
/// solo a mano su PDF reali.
///
/// Le [ParolaRateo] usate sotto sono costruite a mano con coppie
/// (testo, coordinate): NESSUNA fixture PDF, nessun dato anagrafico. Le
/// coordinate delle 5 colonne e delle 3 righe riprendono quelle empiriche
/// verificate su PDF reali (vedi doc su `_colonneBordoDestroX`/
/// `_rigaPerBordoSuperiore` in `pdf_import_service.dart`); i valori numerici
/// dei ratei (ore/giorni maturati/goduti/residui) in alcuni casi sotto
/// riprendono cedolini reali verificati manualmente, ma sono solo numeri
/// isolati — nessun nome, codice fiscale, indirizzo o importo di stipendio.
void main() {
  // Ancore X (bordo destro) delle 5 colonne della tabella "RATEI".
  const xResiduoAP = 113.6;
  const xMaturato = 151.8;
  const xGodutoAP = 190.1;
  const xGodutoAC = 229.7;
  const xResiduoTotali = 270.6;

  // Ancore Y (bordo superiore) delle 3 righe/categorie.
  const yFerie = 205.0;
  const yRol = 224.0;
  const yExFestivita = 244.0;

  ParolaRateo parola(String testo, {required double y, required double x}) =>
      (testo: testo, bordoSuperiore: y, bordoDestro: x);

  group('lettura posizionale delle 5 colonne (caso pieno/parziale)', () {
    test(
        '4 valori (Luglio 2026, ferie): AP/MATURATI/GODUTI A.P./RESIDUI '
        'TOTALI letti e assegnati alla colonna giusta', () {
      final risultato = classificaRateiDaCoordinate([
        parola('7,17', y: yFerie, x: xResiduoAP),
        parola('12,83', y: yFerie, x: xMaturato),
        parola('4,00', y: yFerie, x: xGodutoAP),
        parola('16,00', y: yFerie, x: xResiduoTotali),
      ]);

      expect(risultato.ferie.residuoAnnoPrecedente, 7.17);
      expect(risultato.ferie.maturato, 12.83);
      expect(risultato.ferie.goduto, 4.00);
      expect(risultato.ferie.residuo, 16.00);
      // Le altre 2 categorie restano vuote: nessuna parola alla loro riga.
      expect(risultato.rol.haAlmenoUnValore, isFalse);
      expect(risultato.exFestivita.haAlmenoUnValore, isFalse);
    });

    test(
        '2 valori (Agosto 2025, ROL): solo MATURATI e RESIDUI TOTALI, le '
        'colonne assenti restano null (non 0)', () {
      final risultato = classificaRateiDaCoordinate([
        parola('1,83', y: yRol, x: xMaturato),
        parola('1,83', y: yRol, x: xResiduoTotali),
      ]);

      expect(risultato.rol.residuoAnnoPrecedente, isNull);
      expect(risultato.rol.maturato, 1.83);
      expect(risultato.rol.goduto, isNull);
      expect(risultato.rol.residuo, 1.83);
    });

    test(
        '3 valori (Dicembre 2025, ex festività) con goduto in GODUTI A.C. '
        '(A.P. assente)', () {
      final risultato = classificaRateiDaCoordinate([
        parola('9,17', y: yExFestivita, x: xMaturato),
        parola('2,00', y: yExFestivita, x: xGodutoAC),
        parola('7,17', y: yExFestivita, x: xResiduoTotali),
      ]);

      expect(risultato.exFestivita.residuoAnnoPrecedente, isNull);
      expect(risultato.exFestivita.maturato, 9.17);
      expect(risultato.exFestivita.goduto, 2.00);
      expect(risultato.exFestivita.residuo, 7.17);
    });

    test('GODUTI A.P. e GODUTI A.C. entrambe valorizzate vengono sommate', () {
      final risultato = classificaRateiDaCoordinate([
        parola('3,00', y: yFerie, x: xGodutoAP),
        parola('2,50', y: yFerie, x: xGodutoAC),
      ]);

      expect(risultato.ferie.goduto, closeTo(5.50, 0.001));
    });

    test('parole di righe diverse non si mescolano fra categorie', () {
      final risultato = classificaRateiDaCoordinate([
        parola('12,83', y: yFerie, x: xMaturato),
        parola('9,17', y: yRol, x: xMaturato),
        parola('3,00', y: yExFestivita, x: xMaturato),
      ]);

      expect(risultato.ferie.maturato, 12.83);
      expect(risultato.rol.maturato, 9.17);
      expect(risultato.exFestivita.maturato, 3.00);
    });
  });

  group('cella vuota vs "0,00" effettivamente stampato', () {
    test('colonna assente dall\'input → campo null, non 0', () {
      final risultato = classificaRateiDaCoordinate([
        parola('12,83', y: yFerie, x: xMaturato),
        // Nessuna parola per RESIDUI TOTALI: colonna del tutto assente.
      ]);

      expect(risultato.ferie.residuo, isNull);
    });

    test('colonna presente con "0,00" → campo 0.0, distinto da assente', () {
      final risultato = classificaRateiDaCoordinate([
        parola('12,83', y: yFerie, x: xMaturato),
        parola('0,00', y: yFerie, x: xResiduoTotali),
      ]);

      expect(risultato.ferie.residuo, isNotNull);
      expect(risultato.ferie.residuo, 0.0);
    });

    test(
        'GODUTI A.P. presente con "0,00" e A.C. assente → goduto 0.0, non '
        'null (almeno una sotto-colonna è stata letta)', () {
      final risultato = classificaRateiDaCoordinate([
        parola('0,00', y: yRol, x: xGodutoAP),
      ]);

      expect(risultato.rol.goduto, isNotNull);
      expect(risultato.rol.goduto, 0.0);
    });
  });

  group('robustezza delle soglie', () {
    test(
        'un valore più lungo del solito ("123,45") resta nella colonna '
        'giusta: la classificazione guarda solo il bordo destro', () {
      final risultato = classificaRateiDaCoordinate([
        parola('123,45', y: yFerie, x: xMaturato),
      ]);

      expect(risultato.ferie.maturato, 123.45);
    });

    test(
        'X ben oltre la tolleranza di ogni colonna → parola ignorata, mai '
        'assegnata a una colonna sbagliata', () {
      final risultato = classificaRateiDaCoordinate([
        // 500 è ben oltre RESIDUI TOTALI (270.6, la colonna più a destra) +
        // la tolleranza massima (16pt).
        parola('99,99', y: yFerie, x: 500.0),
      ]);

      expect(risultato.ferie.haAlmenoUnValore, isFalse);
    });

    test(
        'Y fuori da ogni banda di riga → parola ignorata in tutte le 3 categorie',
        () {
      final risultato = classificaRateiDaCoordinate([
        parola('99,99', y: 400.0, x: xMaturato),
      ]);

      expect(risultato.ferie.haAlmenoUnValore, isFalse);
      expect(risultato.rol.haAlmenoUnValore, isFalse);
      expect(risultato.exFestivita.haAlmenoUnValore, isFalse);
    });

    test('bordo esatto fra Ferie e ROL (Y=217.0) va alla riga successiva (ROL)',
        () {
      final risultato = classificaRateiDaCoordinate([
        parola('5,00', y: 217.0, x: xMaturato),
      ]);

      expect(risultato.ferie.haAlmenoUnValore, isFalse);
      expect(risultato.rol.maturato, 5.00);
    });
  });

  group('degrado sicuro (tabella non riconoscibile)', () {
    test('lista vuota → 3 categorie vuote, nessuna eccezione', () {
      expect(() => classificaRateiDaCoordinate(const []), returnsNormally);

      final risultato = classificaRateiDaCoordinate(const []);
      expect(risultato.ferie.haAlmenoUnValore, isFalse);
      expect(risultato.rol.haAlmenoUnValore, isFalse);
      expect(risultato.exFestivita.haAlmenoUnValore, isFalse);
    });

    test(
        'solo testo non numerico (etichette di intestazione) → ignorato, '
        'nessuna eccezione', () {
      final risultato = classificaRateiDaCoordinate([
        parola('MATURATI', y: yFerie, x: xMaturato),
        parola('RESIDUI TOTALI', y: yFerie, x: xResiduoTotali),
        parola('FERIE', y: yFerie, x: xResiduoAP),
      ]);

      expect(risultato.ferie.haAlmenoUnValore, isFalse);
    });

    test(
        'layout completamente irriconoscibile (coordinate casuali fuori '
        'tabella) → tutte le categorie restano vuote', () {
      final risultato = classificaRateiDaCoordinate([
        parola('42,00', y: 10.0, x: 5.0),
        parola('7,50', y: 900.0, x: 900.0),
      ]);

      expect(risultato.ferie.haAlmenoUnValore, isFalse);
      expect(risultato.rol.haAlmenoUnValore, isFalse);
      expect(risultato.exFestivita.haAlmenoUnValore, isFalse);
    });
  });
}
