import 'package:flutter/cupertino.dart';

/// Colori semantici stile Apple (system colors), con varianti Light/Dark.
class AppColors {
  AppColors._();

  // --- System semantic colors (Light / Dark) ---
  static const systemGreen = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF34C759),
    darkColor: Color(0xFF30D158),
  );
  static const systemBlue = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF007AFF),
    darkColor: Color(0xFF0A84FF),
  );
  static const systemPurple = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFAF52DE),
    darkColor: Color(0xFFBF5AF2),
  );
  static const systemOrange = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF9500),
    darkColor: Color(0xFFFF9F0A),
  );
  static const systemRed = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF3B30),
    darkColor: Color(0xFFFF453A),
  );

  // --- Backgrounds & surfaces ---
  static const backgroundPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF000000),
  );
  static const surface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );
  static const surfaceSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF2C2C2E),
  );

  // --- Labels (testo) ---
  static const labelPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF000000),
    darkColor: Color(0xFFFFFFFF),
  );
  static const labelSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0x993C3C43), // 60% opacity black
    darkColor: Color(0x99EBEBF5), // 60% opacity white
  );
  static const labelTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0x4D3C3C43), // 30% opacity black
    darkColor: Color(0x4DEBEBF5), // 30% opacity white
  );

  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0x4A3C3C43),
    darkColor: Color(0x99545458),
  );

  // --- Liquid Glass ---
  // Palette volutamente sobria/neutra: il materiale vetro è la fonte di
  // profondità, il colore resta riservato ad accenti puntuali (badge di
  // stato, CTA primaria) — coerente con le linee guida Apple sul Liquid
  // Glass ("usa il colore con parsimonia sopra il vetro"). Usati solo da
  // `LiquidGlassSurface`/`LiquidGlassButton`.

  /// Riempimento della superficie di vetro, sopra il blur. Resta chiaro e
  /// leggermente più opaco in light mode, più scuro/trasparente in dark
  /// mode senza mai diventare nero pieno (il vetro "regular" di Apple
  /// schiarisce leggermente anche sopra sfondi scuri).
  static const glassFill = CupertinoDynamicColor.withBrightness(
    color: Color(0xB3FFFFFF),
    darkColor: Color(0x40FFFFFF),
  );

  /// Riflesso speculare sul bordo (angolo in cui la luce "colpisce" il
  /// vetro): usato solo per lo stroke con gradiente del bordo, mai come
  /// riempimento pieno.
  static const glassHighlight = CupertinoDynamicColor.withBrightness(
    color: Color(0xCCFFFFFF),
    darkColor: Color(0x66FFFFFF),
  );

  /// Bordo in ombra, lato opposto al riflesso speculare.
  static const glassShadowEdge = CupertinoDynamicColor.withBrightness(
    color: Color(0x14000000),
    darkColor: Color(0x4D000000),
  );

  /// Scrim dietro `AppAlertDialog`: nero semi-trasparente, più opaco in dark
  /// mode per staccare la card piatta dal contenuto sottostante.
  static const alertBarrier = CupertinoDynamicColor.withBrightness(
    color: Color(0x66000000),
    darkColor: Color(0x99000000),
  );

  // --- Pulse ---
  // Nuova direzione visiva (vedi CLAUDE.md, "Stile visivo"): superfici piatte
  // a colore pieno, dark-first, accento ciano/cobalto elettrico. Dal
  // 2026-09-08 i valori dark sono quelli esatti già validati nel widget home
  // screen iOS (`ios/BustaPagaWidgetExtension/BustaPagaWidgetView.swift`,
  // `BustaPagaWidgetColors`) su richiesta esplicita dell'utente; i valori
  // light sono stati ricalcolati per preservare la stessa gerarchia e gli
  // stessi rapporti di contrasto minimi già in uso (vedi commenti di
  // ciascun token, rapporti calcolati con la formula di luminanza relativa
  // WCAG, non stimati).

  /// Sfondo pagina. Light: bianco/grigio molto chiaro e freddo (invariato).
  /// Dark: quasi-nero freddo — valore esatto del widget home screen.
  static const pulseBackground = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF4F6F8),
    darkColor: Color(0xFF0A0F17),
  );

  /// Superficie "tessera" (card, tile, riga di elenco): un grado più chiara
  /// dello sfondo in entrambi i temi. Dark derivato mantenendo lo stesso
  /// scarto per canale (+7,+8,+9) già usato prima di questo aggiornamento
  /// tra sfondo e superficie, applicato al nuovo `pulseBackground` dark (il
  /// widget non ha un concetto di superficie separata dallo sfondo).
  static const pulseSurface = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF111720),
  );

  /// Accento primario ciano/cobalto elettrico: CTA, valori di rilievo,
  /// riempimento pieno del blocco netto del mese, stati attivi in
  /// navigazione. Dark: valore esatto del widget (#00B8F0). Light:
  /// ricalcolato per la stessa hue, contrasto 4.06:1 su `pulseSurface`
  /// chiara — soglia testo grande/icone (WCAG), non corpo testo piccolo.
  static const pulseAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0089AC),
    darkColor: Color(0xFF00B8F0),
  );

  /// Testo/icone sopra un riempimento pieno di `pulseAccent`. Invariato:
  /// contrasto riverificato contro i nuovi valori di `pulseAccent` — 7.15:1
  /// dark, ≈4:1 light — entrambi confermati sopra soglia.
  static const pulseOnAccent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFBFEFF),
    darkColor: Color(0xFF00232B),
  );

  /// Testo primario sopra le superfici Pulse. Light invariato (quasi-nero).
  /// Dark: bianco puro, valore esatto del widget (era un bianco leggermente
  /// sporcato, #F5F8FA).
  static const pulseTextPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0E1420),
    darkColor: Color(0xFFFFFFFF),
  );

  /// Testo secondario/label sopra le superfici Pulse. Dark: grigio neutro,
  /// valore esatto del widget (#B3B3B3, non più grigio-bluastro). Light:
  /// ricalcolato come grigio neutro equivalente (stessa desaturazione),
  /// contrasto 5.74:1 su `pulseSurface` chiara.
  static const pulseTextSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF666666),
    darkColor: Color(0xFFB3B3B3),
  );

  /// Viola elettrico per accenti/gradienti decorativi (direzione
  /// "futuristica" derivata dal mockup B — vedi CLAUDE.md/piano sessione).
  /// Uso ESCLUSIVAMENTE decorativo: seconda serie/colore "Lordo" nei grafici
  /// Statistiche (`buste_paga_statistiche_screen.dart`), bordo a gradiente
  /// opzionale (`showGradientBorder`) di `ProgressRingTile`. MAI come colore
  /// funzionale di icone/testo/CTA — quel ruolo resta interamente a
  /// `pulseAccent` (ciano), che non cambia.
  static const pulseSecondaryGlow = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF6A3FD1),
    darkColor: Color(0xFF7C5CFF),
  );

  /// Variazione favorevole/stato positivo (es. "Confermato") sopra
  /// superfici Pulse: verde ricalibrato per contrasto adeguato sia su
  /// `pulseSurface` chiara sia scura, non il systemGreen Apple.
  static const pulsePositive = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1C9A5B),
    darkColor: Color(0xFF3DE08A),
  );

  /// Variazione sfavorevole/stato di attenzione (es. "Da confermare",
  /// alert) sopra superfici Pulse: rosso ricalibrato per contrasto adeguato
  /// sia su `pulseSurface` chiara sia scura, non il systemRed Apple.
  static const pulseNegative = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF04C41),
    darkColor: Color(0xFFFF6B61),
  );

  /// Testo sopra un riempimento pieno di `pulsePositive` (es. badge
  /// "Confermato"). Un testo bianco fisso non raggiunge 4.5:1 in nessuna
  /// combinazione (calcolato con la formula di luminanza relativa WCAG:
  /// 1.72:1 su `pulsePositive` dark, 3.61:1 su `pulsePositive` light) —
  /// entrambi i valori di `pulsePositive` sono verdi abbastanza chiari da
  /// dare invece ottimo contrasto con testo quasi-nero (10.73:1 dark, 5.11:1
  /// light), quindi qui la polarità è quasi-nero in entrambi i temi, non
  /// invertita come `pulseOnAccent`.
  static const pulseOnPositive = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0E1420),
    darkColor: Color(0xFF0E1420),
  );

  /// Testo sopra un riempimento pieno di `pulseNegative` (es. badge "Da
  /// confermare"). Stesso ragionamento di `pulseOnPositive`: bianco fisso
  /// insufficiente (2.79:1 dark, 3.61:1 light), testo quasi-nero invece
  /// raggiunge 6.61:1 dark e 5.10:1 light. `pulseNegative` light è stato
  /// leggermente schiarito (non scurito: il testo sopra è quasi-nero, quindi
  /// è allontanare lo sfondo dal nero — non avvicinarlo — che aumenta il
  /// contrasto) il 2026-08-28 per portare questo margine da 4.51:1, appena
  /// sopra soglia, a un margine di sicurezza reale ≥5:1.
  static const pulseOnNegative = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF0E1420),
    darkColor: Color(0xFF0E1420),
  );
}
