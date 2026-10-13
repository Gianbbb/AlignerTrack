import SwiftUI

public struct CalendarView: View {
    @ObservedObject var dataManager: AlignerDataManager
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let daysOfWeek = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Mese Header & Navigazione
                    MonthHeaderView(
                        displayedMonth: $displayedMonth,
                        onMonthChange: { offset in
                            if let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) {
                                displayedMonth = newMonth
                            }
                        }
                    )

                    // MARK: - Griglia Calendario Colorata per Ciclo
                    CalendarGridView(
                        displayedMonth: displayedMonth,
                        selectedDate: $selectedDate,
                        dataManager: dataManager
                    )
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                    )

                    // MARK: - Legenda Colori Cicli
                    CycleLegendView(cycles: dataManager.cycles)

                    // MARK: - Dettaglio Giorno Selezionato & Info Ciclo
                    DayDetailCard(
                        date: selectedDate,
                        dataManager: dataManager
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Calendario")
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

// MARK: - Month Header
struct MonthHeaderView: View {
    @Binding var displayedMonth: Date
    let onMonthChange: (Int) -> Void

    var body: some View {
        HStack {
            Button {
                onMonthChange(-1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.emeraldMint)
            }

            Spacer()

            Text(monthYearString(from: displayedMonth))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()

            Button {
                onMonthChange(1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.emeraldMint)
            }
        }
        .padding(.horizontal, 8)
    }

    private func monthYearString(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date).capitalized
    }
}

// MARK: - Calendar Grid
struct CalendarGridView: View {
    let displayedMonth: Date
    @Binding var selectedDate: Date
    @ObservedObject var dataManager: AlignerDataManager

    private let calendar = Calendar.current
    private let daysOfWeek = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]

    var body: some View {
        VStack(spacing: 8) {
            // Intestazione giorni della settimana
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let days = generateDaysForMonth(displayedMonth)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(date)
                        let cycle = dataManager.cycle(for: date)

                        DayCell(
                            date: date,
                            cycle: cycle,
                            isCurrentMonth: isCurrentMonth,
                            isSelected: isSelected,
                            isToday: isToday,
                            dataManager: dataManager
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }
        }
    }

    private func generateDaysForMonth(_ month: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        // Indice giorno della settimana (Lunedì = 1 ... Domenica = 7)
        let weekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Converti a Lunedì = 0
        let leadingSpaces = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingSpaces)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let cycle: AlignerCycle?
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let dataManager: AlignerDataManager

    private let calendar = Calendar.current

    var body: some View {
        let dayNumber = calendar.component(.day, from: date)
        let wornSec = dataManager.wornSeconds(for: date)
        let removedSec = dataManager.removedSeconds(for: date)
        let hasRecords = removedSec > 0 || (wornSec > 0 && date <= Date())
        let metGoal = wornSec >= dataManager.dailyTargetWearSeconds

        // Indicatori speciali ciclo
        let isCycleStart = cycle != nil && calendar.isDate(date, inSameDayAs: cycle!.startDate)
        let isNominalEnd = cycle != nil && calendar.isDate(date, inSameDayAs: cycle!.nominalEndDate)
        let isFinalEnd = cycle != nil && calendar.isDate(date, inSameDayAs: cycle!.calculatedEndDate)
        let isRecoveryDay = cycle != nil && date > cycle!.nominalEndDate && date <= cycle!.calculatedEndDate

        VStack(spacing: 2) {
            // Header cell: numero giorno + badge ciclo
            HStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isToday ? .heavy : .semibold, design: .rounded))
                    .foregroundColor(isCurrentMonth ? (isToday ? Color.emeraldMint : .primary) : .secondary.opacity(0.4))

                Spacer()

                if let cycle = cycle {
                    // Pallino colorato del ciclo
                    Circle()
                        .fill(Color(hex: cycle.colorHex))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer(minLength: 0)

            // Indicatore recupero o fine
            if isRecoveryDay {
                Text("+rec")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            } else if isCycleStart {
                Text("Inizio")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(cycle.map { Color(hex: $0.colorHex) } ?? .primary)
            } else if isFinalEnd {
                Text("Fine")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(cycle.map { Color(hex: $0.colorHex) } ?? .primary)
            } else if hasRecords {
                // Ore indossate approssimate
                let hours = Int(wornSec / 3600)
                HStack(spacing: 2) {
                    Circle()
                        .fill(metGoal ? Color.emeraldMint : Color.orange)
                        .frame(width: 4, height: 4)
                    Text("\(hours)h")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            } else {
                Spacer().frame(height: 10)
            }
        }
        .padding(5)
        .frame(height: 52)
        .background(
            ZStack {
                // Colore di sfondo se appartiene a un ciclo
                if let cycle = cycle, isCurrentMonth {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: cycle.colorHex).opacity(isRecoveryDay ? 0.08 : 0.16))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .systemBackground).opacity(0.5))
                }

                // Evidenziazione selezione
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary, lineWidth: 2)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.emeraldMint, lineWidth: 1.5)
                }
            }
        )
    }
}

// MARK: - Cycle Legend View
struct CycleLegendView: View {
    let cycles: [AlignerCycle]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Legenda Mascherine")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cycles) { cycle in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: cycle.colorHex))
                                .frame(width: 10, height: 10)

                            Text("M#\(cycle.cycleNumber)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            if cycle.recoveryDays > 0 {
                                Text("(+\(cycle.recoveryDays)g)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(hex: cycle.colorHex).opacity(0.14))
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Day Detail Card
struct DayDetailCard: View {
    let date: Date
    @ObservedObject var dataManager: AlignerDataManager
    private let calendar = Calendar.current

    var body: some View {
        let cycle = dataManager.cycle(for: date)
        let wornSec = dataManager.wornSeconds(for: date)
        let removedSec = dataManager.removedSeconds(for: date)
        let wornHours = Int(wornSec / 3600)
        let wornMins = Int((wornSec.truncatingRemainder(dividingBy: 3600)) / 60)
        let removedMins = Int(removedSec / 60)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date()

        VStack(alignment: .leading, spacing: 14) {
            // Header del giorno selezionato
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatFullDate(date))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)

                    if let cycle = cycle {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: cycle.colorHex))
                                .frame(width: 8, height: 8)

                            let daysSince = calendar.dateComponents([.day], from: calendar.startOfDay(for: cycle.startDate), to: calendar.startOfDay(for: date)).day ?? 0
                            let dayIndex = daysSince + 1

                            Text("Mascherina #\(cycle.cycleNumber) • Giorno \(dayIndex) di \(cycle.totalDays)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: cycle.colorHex))
                        }
                    } else {
                        Text("Nessun ciclo attivo programmato per questa data")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let cycle = cycle {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Fine Ciclo:")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(formatShortDate(cycle.calculatedEndDate))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
            }

            Divider()

            if !isFuture {
                // Info tempi del giorno
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tempo Indossato")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("\(wornHours)h \(wornMins)m")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(wornSec >= 22 * 3600 ? Color.emeraldMint : .orange)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tempo Tolto")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("\(removedMins / 60)h \(removedMins % 60)m")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(removedMins > 120 ? .red : .primary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Esito Target 22h")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        if wornSec >= 22 * 3600 {
                            Text("Raggiunto ✅")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color.emeraldMint)
                        } else {
                            Text("Non raggiunto ⚠️")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                    }
                }

                // Info ciclo successivo
                if let cycle = cycle {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(Color(hex: cycle.colorHex))
                            .font(.system(size: 14))

                        Text("Prossimo ciclo (M#\(cycle.cycleNumber + 1)) inizierà il:")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(formatFullDate(cycle.nextCycleStartDate))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    )
                }

                // Lista sessioni di quel giorno
                let daySessions = dataManager.sessions.filter {
                    calendar.isDate($0.startDate, inSameDayAs: date)
                }

                if !daySessions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sessioni di Rimozione:")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)

                        ForEach(daySessions) { s in
                            HStack {
                                Text("\(formatTime(s.startDate)) - \(formatTime(s.endDate))")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                if !s.note.isEmpty {
                                    Text("(\(s.note))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(s.durationFormatted)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                // Giorno futuro
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pianificazione Futura")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    if let cycle = cycle {
                        let isRec = date > cycle.nominalEndDate && date <= cycle.calculatedEndDate
                        if isRec {
                            Text("⚠️ Questo è un giorno di recupero programmato per compensare le ore senza mascherina.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.orange)
                        } else if calendar.isDate(date, inSameDayAs: cycle.calculatedEndDate) {
                            Text("🏁 Data prevista per il cambio mascherina (passaggio a M#\(cycle.cycleNumber + 1)).")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color.emeraldMint)
                        } else {
                            Text("Continuazione normale dell'allineamento (Target 22h/giorno).")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }

    private func formatFullDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEE d MMMM yyyy"
        return f.string(from: d).capitalized
    }

    private func formatShortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }

    private func formatTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}
