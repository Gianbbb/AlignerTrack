import SwiftUI
import UIKit

public struct TodayDashboardView: View {
    @ObservedObject var dataManager: AlignerDataManager
    @State private var showingAddManualSheet = false
    @State private var manualStart = Date().addingTimeInterval(-1800)
    @State private var manualEnd = Date()
    @State private var manualNote = ""

    // Timer per aggiornare la visualizzazione ogni secondo quando l'apparecchio è tolto
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Banner Ciclo Attivo
                    if let currentCycle = dataManager.currentCycle {
                        ActiveCycleBanner(cycle: currentCycle, dataManager: dataManager)
                    }

                    // MARK: - Banner Modalità Festa (se attiva)
                    if dataManager.specialEventMode {
                        SpecialEventActiveBanner(dataManager: dataManager)
                    }

                    // MARK: - Hero Status Card (Stile Widget ma in grande)
                    MainStatusHeroCard(dataManager: dataManager, now: now)

                    // MARK: - Strumenti Rapidi (Chewies, Pulizia, Foto, Report)
                    TodayQuickToolsBar(dataManager: dataManager)

                    // MARK: - Statistiche Odierne Rapide
                    TodayStatsGrid(dataManager: dataManager, now: now)

                    // MARK: - Lista Rimozioni di Oggi
                    TodaySessionsSection(
                        dataManager: dataManager,
                        onAddTap: { showingAddManualSheet = true }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Oggi")
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(destination: TreatmentManagementView(dataManager: dataManager)) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.emeraldMint)
                    }

                    Button {
                        showingAddManualSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.emeraldMint)
                    }
                }
            }
            .onReceive(timer) { input in
                now = input
            }
            .sheet(isPresented: $showingAddManualSheet) {
                AddManualSessionSheet(
                    dataManager: dataManager,
                    isPresented: $showingAddManualSheet
                )
            }
        }
    }
}

// MARK: - Active Cycle Banner
struct ActiveCycleBanner: View {
    let cycle: AlignerCycle
    let dataManager: AlignerDataManager

    var body: some View {
        let analysis = dataManager.analyzeCycle(cycle)
        NavigationLink(destination: RecoveryManagementView(dataManager: dataManager)) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: cycle.colorHex))
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Mascherina #\(cycle.cycleNumber)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)

                        if cycle.recoveryDays > 0 {
                            Text("+\(cycle.recoveryDays) gg recupero")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                    }

                    Text("Giorno \(analysis.daysElapsed) di \(cycle.totalDays) • Cambio il \(formatDate(cycle.calculatedEndDate))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMMM"
        return f.string(from: date)
    }
}

// MARK: - Special Event Active Banner
struct SpecialEventActiveBanner: View {
    @ObservedObject var dataManager: AlignerDataManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "party.popper.fill")
                .foregroundColor(.purple)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Modalità Festa Attiva 🎉")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                Text("Pausa libera oggi estesa a \(Int(dataManager.specialEventAllowedHours)) ore.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            NavigationLink(destination: CareToolsView(dataManager: dataManager)) {
                Text("Gestisci")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Today Quick Tools Bar
struct TodayQuickToolsBar: View {
    @ObservedObject var dataManager: AlignerDataManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                NavigationLink(destination: CareToolsView(dataManager: dataManager)) {
                    QuickToolPill(icon: "mouth.fill", label: "Chewies", color: Color.emeraldMint)
                }

                NavigationLink(destination: CareToolsView(dataManager: dataManager)) {
                    QuickToolPill(icon: "bubbles.and.sparkles.fill", label: "Pulizia", color: .blue)
                }

                NavigationLink(destination: SmileComparisonView(dataManager: dataManager)) {
                    QuickToolPill(icon: "photo.stack.fill", label: "Foto Sorriso", color: .pink)
                }

                NavigationLink(destination: CareToolsView(dataManager: dataManager)) {
                    QuickToolPill(icon: "doc.richtext.fill", label: "Report PDF", color: .indigo)
                }

                NavigationLink(destination: TreatmentManagementView(dataManager: dataManager)) {
                    QuickToolPill(icon: "slider.horizontal.3", label: "Modifica Date", color: .orange)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct QuickToolPill: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
        )
    }
}

// MARK: - Main Status Hero Card
struct MainStatusHeroCard: View {
    @ObservedObject var dataManager: AlignerDataManager
    let now: Date

    var body: some View {
        VStack(spacing: 18) {
            // Stato Attuale Pill
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(dataManager.isAlignerRemoved ? Color.orange : Color.emeraldMint)
                        .frame(width: 10, height: 10)
                    Text(dataManager.isAlignerRemoved ? "APPARECCHIO TOLTO" : "APPARECCHIO INDOSSATO")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(dataManager.isAlignerRemoved ? .orange : Color.emeraldMint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(dataManager.isAlignerRemoved ? Color.orange.opacity(0.12) : Color.emeraldMint.opacity(0.12))
                )

                Spacer()

                Text("Target: 22h / 24h")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // Anello di Progresso & Tempo Live
            ZStack {
                // Progresso ore indossate oggi (22h target)
                let wearProgress = dataManager.todayWearProgress()

                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 16)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0, to: CGFloat(wearProgress))
                    .stroke(
                        dataManager.isAlignerRemoved ? Color.orange : Color.emeraldMint,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 190, height: 190)
                    .animation(.spring(), value: wearProgress)

                VStack(spacing: 4) {
                    if dataManager.isAlignerRemoved {
                        Image(systemName: "timer")
                            .font(.system(size: 26))
                            .foregroundColor(.orange)

                        let elapsedSec = dataManager.currentRemovalStartTime.map { now.timeIntervalSince($0) } ?? 0
                        Text(formatDuration(elapsedSec))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.orange)
                            .monospacedDigit()

                        Text("Fuori dall'inizio")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(Color.emeraldMint)

                        let wornSec = dataManager.wornSeconds(for: Date())
                        let hours = Int(wornSec / 3600)
                        let mins = Int((wornSec.truncatingRemainder(dividingBy: 3600)) / 60)
                        Text("\(hours)h \(mins)m")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Indossato oggi")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)

            // Pulsante Alternante Gigante: "TOLTO" / "RIMESSO"
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    dataManager.toggleAligner()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: dataManager.isAlignerRemoved ? "checkmark.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 20, weight: .bold))

                    Text(dataManager.isAlignerRemoved ? "Rimesso" : "Tolto")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    dataManager.isAlignerRemoved
                        ? LinearGradient(colors: [Color.emeraldMint, Color.teal], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.orange, Color.red.opacity(0.85)], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white)
                .cornerRadius(18)
                .shadow(
                    color: (dataManager.isAlignerRemoved ? Color.emeraldMint : Color.orange).opacity(0.35),
                    radius: 8,
                    y: 4
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        )
    }

    private func formatDuration(_ sec: TimeInterval) -> String {
        let s = Int(sec)
        let m = (s / 60) % 60
        let h = s / 3600
        let remainderSec = s % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, remainderSec)
        } else {
            return String(format: "%02d:%02d", m, remainderSec)
        }
    }
}

// MARK: - Today Stats Grid
struct TodayStatsGrid: View {
    @ObservedObject var dataManager: AlignerDataManager
    let now: Date

    var body: some View {
        let removedSec = dataManager.removedSeconds(for: Date())
        let allowedSec = dataManager.dailyAllowedRemovalSeconds
        let remainingPauseSec = max(0, allowedSec - removedSec)

        HStack(spacing: 12) {
            // Card Tempo Tolto Oggi
            StatMiniCard(
                title: "Tempo Tolto",
                value: formatSecondsPrecise(removedSec),
                subtitle: "Max 2h / giorno",
                icon: "arrow.up.and.down.circle.fill",
                color: removedSec > allowedSec ? .red : .orange
            )

            // Card Pausa Rimasta
            StatMiniCard(
                title: "Pausa Rimasta",
                value: formatSecondsPrecise(remainingPauseSec),
                subtitle: remainingPauseSec == 0 ? "Limite superato!" : "Prima del deficit",
                icon: "hourglass.badge.plus",
                color: remainingPauseSec < 1200 ? .red : Color.emeraldMint
            )

            // Card Sessioni
            let todaySessionsCount = getTodaySessionsCount()
            StatMiniCard(
                title: "Pasti / Pause",
                value: "\(todaySessionsCount)",
                subtitle: "Rimozioni oggi",
                icon: "fork.knife.circle.fill",
                color: .blue
            )
        }
    }

    private func getTodaySessionsCount() -> Int {
        let cal = Calendar.current
        var count = dataManager.sessions.filter { cal.isDate($0.startDate, inSameDayAs: Date()) }.count
        if dataManager.isAlignerRemoved { count += 1 }
        return count
    }

    private func formatSecondsPrecise(_ sec: TimeInterval) -> String {
        let total = max(0, Int(sec))
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

struct StatMiniCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 15))
                Spacer()
            }

            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
        )
    }
}

// MARK: - Today Sessions List
struct TodaySessionsSection: View {
    @ObservedObject var dataManager: AlignerDataManager
    let onAddTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dettaglio Pause di Oggi")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button("Aggiungi manuale", action: onAddTap)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.emeraldMint)
            }

            let todaySessions = dataManager.sessions.filter {
                Calendar.current.isDate($0.startDate, inSameDayAs: Date())
            }.reversed()

            if todaySessions.isEmpty && !dataManager.isAlignerRemoved {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.emeraldMint)
                        Text("Nessuna pausa registrata oggi!")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            } else {
                VStack(spacing: 8) {
                    if dataManager.isAlignerRemoved, let start = dataManager.currentRemovalStartTime {
                        HStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("In corso (dal \(formatTime(start)))")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                                Text("L'apparecchio è attualmente tolto")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("In pausa")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                    }

                    ForEach(Array(todaySessions)) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(formatTime(session.startDate)) - \(formatTime(session.endDate))")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                if !session.note.isEmpty {
                                    Text(session.note)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(session.durationFormatted)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)

                            Button {
                                dataManager.deleteSession(session)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }
            }
        }
    }

    private func formatTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

// MARK: - Add Manual Session Sheet
struct AddManualSessionSheet: View {
    @ObservedObject var dataManager: AlignerDataManager
    @Binding var isPresented: Bool
    @State private var start = Date().addingTimeInterval(-1800)
    @State private var end = Date()
    @State private var note = "Pranzo / Spuntino"

    var body: some View {
        NavigationStack {
            Form {
                Section("Orari Pausa") {
                    DatePicker("Inizio rimozione", selection: $start, displayedComponents: [.hourAndMinute, .date])
                    DatePicker("Fine rimozione (rimesso)", selection: $end, displayedComponents: [.hourAndMinute, .date])
                }

                Section("Motivo / Nota") {
                    TextField("Es. Pranzo, Lavaggio denti, Cena", text: $note)
                }

                Section {
                    let duration = max(0, end.timeIntervalSince(start))
                    HStack {
                        Text("Durata registrata")
                        Spacer()
                        Text("\(Int(duration / 60)) minuti")
                            .bold()
                    }
                }
            }
            .navigationTitle("Aggiungi Pausa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        dataManager.addManualSession(startDate: start, endDate: end, note: note)
                        isPresented = false
                    }
                    .disabled(end <= start)
                }
            }
        }
    }
}
