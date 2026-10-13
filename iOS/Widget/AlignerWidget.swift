import WidgetKit
import SwiftUI
import AppIntents
import UIKit

// MARK: - Timeline Entry
public struct AlignerEntry: TimelineEntry {
    public let date: Date
    public let isRemoved: Bool
    public let removalStartTime: Date?
    public let todayRemovedSeconds: Int
    public let todayWornSeconds: Int
    public let cycleNumber: Int
    public let cycleColorHex: String
}

// MARK: - Timeline Provider
public struct AlignerTimelineProvider: TimelineProvider {
    public func placeholder(in context: Context) -> AlignerEntry {
        AlignerEntry(
            date: Date(),
            isRemoved: false,
            removalStartTime: nil,
            todayRemovedSeconds: 45 * 60,
            todayWornSeconds: 1275 * 60,
            cycleNumber: 1,
            cycleColorHex: "#00A896"
        )
    }

    public func getSnapshot(in context: Context, completion: @escaping (AlignerEntry) -> Void) {
        completion(fetchCurrentEntry())
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<AlignerEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        // Aggiorna ogni 15 minuti se non ci sono interazioni manuali
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchCurrentEntry() -> AlignerEntry {
        let defaults: UserDefaults
        if let shared = UserDefaults(suiteName: AppGroupConstants.groupIdentifier) {
            defaults = shared
        } else {
            defaults = UserDefaults.standard
        }

        let isRemoved = defaults.bool(forKey: AppGroupConstants.stateKey)
        let startTime = defaults.object(forKey: AppGroupConstants.removalStartTimeKey) as? Date

        // Calcola secondi precisi rimossi oggi (senza arrotondamenti ad 1 minuto)
        var removedSeconds: TimeInterval = 0
        if let data = defaults.data(forKey: AppGroupConstants.sessionsKey),
           let sessions = try? JSONDecoder().decode([RemovalSession].self, from: data) {
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()

            for s in sessions {
                let overlapStart = max(todayStart, s.startDate)
                let overlapEnd = min(todayEnd, s.endDate)
                if overlapEnd > overlapStart {
                    removedSeconds += overlapEnd.timeIntervalSince(overlapStart)
                }
            }
        }

        if isRemoved, let sTime = startTime {
            removedSeconds += Date().timeIntervalSince(sTime)
        }

        let totalRemovedSec = Int(removedSeconds)
        let calendar = Calendar.current
        let secondsPassedToday = Int(Date().timeIntervalSince(calendar.startOfDay(for: Date())))
        let wornSec = max(0, secondsPassedToday - totalRemovedSec)

        // Info ciclo
        var cycleNum = 1
        var colorHex = "#00A896"
        if let cycleData = defaults.data(forKey: AppGroupConstants.cyclesKey),
           let cycles = try? JSONDecoder().decode([AlignerCycle].self, from: cycleData),
           let current = cycles.first(where: { !$0.isCompleted }) ?? cycles.last {
            cycleNum = current.cycleNumber
            colorHex = current.colorHex
        }

        return AlignerEntry(
            date: Date(),
            isRemoved: isRemoved,
            removalStartTime: startTime,
            todayRemovedSeconds: totalRemovedSec,
            todayWornSeconds: wornSec,
            cycleNumber: cycleNum,
            cycleColorHex: colorHex
        )
    }
}

// MARK: - Widget Views

public struct AlignerWidgetEntryView: View {
    var entry: AlignerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (Il widget richiesto: "molto semplice, piccolo e carino")
struct SmallWidgetView: View {
    let entry: AlignerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Mascherina N. e Status Badge
            HStack {
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(hex: entry.cycleColorHex))
                        .frame(width: 7, height: 7)
                    Text("M#\(entry.cycleNumber)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Badge Stato
                HStack(spacing: 3) {
                    Circle()
                        .fill(entry.isRemoved ? Color.orange : Color.emeraldMint)
                        .frame(width: 6, height: 6)
                    Text(entry.isRemoved ? "TOLTO" : "INDOSSATO")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(entry.isRemoved ? .orange : Color.emeraldMint)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(entry.isRemoved ? Color.orange.opacity(0.15) : Color.emeraldMint.opacity(0.15))
                )
            }

            Spacer(minLength: 2)

            // Contenuto Centrale Dinamico
            if entry.isRemoved {
                // STATO: TOLTO -> Mostra Timer che scorre
                VStack(alignment: .leading, spacing: 1) {
                    Text("FUORI DA")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    if let startTime = entry.removalStartTime {
                        Text(startTime, style: .timer)
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundColor(.orange)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    } else {
                        Text("00:00")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundColor(.orange)
                    }

                    Text("Oggi fuori: \(formatSeconds(entry.todayRemovedSeconds))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            } else {
                // STATO: RIMESSO / INDOSSATO -> Mostra progresso odierno
                VStack(alignment: .leading, spacing: 1) {
                    Text("OGGI PORTATO")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    let hours = entry.todayWornSeconds / 3600
                    let mins = (entry.todayWornSeconds % 3600) / 60
                    Text("\(hours)h \(mins)m")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    let remainingAllowed = max(0, (2 * 3600) - entry.todayRemovedSeconds)
                    Text("Pausa rimasta: \(formatSeconds(remainingAllowed))")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(remainingAllowed < 1800 ? .orange : Color.emeraldMint)
                }
            }

            Spacer(minLength: 2)

            // Pulsante Interattivo iOS 17+ (Alterna: Tolto / Rimesso)
            if #available(iOS 17.0, *) {
                Button(intent: ToggleAlignerIntent()) {
                    HStack(spacing: 5) {
                        Image(systemName: entry.isRemoved ? "checkmark.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(entry.isRemoved ? "Rimesso" : "Tolto")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        entry.isRemoved
                            ? LinearGradient(colors: [Color.emeraldMint, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.orange, Color.red.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: (entry.isRemoved ? Color.emeraldMint : Color.orange).opacity(0.3), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            } else {
                Text(entry.isRemoved ? "Apri e rimetti" : "Apri e togli")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .systemBackground))
        )
    }

    private func formatSeconds(_ sec: Int) -> String {
        let total = max(0, sec)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        } else {
            return "\(s)s"
        }
    }
}

// MARK: - Medium Widget (Versione estesa)
struct MediumWidgetView: View {
    let entry: AlignerEntry

    var body: some View {
        HStack(spacing: 14) {
            SmallWidgetView(entry: entry)
                .frame(maxWidth: 155)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Obiettivo 22h / 24h")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                ProgressView(value: Double(entry.todayWornSeconds), total: 22.0 * 3600.0)
                    .tint(Color.emeraldMint)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Portato")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(entry.todayWornSeconds / 3600)h \((entry.todayWornSeconds % 3600) / 60)m")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Tolto")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(formatSec(entry.todayRemovedSeconds))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(entry.todayRemovedSeconds > 7200 ? .red : .orange)
                    }
                }

                Spacer()

                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(hex: entry.cycleColorHex))
                        .font(.system(size: 10))
                    Text("Ciclo da 14 giorni")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(10)
    }

    private func formatSec(_ sec: Int) -> String {
        let total = max(0, sec)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

// MARK: - App Color Helper
extension Color {
    static let emeraldMint = Color(red: 0.0, green: 0.72, blue: 0.58)
}

// MARK: - Widget Definition
public struct AlignerWidget: Widget {
    public let kind: String = "AlignerWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlignerTimelineProvider()) { entry in
            AlignerWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(uiColor: .secondarySystemBackground)
                }
        }
        .configurationDisplayName("Aligner Tracker")
        .description("Controlla e registra rapidamente quando togli e rimetti la mascherina.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
