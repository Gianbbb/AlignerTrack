import SwiftUI

public struct RecoveryManagementView: View {
    @ObservedObject var dataManager: AlignerDataManager

    @State private var selectedRecoveryDays: Int = 0
    @State private var showingStartNewCycleAlert = false
    @State private var showingNewCycleSheet = false
    @State private var newCycleNumber: Int = 2
    @State private var newCycleStartDate: Date = Date()

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let currentCycle = dataManager.currentCycle {
                        let analysis = dataManager.analyzeCycle(currentCycle)

                        // MARK: - Card Ciclo Attuale
                        CurrentCycleSummaryCard(cycle: currentCycle, analysis: analysis)

                        // MARK: - Calcolo Ore Saltate & Suggerimento App
                        RecoverySuggestionCard(
                            analysis: analysis,
                            onApplySuggestion: {
                                selectedRecoveryDays = analysis.suggestedRecoveryDays
                                dataManager.setRecoveryDays(for: currentCycle.id, days: selectedRecoveryDays)
                            }
                        )

                        // MARK: - Selettore Manuale Giorni di Recupero
                        ManualRecoveryAdjustmentCard(
                            cycle: currentCycle,
                            selectedDays: $selectedRecoveryDays,
                            onSave: { days in
                                dataManager.setRecoveryDays(for: currentCycle.id, days: days)
                            }
                        )
                        .onAppear {
                            selectedRecoveryDays = currentCycle.recoveryDays
                        }

                        // MARK: - Date Ricalcolate
                        RecalculatedDatesTimelineCard(cycle: currentCycle, analysis: analysis)

                        // MARK: - Azione Start Nuovo Ciclo
                        StartNewCycleActionSection(
                            currentCycle: currentCycle,
                            onStartNewCycleTap: {
                                newCycleNumber = currentCycle.cycleNumber + 1
                                newCycleStartDate = Date()
                                showingNewCycleSheet = true
                            }
                        )
                    } else {
                        // Nessun ciclo attivo
                        NoActiveCycleCard(onStartFirst: {
                            dataManager.startNewCycle(manualNumber: 1, startDate: Date())
                        })
                    }

                    // Link allo Storico
                    NavigationLink(destination: CycleHistoryView(dataManager: dataManager)) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(Color.emeraldMint)
                            Text("Visualizza lo Storico Completo dei Cicli")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Giorni di Recupero")
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(isPresented: $showingNewCycleSheet) {
                StartNewCycleSheet(
                    dataManager: dataManager,
                    cycleNumber: $newCycleNumber,
                    startDate: $newCycleStartDate,
                    isPresented: $showingNewCycleSheet
                )
            }
        }
    }
}

// MARK: - Current Cycle Summary Card
struct CurrentCycleSummaryCard: View {
    let cycle: AlignerCycle
    let analysis: AlignerDataManager.CycleAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: cycle.colorHex))
                        .frame(width: 14, height: 14)
                    Text("Mascherina #\(cycle.cycleNumber)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("Ciclo Attivo")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.emeraldMint.opacity(0.15))
                    .foregroundColor(Color.emeraldMint)
                    .cornerRadius(8)
            }

            // Barra progresso 14 giorni nominali
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Giorno \(analysis.daysElapsed) di \(cycle.nominalDays) nominali")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)

                    Spacer()

                    if cycle.recoveryDays > 0 {
                        Text("+\(cycle.recoveryDays) gg recupero aggiunti")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }

                let progress = min(1.0, Double(analysis.daysElapsed) / Double(cycle.nominalDays))
                ProgressView(value: progress)
                    .tint(Color(hex: cycle.colorHex))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - Recovery Suggestion Card
struct RecoverySuggestionCard: View {
    let analysis: AlignerDataManager.CycleAnalysis
    let onApplySuggestion: () -> Void

    var body: some View {
        let deficitHours = analysis.totalDeficitSeconds / 3600.0
        let suggestedDays = analysis.suggestedRecoveryDays

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                Text("Suggerimento Intelligente App")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Ore complessive saltate nel ciclo:")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f ore", deficitHours))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(deficitHours > 4 ? .orange : Color.emeraldMint)
                }

                Text("Target medico consigliato: 22 ore al giorno (max 2 ore di pausa libera).")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggerimento calcolato:")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)

                    if suggestedDays == 0 {
                        Text("Nessun giorno di recupero necessario! 🎉")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.emeraldMint)
                    } else {
                        Text("+\(suggestedDays) \(suggestedDays == 1 ? "giorno" : "giorni") di recupero")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                if suggestedDays > 0 {
                    Button("Applica") {
                        onApplySuggestion()
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }

            Text("💡 La formula divide le ore perse per l'efficacia di 22h/giorno per garantire il completo spostamento dentale prima del cambio.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - Manual Recovery Adjustment Card
struct ManualRecoveryAdjustmentCard: View {
    let cycle: AlignerCycle
    @Binding var selectedDays: Int
    let onSave: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Regolazione Manuale Giorni")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Puoi impostare o modificare a tuo piacimento quanti giorni aggiungere a questa mascherina:")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)

            HStack {
                Button {
                    if selectedDays > 0 {
                        selectedDays -= 1
                        onSave(selectedDays)
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(selectedDays > 0 ? Color.emeraldMint : .secondary.opacity(0.3))
                }
                .disabled(selectedDays <= 0)

                Spacer()

                VStack(spacing: 2) {
                    Text("+\(selectedDays)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(selectedDays > 0 ? .orange : .primary)
                    Text(selectedDays == 1 ? "Giorno Extra" : "Giorni Extra")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    selectedDays += 1
                    onSave(selectedDays)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color.emeraldMint)
                }
            }
            .padding(.vertical, 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - Recalculated Dates Timeline Card
struct RecalculatedDatesTimelineCard: View {
    let cycle: AlignerCycle
    let analysis: AlignerDataManager.CycleAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Impatto sul Calendario")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                TimelineDateRow(
                    label: "Inizio Mascherina #\(cycle.cycleNumber):",
                    dateText: formatDate(cycle.startDate),
                    icon: "play.circle.fill",
                    color: Color(hex: cycle.colorHex)
                )

                TimelineDateRow(
                    label: "Fine nominale (14 giorni):",
                    dateText: formatDate(cycle.nominalEndDate),
                    icon: "calendar.badge.clock",
                    color: .secondary
                )

                if cycle.recoveryDays > 0 {
                    TimelineDateRow(
                        label: "Giorni di recupero attivi:",
                        dateText: "+\(cycle.recoveryDays) giorni extra",
                        icon: "bandage.fill",
                        color: .orange
                    )
                }

                Divider()

                TimelineDateRow(
                    label: "Data Finale Cambio Mascherina:",
                    dateText: formatDate(cycle.calculatedEndDate),
                    icon: "flag.checkered.circle.fill",
                    color: Color.emeraldMint,
                    isProminent: true
                )

                TimelineDateRow(
                    label: "Inizio Prossimo Ciclo (M#\(cycle.cycleNumber + 1)):",
                    dateText: formatDate(cycle.nextCycleStartDate),
                    icon: "arrow.right.circle.fill",
                    color: .blue,
                    isProminent: true
                )
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
        f.dateFormat = "EEEE d MMMM yyyy"
        return f.string(from: date).capitalized
    }
}

struct TimelineDateRow: View {
    let label: String
    let dateText: String
    let icon: String
    let color: Color
    var isProminent: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: isProminent ? 16 : 14))

            Text(label)
                .font(.system(size: isProminent ? 14 : 13, weight: isProminent ? .bold : .medium, design: .rounded))
                .foregroundColor(isProminent ? .primary : .secondary)

            Spacer()

            Text(dateText)
                .font(.system(size: isProminent ? 14 : 13, weight: .bold, design: .rounded))
                .foregroundColor(isProminent ? color : .primary)
        }
    }
}

// MARK: - Start New Cycle Action Section
struct StartNewCycleActionSection: View {
    let currentCycle: AlignerCycle
    let onStartNewCycleTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                onStartNewCycleTap()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                    Text("Start Nuovo Ciclo (Mascherina #\(currentCycle.cycleNumber + 1))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.emeraldMint, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(18)
                .shadow(color: Color.emeraldMint.opacity(0.3), radius: 8, y: 4)
            }

            Text("Archivia la mascherina attuale e inizia un nuovo ciclo standard di 14 giorni.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - No Active Cycle Card
struct NoActiveCycleCard: View {
    let onStartFirst: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(Color.emeraldMint)

            Text("Nessun ciclo attivo")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("Inizia il monitoraggio della tua prima mascherina da 14 giorni.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Avvia Mascherina #1") {
                onStartFirst()
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.emeraldMint)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Start New Cycle Sheet
struct StartNewCycleSheet: View {
    @ObservedObject var dataManager: AlignerDataManager
    @Binding var cycleNumber: Int
    @Binding var startDate: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Dettagli Nuovo Ciclo") {
                    Stepper("Numero Mascherina: #\(cycleNumber)", value: $cycleNumber, in: 1...100)
                    DatePicker("Data di Inizio", selection: $startDate, displayedComponents: [.date])
                }

                Section("Durata") {
                    HStack {
                        Text("Durata nominale")
                        Spacer()
                        Text("14 giorni (22h/die)")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Text("Avviando questo ciclo, la mascherina precedente verrà contrassegnata come completata nello storico e il calendario colorerà i prossimi 14 giorni con un nuovo colore distintivo.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Avvia Nuovo Ciclo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Avvia") {
                        dataManager.startNewCycle(manualNumber: cycleNumber, startDate: startDate)
                        isPresented = false
                    }
                }
            }
        }
    }
}
