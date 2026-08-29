# Font bundlati offline — Pulse

Font usati dal sistema visivo "Pulse" (vedi `CLAUDE.md`, sezione "Stile
visivo"). Licenza SIL Open Font License 1.1 per entrambe le famiglie (vedi
`OFL-SpaceGrotesk.txt` / `OFL-Inter.txt` in questa cartella).

File presenti in questa cartella (istanze statiche generate dai file
variabili ufficiali del repo `google/fonts` con `fonttools varLib.instancer`,
ai pesi dichiarati in `pubspec.yaml`):

- `SpaceGrotesk-Medium.ttf` (peso 500)
- `SpaceGrotesk-Bold.ttf` (peso 700)
- `SpaceGrotesk-ExtraBold.ttf` (peso 800)
- `Inter-Regular.ttf` (peso 400)
- `Inter-Medium.ttf` (peso 500)
- `Inter-SemiBold.ttf` (peso 600)

Se in futuro servisse rigenerarli o aggiungere altri pesi, i file variabili
sorgente sono su:

- Space Grotesk: https://fonts.google.com/specimen/Space+Grotesk (o
  `https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf`)
- Inter: https://fonts.google.com/specimen/Inter (o
  `https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf`)

Per estrarre un'istanza statica da un file variabile:

```
pip install fonttools
fonttools varLib.instancer -q --update-name-table \
  -o SpaceGrotesk-Medium.ttf "SpaceGrotesk[wght].ttf" wght=500
```

(per Inter, che ha anche l'asse `opsz`, fissare anche `opsz=14`, es.
`wght=400 opsz=14`).

Le dichiarazioni corrispondenti sono in `pubspec.yaml` sotto `flutter: fonts:`
con i nomi famiglia `'Space Grotesk'` e `'Inter'`, usati da
`lib/theme/app_text_styles.dart`.
