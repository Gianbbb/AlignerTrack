import SwiftUI
import UIKit

public struct StatsView: View {
    @ObservedObject var dataManager: AlignerDataManager
    @State private var timeRange: StatsTimeRange = .last14Days

    public enum StatsTimeRange: String, CaseIterable, Identifiable {
        case last7Days = "7 Giorni"
        case last14Days = "14 Giorni (Ciclo)"
        case last30Days = "30 Giorni"

        public var id: String { rawValue }

        public var dayCount: Int {
            switch self {
            case .last7Days: return 7
            case .last14Days: return 14
            case .last30Days: return 30
            }
        }
    }

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Selettore Range
                    Picker("Periodo", selection: $timeRange) {
                        ForEach(StatsTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    // Metriche Chiave
                    let stats = calculateRangeStats(daysCount: timeRange.dayCount)
                    KeyMetricsGrid(stats: stats)

                    // Grafico a Barre Giornaliero
                    DailyBreakdownChartCard(daysData: stats.daysData)

                    // Tabella Storica Dettagliata per Giorno
                    DailyBreakdownTableCard(daysData: stats.daysData)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Statistiche")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }

    // MARK: - Calculation Helper
    struct DayStatItem: Identifiable {
        let id = UUID()
        let date: Date
        let wornHours: Double
        let removedHours: Double
        let metGoal: Bool
    }

    struct RangeStats {
        let avgWornHoursPerDay: Double
        let avgRemovedHoursPerDay: Double
        let goalAchievementRate: Double
        let totalSessionsCount: Int
        let daysData: [DayStatItem]
    }

    private func calculateRangeStats(daysCount: Int) -> RangeStats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var items: [DayStatItem] = []
        var totalWorn: Double = 0
        var totalRemoved: Double = 0
        var daysWithGoalMet: Int = 0

        for offset in (0..<daysCount).reversed() {
            if let date = cal.date(byAdding: .day, value: -offset, to: today) {
                let wornSec = dataManager.wornSeconds(for: date)
                let removedSec = dataManager.removedSeconds(for: date)
                let wornH = wornSec / 3600.0
                let removedH = removedSec / 3600.0
                let met = wornSec >= dataManager.dailyTargetWearSeconds

                items.append(DayStatItem(
                    date: date,
                    wornHours: wornH,
                    removedHours: removedH,
                    metGoal: met
                ))

                totalWorn += wornH
                totalRemoved += removedH
                if met { daysWithGoalMet += 1 }
            }
        }

        let avgWorn = daysCount > 0 ? totalWorn / Double(daysCount) : 0
        let avgRemoved = daysCount > 0 ? totalRemoved / Double(daysCount) : 0
        let rate = daysCount > 0 ? (Double(daysWithGoalMet) / Double(daysCount)) * 100.0 : 0

        return RangeStats(
            avgWornHoursPerDay: avgWorn,
            avgRemovedHoursPerDay: avgRemoved,
            goalAchievementRate: rate,
            totalSessionsCount: dataManager.sessions.count,
            daysData: items
        )
    }
}

// MARK: - Key Metrics Grid
struct KeyMetricsGrid: View {
    let stats: StatsView.RangeStats

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "Media Indossato",
                value: String(format: "%.1fh", stats.avgWornHoursPerDay),
                target: "Target: 22h",
                icon: "shield.lefthalf.filled",
                color: stats.avgWornHoursPerDay >= 22 ? Color.emeraldMint : .orange
            )

            MetricCard(
                title: "Media Tolto",
                value: String(format: "%.1fh", stats.avgRemovedHoursPerDay),
                target: "Max: 2h/die",
                icon: "pause.circle.fill",
                color: stats.avgRemovedHoursPerDay <= 2 ? Color.emeraldMint : .red
            )

            MetricCard(
                title: "Conformità Target",
                value: String(format: "%.0f%%", stats.goalAchievementRate),
                target: "Giorni >= 22h",
                icon: "checkmark.seal.fill",
                color: stats.goalAchievementRate >= 80 ? Color.emeraldMint : .orange
            )

            MetricCard(
                title: "Pasti Totali",
                value: "\(stats.totalSessionsCount)",
                target: "Rimozioni registrate",
                icon: "fork.knife",
                color: .blue
            )
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let target: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Spacer()
            }

            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(target)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - Daily Breakdown Chart Card
struct DailyBreakdownChartCard: View {
    let daysData: [StatsView.DayStatItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Andamento Ore al Giorno")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.emeraldMint).frame(width: 8, height: 8)
                        Text("Indossato").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                        Text("Tolto").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
            }

            // Visualizzazione grafica barre
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(daysData) { item in
                    VStack(spacing: 4) {
                        // Barra ore (massimo 24h)
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 110)

                            VStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange)
                                    .frame(height: max(3, CGFloat(min(24, item.removedHours) / 24.0) * 110))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.emeraldMint)
                                    .frame(height: max(3, CGFloat(min(24, item.wornHours) / 24.0) * 110))
                            }
                        }

                        // Etichetta giorno
                        Text(formatDayShort(item.date))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 135)

            // Linea Target di Riferimento 22h
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.emeraldMint.opacity(0.5))
                    .frame(width: 20, height: 2)
                Text("Target medico ottimale: 22h al giorno (linea verde)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }

    private func formatDayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d/M"
        return f.string(from: date)
    }
}

// MARK: - Daily Breakdown Table Card
struct DailyBreakdownTableCard: View {
    let daysData: [StatsView.DayStatItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dettaglio Giornaliero")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                ForEach(daysData.reversed()) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatDayFull(item.date))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)

                            Text(item.metGoal ? "Obiettivo 22h Raggiunto" : "Sotto obiettivo")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(item.metGoal ? Color.emeraldMint : .orange)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 8) {
                                Text("\(formatHours(item.wornHours)) tenuto")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundColor(item.metGoal ? Color.emeraldMint : .primary)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Text("\(formatHours(item.removedHours)) tolto")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(item.removedHours > 2.0 ? .red : .orange)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    )
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

    private func formatDayFull(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: d).capitalized
    }

    private func formatHours(_ h: Double) -> String {
        let hours = Int(h)
        let mins = Int((h - Double(hours)) * 60)
        return "\(hours)h \(mins)m"
    }
}
