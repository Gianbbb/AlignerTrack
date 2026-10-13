import SwiftUI
import UIKit

public struct CycleHistoryView: View {
    @ObservedObject var dataManager: AlignerDataManager
    @State private var showingAddCycleSheet = false
    @State private var newCycleNumber = 1
    @State private var newCycleStartDate = Date()

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if dataManager.cycles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Nessun ciclo archiviato")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("I cicli completati e in corso appariranno qui.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(32)
                } else {
                    ForEach(dataManager.cycles.reversed()) { cycle in
                        CycleHistoryCard(cycle: cycle, dataManager: dataManager)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Storico Cicli")
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct CycleHistoryCard: View {
    let cycle: AlignerCycle
    @ObservedObject var dataManager: AlignerDataManager

    var body: some View {
        let analysis = dataManager.analyzeCycle(cycle)
        let isCurrent = dataManager.currentCycle?.id == cycle.id

        VStack(alignment: .leading, spacing: 14) {
            // Header: Numero Mascherina, Colore, Badge Stato
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: cycle.colorHex))
                        .frame(width: 14, height: 14)

                    Text("Mascherina #\(cycle.cycleNumber)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                if isCurrent {
                    Text("IN CORSO")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.emeraldMint.opacity(0.15))
                        .foregroundColor(Color.emeraldMint)
                        .cornerRadius(6)
                } else {
                    Text("COMPLETATA")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.secondary)
                        .cornerRadius(6)
                }
            }

            // Durata e Date
            VStack(alignment: .leading, spacing: 4) {
                Text("\(formatDate(cycle.startDate)) → \(formatDate(cycle.calculatedEndDate))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text("Durata: \(cycle.nominalDays) giorni base")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    if cycle.recoveryDays > 0 {
                        Text("(+\(cycle.recoveryDays) recupero = \(cycle.totalDays) totali)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }
            }

            Divider()

            // Statistiche ciclo
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ore Indossato")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    let hours = Int(analysis.totalWornSeconds / 3600)
                    Text("\(hours)h")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ritardo Accumulato")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    let deficitH = Int(analysis.totalDeficitSeconds / 3600)
                    Text("\(deficitH)h")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(deficitH > 5 ? .orange : Color.emeraldMint)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Giorni Recupero")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("+\(cycle.recoveryDays) gg")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(cycle.recoveryDays > 0 ? .orange : .secondary)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}
