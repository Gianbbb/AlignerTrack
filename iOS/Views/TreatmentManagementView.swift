import SwiftUI
import PhotosUI
import UIKit

public struct TreatmentManagementView: View {
    @ObservedObject var dataManager: AlignerDataManager
    @State private var showingResetAlert = false
    @State private var showingEditCycleSheet = false
    @State private var cycleToEdit: AlignerCycle? = nil

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Ciclo Attuale & Modifica Rapida
                    if let currentCycle = dataManager.currentCycle {
                        ActiveCycleEditCard(
                            cycle: currentCycle,
                            dataManager: dataManager,
                            onEditFull: {
                                cycleToEdit = currentCycle
                                showingEditCycleSheet = true
                            }
                        )
                    }

                    // MARK: - Foto Sorriso e Mascherina Attuale
                    if let currentCycle = dataManager.currentCycle {
                        CyclePhotoCard(
                            cycle: currentCycle,
                            dataManager: dataManager
                        )
                    }

                    // MARK: - Obiettivi & Parametri Trattamento
                    TreatmentGlobalSettingsCard(dataManager: dataManager)

                    // MARK: - Tutte le Mascherine (Elenco per modifica individuale)
                    AllCyclesManagementSection(
                        cycles: dataManager.cycles,
                        dataManager: dataManager,
                        onEditCycle: { cycle in
                            cycleToEdit = cycle
                            showingEditCycleSheet = true
                        }
                    )

                    // MARK: - Zona Pericolo / Reset
                    DangerZoneCard(onReset: {
                        showingResetAlert = true
                    })
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Gestione Trattamento")
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(item: $cycleToEdit) { cycle in
                EditCycleSheet(
                    cycle: cycle,
                    dataManager: dataManager,
                    isPresented: Binding(
                        get: { cycleToEdit != nil },
                        set: { if !$0 { cycleToEdit = nil } }
                    )
                )
            }
            .alert("Ripristinare tutti i dati?", isPresented: $showingResetAlert) {
                Button("Annulla", role: .cancel) {}
                Button("Ripristina", role: .destructive) {
                    dataManager.resetAllData()
                }
            } message: {
                Text("Questa azione cancellerà tutte le sessioni registrate e reimposterà il trattamento alla Mascherina #1.")
            }
        }
    }
}

// MARK: - Active Cycle Edit Card
struct ActiveCycleEditCard: View {
    let cycle: AlignerCycle
    @ObservedObject var dataManager: AlignerDataManager
    let onEditFull: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        let analysis = dataManager.analyzeCycle(cycle)
        let currentDayNumber = min(cycle.totalDays, max(1, analysis.daysElapsed))

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: cycle.colorHex))
                        .frame(width: 14, height: 14)
                    Text("Mascherina #\(cycle.cycleNumber) di \(dataManager.totalTreatmentAligners)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                Button("Modifica tutto", action: onEditFull)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color.emeraldMint)
            }

            Divider()

            // Controllo Rapido: "A che giorno sei oggi?"
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Giorno attuale nel ciclo:")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Giorno \(currentDayNumber) di \(cycle.totalDays)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 12) {
                    Button {
                        if currentDayNumber > 1 {
                            dataManager.setCycleCurrentDay(for: cycle.id, currentDay: currentDayNumber - 1)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(currentDayNumber > 1 ? Color.emeraldMint : .secondary.opacity(0.3))
                    }
                    .disabled(currentDayNumber <= 1)

                    Slider(
                        value: Binding(
                            get: { Double(currentDayNumber) },
                            set: { dataManager.setCycleCurrentDay(for: cycle.id, currentDay: Int($0)) }
                        ),
                        in: 1...Double(max(1, cycle.totalDays)),
                        step: 1
                    )
                    .tint(Color.emeraldMint)

                    Button {
                        if currentDayNumber < cycle.totalDays {
                            dataManager.setCycleCurrentDay(for: cycle.id, currentDay: currentDayNumber + 1)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(currentDayNumber < cycle.totalDays ? Color.emeraldMint : .secondary.opacity(0.3))
                    }
                    .disabled(currentDayNumber >= cycle.totalDays)
                }

                Text("⚡ Modificando il giorno attuale, l'app ricalcola automaticamente la data di inizio per far coincidere perfettamente il calendario con la tua mascherina.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Riepilogo Date Chiave
            VStack(spacing: 8) {
                DateRowSummary(
                    label: "Inizio mascherina:",
                    date: cycle.startDate,
                    icon: "calendar.badge.clock",
                    color: Color(hex: cycle.colorHex)
                )

                DateRowSummary(
                    label: "Durata base impostata:",
                    text: "\(cycle.nominalDays) giorni",
                    icon: "clock.arrow.2.circlepath",
                    color: .secondary
                )

                if cycle.recoveryDays > 0 {
                    DateRowSummary(
                        label: "Giorni recupero aggiunti:",
                        text: "+\(cycle.recoveryDays) giorni extra",
                        icon: "bandage.fill",
                        color: .orange
                    )
                }

                DateRowSummary(
                    label: "Data cambio / fine prevista:",
                    date: cycle.calculatedEndDate,
                    icon: "flag.checkered.circle.fill",
                    color: Color.emeraldMint,
                    isBold: true
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
}

struct DateRowSummary: View {
    let label: String
    var date: Date? = nil
    var text: String? = nil
    let icon: String
    let color: Color
    var isBold: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 13))

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()

            if let date = date {
                Text(formatDate(date))
                    .font(.system(size: 13, weight: isBold ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isBold ? color : .primary)
            } else if let text = text {
                Text(text)
                    .font(.system(size: 13, weight: isBold ? .bold : .semibold, design: .rounded))
                    .foregroundColor(isBold ? color : .primary)
            }
        }
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEE d MMMM yyyy"
        return f.string(from: d)
    }
}

// MARK: - Cycle Photo Card (Smile Progress Gallery)
struct CyclePhotoCard: View {
    let cycle: AlignerCycle
    @ObservedObject var dataManager: AlignerDataManager
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(Color.emeraldMint)
                    .font(.system(size: 18))

                Text("Foto Sorriso & Denti (M#\(cycle.cycleNumber))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 4) {
                        Image(systemName: cycle.photoData == nil ? "plus" : "arrow.triangle.2.circlepath")
                        Text(cycle.photoData == nil ? "Aggiungi" : "Cambia")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color.emeraldMint)
                }
            }

            if let data = cycle.photoData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(14)

                    Button {
                        dataManager.setCyclePhoto(for: cycle.id, photoData: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .padding(8)
                }
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.rectangle.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(Color.emeraldMint)

                        Text("Scatta o seleziona una foto dei denti")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Registra i progressi del sorriso ad ogni mascherina per confrontare il prima e dopo.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundColor(Color.emeraldMint.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        dataManager.setCyclePhoto(for: cycle.id, photoData: data)
                    }
                }
            }
        }
    }
}

// MARK: - Treatment Global Settings Card
struct TreatmentGlobalSettingsCard: View {
    @ObservedObject var dataManager: AlignerDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Parametri Generali Trattamento")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Target Ore Giornaliere
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Obiettivo indossamento giornaliero:")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(dataManager.dailyTargetWearHours)) ore / giorno")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.emeraldMint)
                }

                HStack(spacing: 8) {
                    ForEach([20, 21, 22, 23], id: \.self) { hours in
                        Button {
                            dataManager.updateTreatmentSettings(
                                targetHours: Double(hours),
                                totalAligners: dataManager.totalTreatmentAligners
                            )
                        } label: {
                            Text("\(hours)h")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Int(dataManager.dailyTargetWearHours) == hours
                                        ? Color.emeraldMint
                                        : Color(uiColor: .tertiarySystemGroupedBackground)
                                )
                                .foregroundColor(
                                    Int(dataManager.dailyTargetWearHours) == hours
                                        ? .white
                                        : .primary
                                )
                                .cornerRadius(10)
                        }
                    }
                }

                Text("Standard ortodontico consigliato: 22 ore (lascia 2 ore per colazione, pranzo e cena).")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Numero totale mascherine previste
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mascherine totali previste dal piano:")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(dataManager.totalTreatmentAligners) mascherine")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Stepper(
                    "Totale mascherine: \(dataManager.totalTreatmentAligners)",
                    value: Binding(
                        get: { dataManager.totalTreatmentAligners },
                        set: { dataManager.updateTreatmentSettings(targetHours: dataManager.dailyTargetWearHours, totalAligners: $0) }
                    ),
                    in: 1...100
                )
                .labelsHidden()
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

// MARK: - All Cycles Management Section
struct AllCyclesManagementSection: View {
    let cycles: [AlignerCycle]
    @ObservedObject var dataManager: AlignerDataManager
    let onEditCycle: (AlignerCycle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tutte le Mascherine")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(cycles.count) mascherine")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            ForEach(cycles.reversed()) { cycle in
                HStack {
                    Circle()
                        .fill(Color(hex: cycle.colorHex))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Mascherina #\(cycle.cycleNumber)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            if dataManager.currentCycle?.id == cycle.id {
                                Text("ATTIVA")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(Color.emeraldMint)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.emeraldMint.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }

                        Text("\(formatShort(cycle.startDate)) → \(formatShort(cycle.calculatedEndDate)) (\(cycle.totalDays) giorni)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if cycle.photoData != nil {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.emeraldMint)
                    }

                    Button {
                        onEditCycle(cycle)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14))
                            .foregroundColor(Color.emeraldMint)
                            .padding(8)
                            .background(Color.emeraldMint.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
            }
        }
    }

    private func formatShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }
}

// MARK: - Danger Zone Card
struct DangerZoneCard: View {
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gestione Dati")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)

            Button(role: .destructive, action: onReset) {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                    Text("Ripristina Dati Trattamento a Zero")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(14)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Edit Cycle Full Sheet
struct EditCycleSheet: View {
    @State var cycle: AlignerCycle
    @ObservedObject var dataManager: AlignerDataManager
    @Binding var isPresented: Bool

    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var nominalDays: Int
    @State private var recoveryDays: Int
    @State private var selectedColorHex: String
    @State private var note: String

    init(cycle: AlignerCycle, dataManager: AlignerDataManager, isPresented: Binding<Bool>) {
        self._cycle = State(initialValue: cycle)
        self.dataManager = dataManager
        self._isPresented = isPresented
        self._cycleNumber = State(initialValue: cycle.cycleNumber)
        self._startDate = State(initialValue: cycle.startDate)
        self._nominalDays = State(initialValue: cycle.nominalDays)
        self._recoveryDays = State(initialValue: cycle.recoveryDays)
        self._selectedColorHex = State(initialValue: cycle.colorHex)
        self._note = State(initialValue: cycle.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identificativo") {
                    Stepper("Numero Mascherina: #\(cycleNumber)", value: $cycleNumber, in: 1...100)
                }

                Section("Date e Durata") {
                    DatePicker("Data Inizio", selection: $startDate, displayedComponents: [.date])

                    Stepper("Durata nominale base: \(nominalDays) giorni", value: $nominalDays, in: 1...60)

                    // Scorciatoie rapide durata (7, 10, 14 giorni)
                    HStack {
                        Text("Preimpostati:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        ForEach([7, 10, 14], id: \.self) { d in
                            Button("\(d) gg") {
                                nominalDays = d
                            }
                            .buttonStyle(.bordered)
                            .tint(nominalDays == d ? Color.emeraldMint : .secondary)
                        }
                    }

                    Stepper("Giorni di recupero manuali: +\(recoveryDays) gg", value: $recoveryDays, in: 0...30)

                    let calculatedEnd = Calendar.current.date(byAdding: .day, value: nominalDays + recoveryDays, to: startDate) ?? startDate
                    HStack {
                        Text("Data Fine Calcolata")
                        Spacer()
                        Text(formatFull(calculatedEnd))
                            .bold()
                            .foregroundColor(Color.emeraldMint)
                    }
                }

                Section("Colore Identificativo nel Calendario") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CycleColorPalette.colors, id: \.self) { colorHex in
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColorHex == colorHex ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColorHex = colorHex
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Note Ortodontista / Trattamento") {
                    TextField("Es. Attacchi nuovi, elastici notturni", text: $note)
                }
            }
            .navigationTitle("Modifica Mascherina #\(cycleNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { isPresented = false }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        var updated = cycle
                        updated.cycleNumber = cycleNumber
                        updated.startDate = Calendar.current.startOfDay(for: startDate)
                        updated.nominalDays = nominalDays
                        updated.recoveryDays = recoveryDays
                        updated.colorHex = selectedColorHex
                        updated.note = note
                        dataManager.updateCycle(updated)
                        isPresented = false
                    }
                }
            }
        }
    }

    private func formatFull(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEE d MMMM yyyy"
        return f.string(from: d)
    }
}
