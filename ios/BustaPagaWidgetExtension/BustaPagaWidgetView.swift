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

/// Vista radice del widget: sceglie fra small/medium/stato "da importare" in
/// base alla famiglia corrente e ai dati dello snapshot. Nessuna logica di
/// business: solo lettura/presentazione dei campi già formattati arrivati da
/// Dart (`HomeWidgetService.aggiorna`).
struct BustaPagaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: BustaPagaWidgetSnapshot

    var body: some View {
        content
            .containerBackground(BustaPagaWidgetColors.background, for: .widget)
            .modifier(WidgetURLModifier(bustaId: linkableBustaId))
    }

    /// Solo se c'è un dato reale da aprire (id valido e non in stato "da
    /// importare") il widget diventa tappabile verso il dettaglio — nessun
    /// link quando i dati sono assenti/da importare.
    private var linkableBustaId: String? {
        guard snapshot.daImportare != true, let id = snapshot.bustaId, !id.isEmpty else {
            return nil
        }
        return id
    }

    @ViewBuilder
    private var content: some View {
        if snapshot.daImportare == true {
            DaImportareView()
        } else if snapshot.bustaId == nil {
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

/// Faccia "small": solo il netto dell'ultima busta paga.
private struct SmallView: View {
    let snapshot: BustaPagaWidgetSnapshot

    var body: some View {
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
                .font(.title3.weight(.bold))
                .foregroundColor(BustaPagaWidgetColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if snapshot.statoConfermato == false {
                StatoBadge(confermato: false)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Faccia "medium": netto + Ferie residue + Ex festività residue.
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

            VStack(alignment: .trailing, spacing: 10) {
                RateoValore(label: "Ferie residue", value: snapshot.ferieResidue)
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

/// Stato "da importare": mostrato al posto del netto quando manca un mese
/// secondo la logica reminder esistente (`reminder_schedule.dart`).
private struct DaImportareView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Buts")
                .font(.caption)
                .foregroundColor(BustaPagaWidgetColors.textSecondary)
            Spacer(minLength: 0)
            Text("Busta paga da importare")
                .font(.headline)
                .foregroundColor(BustaPagaWidgetColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Apri Buts per importare l'ultimo cedolino")
                .font(.caption2)
                .foregroundColor(BustaPagaWidgetColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
