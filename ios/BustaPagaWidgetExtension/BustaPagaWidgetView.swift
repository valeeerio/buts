import SwiftUI
import WidgetKit

/// Colori "dark forzato" del widget — coerenti a occhio con la palette
/// `pulseBackground`/`pulseSurface`/`pulseAccent`/`pulseTextPrimary`/
/// `pulseTextSecondary` dell'app (`lib/theme/app_colors.dart`), duplicati qui
/// come costanti statiche perché un'estensione WidgetKit non condivide il
/// codice Dart/Flutter dell'app — nessun calcolo di business, solo
/// presentazione.
private enum BustaPagaWidgetColors {
    static let background = Color(red: 0.04, green: 0.06, blue: 0.09)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.7)
    static let accent = Color(red: 0.0, green: 0.72, blue: 0.94)
}

/// Vista radice del widget: sceglie fra small/medium/stato "nessun dato" in
/// base alla famiglia corrente e ai dati dello snapshot — mostra sempre i
/// dati dell'ultima busta paga presente in archivio, indipendentemente da
/// quanto tempo è passato dall'ultimo import. Nessuna logica di business:
/// solo lettura/presentazione dei campi già formattati arrivati da Dart
/// (`HomeWidgetService.aggiorna`).
struct BustaPagaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: BustaPagaWidgetSnapshot

    var body: some View {
        content
            .containerBackground(BustaPagaWidgetColors.background, for: .widget)
            .modifier(WidgetURLModifier(bustaId: linkableBustaId))
    }

    /// Solo se c'è un dato reale da aprire (id valido) il widget diventa
    /// tappabile verso il dettaglio — nessun link quando i dati sono assenti.
    private var linkableBustaId: String? {
        guard let id = snapshot.bustaId, !id.isEmpty else {
            return nil
        }
        return id
    }

    @ViewBuilder
    private var content: some View {
        if snapshot.bustaId == nil {
            NessunDatoView()
        } else {
            switch family {
            case .systemMedium:
                MediumView(snapshot: snapshot)
            default:
                SmallView(snapshot: snapshot)
            }
        }
    }
}

/// Applica `.widgetURL` solo se [bustaId] non è `nil`, evitando di costruire
/// un `URL` non valido/superfluo quando il widget non deve essere
/// tappabile.
private struct WidgetURLModifier: ViewModifier {
    let bustaId: String?

    func body(content: Content) -> some View {
        if let bustaId, let url = URL(string: "buts://busta/\(bustaId)") {
            content.widgetURL(url)
        } else {
            content
        }
    }
}

/// Faccia "small": mese in cima, netto in evidenza al centro, riga
/// Ferie/Permessi in fondo separata da un divisore sottile — stesso spirito
/// di `_StatTrio` in `busta_paga_summary_hero.dart` (lettura, mai il fuoco
/// visivo del netto).
private struct SmallView: View {
    let snapshot: BustaPagaWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(snapshot.mese ?? "")
                    .font(.caption)
                    .foregroundColor(BustaPagaWidgetColors.textSecondary)
                    .lineLimit(1)
                Circle()
                    .fill(snapshot.statoConfermato == true ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }

            Spacer(minLength: 0)

            Text("Netto")
                .font(.caption2)
                .foregroundColor(BustaPagaWidgetColors.textSecondary)
            Text(snapshot.netto ?? "—")
                .font(.title3.weight(.bold))
                .foregroundColor(BustaPagaWidgetColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 0)

            Rectangle()
                .fill(BustaPagaWidgetColors.textSecondary.opacity(0.25))
                .frame(height: 1)

            HStack(spacing: 4) {
                SmallStatColumn(label: "Ferie", value: snapshot.ferieResidue)
                Rectangle()
                    .fill(BustaPagaWidgetColors.textSecondary.opacity(0.25))
                    .frame(width: 1)
                    .padding(.vertical, 2)
                SmallStatColumn(label: "Permessi", value: snapshot.permessiResidue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Colonna compatta etichetta/valore usata nella riga Ferie/Permessi della
/// faccia small — centrata, separata dalle colonne vicine da un divisore
/// verticale sottile disegnato dal chiamante.
private struct SmallStatColumn: View {
    let label: String
    let value: String?

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundColor(BustaPagaWidgetColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(value ?? "—")
                .font(.callout.weight(.semibold))
                .foregroundColor(BustaPagaWidgetColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Faccia "medium": netto + Ferie residue + Permessi residui + Ex festività
/// residue.
private struct MediumView: View {
    let snapshot: BustaPagaWidgetSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.mese ?? "")
                    .font(.caption)
                    .foregroundColor(BustaPagaWidgetColors.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("Netto")
                    .font(.caption2)
                    .foregroundColor(BustaPagaWidgetColors.textSecondary)
                Text(snapshot.netto ?? "—")
                    .font(.title2.weight(.bold))
                    .foregroundColor(BustaPagaWidgetColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if snapshot.statoConfermato == false {
                    StatoBadge(confermato: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 7) {
                RateoValore(label: "Ferie residue", value: snapshot.ferieResidue)
                RateoValore(label: "Permessi residui", value: snapshot.permessiResidue)
                RateoValore(label: "Ex festività residue", value: snapshot.exFestivitaResidue)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RateoValore: View {
    let label: String
    let value: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(BustaPagaWidgetColors.textSecondary)
            Text(value ?? "—")
                .font(.callout.weight(.semibold))
                .foregroundColor(BustaPagaWidgetColors.textPrimary)
        }
    }
}

private struct StatoBadge: View {
    let confermato: Bool

    var body: some View {
        Text(confermato ? "Confermato" : "Da confermare")
            .font(.caption2.weight(.medium))
            .foregroundColor(confermato ? .green : .red)
    }
}

/// Stato "nessun dato": nessuna busta paga mensile ancora in archivio (prima
/// esecuzione dell'app).
private struct NessunDatoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Buts")
                .font(.caption)
                .foregroundColor(BustaPagaWidgetColors.textSecondary)
            Spacer(minLength: 0)
            Text("Nessun dato")
                .font(.headline)
                .foregroundColor(BustaPagaWidgetColors.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
