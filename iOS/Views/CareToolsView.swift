import SwiftUI
import UIKit

public struct CareToolsView: View {
    @ObservedObject var dataManager: AlignerDataManager

    // MARK: - Chewies Timer State
    @State private var chewiesRemainingSeconds: Int = 5 * 60
    @State private var chewiesTotalSeconds: Int = 5 * 60
    @State private var chewiesRunning: Bool = false
    @State private var chewiesTimer: Timer? = nil

    // MARK: - Cleaning Timer State
    @State private var cleaningRemainingSeconds: Int = 15 * 60
    @State private var cleaningTotalSeconds: Int = 15 * 60
    @State private var cleaningRunning: Bool = false
    @State private var cleaningTimer: Timer? = nil

    // MARK: - PDF Share State
    @State private var generatedPDFURL: URL? = nil
    @State private var showingShareSheet = false

    public init(dataManager: AlignerDataManager) {
        self.dataManager = dataManager
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - 1. Timer Chewies (Masticabili per aderenza)
                    ChewiesCardView(
                        remainingSeconds: $chewiesRemainingSeconds,
                        totalSeconds: $chewiesTotalSeconds,
                        isRunning: $chewiesRunning,
                        onToggle: toggleChewies,
                        onReset: resetChewies,
                        onSetDuration: setChewiesDuration
                    )

                    // MARK: - 2. Timer Pulizia & Igienizzazione (Pastiglie)
                    CleaningCardView(
                        remainingSeconds: $cleaningRemainingSeconds,
                        totalSeconds: $cleaningTotalSeconds,
                        isRunning: $cleaningRunning,
                        onToggle: toggleCleaning,
                        onReset: resetCleaning,
                        onSetDuration: setCleaningDuration
                    )

                    // MARK: - 3. Modalità Festa / Evento Speciale
                    SpecialEventCardView(dataManager: dataManager)

                    // MARK: - 4. Esportazione Report PDF Ortodontista
                    PDFExportCardView(
                        onGenerate: {
                            if let url = PDFReportGenerator.generateReport(dataManager: dataManager) {
                                generatedPDFURL = url
                                showingShareSheet = true
                            }
                        }
                    )

                    // MARK: - 5. Impostazioni Notifiche Promemoria
                    NotificationSettingsCardView(dataManager: dataManager)

                    // MARK: - 6. Scorciatoia Confronto Sorriso
                    NavigationLink(destination: SmileComparisonView(dataManager: dataManager)) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.emeraldMint)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Confronto Split Sorriso Prima vs Oggi")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Visualizza lo slider interattivo dei tuoi denti")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Strumenti & Cura")
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(isPresented: $showingShareSheet) {
                if let url = generatedPDFURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Chewies Timer Logic
    private func toggleChewies() {
        if chewiesRunning {
            chewiesTimer?.invalidate()
            chewiesTimer = nil
            chewiesRunning = false
        } else {
            chewiesRunning = true
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            chewiesTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if chewiesRemainingSeconds > 0 {
                    chewiesRemainingSeconds -= 1
                } else {
                    chewiesTimer?.invalidate()
                    chewiesTimer = nil
                    chewiesRunning = false
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    NotificationManager.shared.scheduleTimerNotification(
                        title: "🦷 Chewies Completati!",
                        body: "Ottimo lavoro! La sessione di masticabili è terminata. Le mascherine sono perfettamente aderenti.",
                        delaySeconds: 1,
                        identifier: "chewies_done"
                    )
                }
            }
        }
    }

    private func resetChewies() {
        chewiesTimer?.invalidate()
        chewiesTimer = nil
        chewiesRunning = false
        chewiesRemainingSeconds = chewiesTotalSeconds
    }

    private func setChewiesDuration(_ minutes: Int) {
        chewiesTimer?.invalidate()
        chewiesTimer = nil
        chewiesRunning = false
        chewiesTotalSeconds = minutes * 60
        chewiesRemainingSeconds = minutes * 60
    }

    // MARK: - Cleaning Timer Logic
    private func toggleCleaning() {
        if cleaningRunning {
            cleaningTimer?.invalidate()
            cleaningTimer = nil
            cleaningRunning = false
        } else {
            cleaningRunning = true
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            cleaningTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if cleaningRemainingSeconds > 0 {
                    cleaningRemainingSeconds -= 1
                } else {
                    cleaningTimer?.invalidate()
                    cleaningTimer = nil
                    cleaningRunning = false
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                    NotificationManager.shared.scheduleTimerNotification(
                        title: "🧼 Mascherine Pronte!",
                        body: "L'igienizzazione è terminata. Risciacqua le mascherine con acqua tiepida prima di rimetterle.",
                        delaySeconds: 1,
                        identifier: "cleaning_done"
                    )
                }
            }
        }
    }

    private func resetCleaning() {
        cleaningTimer?.invalidate()
        cleaningTimer = nil
        cleaningRunning = false
        cleaningRemainingSeconds = cleaningTotalSeconds
    }

    private func setCleaningDuration(_ minutes: Int) {
        cleaningTimer?.invalidate()
        cleaningTimer = nil
        cleaningRunning = false
        cleaningTotalSeconds = minutes * 60
        cleaningRemainingSeconds = minutes * 60
    }
}

// MARK: - 1. Chewies Card View
struct ChewiesCardView: View {
    @Binding var remainingSeconds: Int
    @Binding var totalSeconds: Int
    @Binding var isRunning: Bool
    let onToggle: () -> Void
    let onReset: () -> Void
    let onSetDuration: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "mouth.fill")
                        .foregroundColor(Color.emeraldMint)
                        .font(.system(size: 18))
                    Text("Timer Chewies (Masticabili)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button("5 min") { onSetDuration(5) }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(totalSeconds == 300 ? Color.emeraldMint : Color(uiColor: .tertiarySystemGroupedBackground))
                        .foregroundColor(totalSeconds == 300 ? .white : .primary)
                        .cornerRadius(6)

                    Button("10 min") { onSetDuration(10) }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(totalSeconds == 600 ? Color.emeraldMint : Color(uiColor: .tertiarySystemGroupedBackground))
                        .foregroundColor(totalSeconds == 600 ? .white : .primary)
                        .cornerRadius(6)
                }
            }

            Text("Mordere i rulli di gomma per 5-10 min aiuta la mascherina a calzare a fondo ed elimina le sacche d'aria sui denti.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Display Tempo & Controlli
            HStack(spacing: 20) {
                // Progresso Circolare
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.emeraldMint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)

                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(Circle())
                    }

                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            Text(isRunning ? "Pausa" : "Avvia")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(isRunning ? Color.orange : Color.emeraldMint)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
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

    private func formatTime(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 2. Cleaning Card View
struct CleaningCardView: View {
    @Binding var remainingSeconds: Int
    @Binding var totalSeconds: Int
    @Binding var isRunning: Bool
    let onToggle: () -> Void
    let onReset: () -> Void
    let onSetDuration: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "bubbles.and.sparkles.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 18))
                    Text("Timer Pulizia & Igienizzazione")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button("10 min") { onSetDuration(10) }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(totalSeconds == 600 ? Color.blue : Color(uiColor: .tertiarySystemGroupedBackground))
                        .foregroundColor(totalSeconds == 600 ? .white : .primary)
                        .cornerRadius(6)

                    Button("15 min") { onSetDuration(15) }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(totalSeconds == 900 ? Color.blue : Color(uiColor: .tertiarySystemGroupedBackground))
                        .foregroundColor(totalSeconds == 900 ? .white : .primary)
                        .cornerRadius(6)
                }
            }

            Text("Tempo per il bagno con pastiglia effervescente o cristalli di pulizia. Riceverai un avviso al termine per risciacquare.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    let progress = totalSeconds > 0 ? Double(remainingSeconds) / Double(totalSeconds) : 0
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)

                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }

                Spacer()

                HStack(spacing: 12) {
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(Circle())
                    }

                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            Text(isRunning ? "Pausa" : "Immergi")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(isRunning ? Color.orange : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
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

    private func formatTime(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 3. Special Event Mode Card
struct SpecialEventCardView: View {
    @ObservedObject var dataManager: AlignerDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "party.popper.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 18))

                Text("Modalità Festa / Evento Speciale")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { dataManager.specialEventMode },
                    set: {
                        dataManager.specialEventMode = $0
                        dataManager.saveData()
                    }
                ))
                .labelsHidden()
            }

            Text("Hai una festa, una cerimonia o una cena lunga? Attiva questa modalità per estendere temporaneamente la pausa consentita per oggi senza allarmi.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            if dataManager.specialEventMode {
                Divider()

                HStack {
                    Text("Pausa libera concessa oggi:")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(Int(dataManager.specialEventAllowedHours)) ore")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                }

                HStack(spacing: 8) {
                    ForEach([3, 4, 5], id: \.self) { h in
                        Button("\(h) ore") {
                            dataManager.specialEventAllowedHours = Double(h)
                            dataManager.saveData()
                        }
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Int(dataManager.specialEventAllowedHours) == h ? Color.purple : Color(uiColor: .tertiarySystemGroupedBackground))
                        .foregroundColor(Int(dataManager.specialEventAllowedHours) == h ? .white : .primary)
                        .cornerRadius(8)
                    }
                }

                Text("🎉 Goditi la serata! Il recupero delle ore extra verrà spalmato automaticamente nei giorni successivi dal suggeritore.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple)
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

// MARK: - 4. PDF Export Card
struct PDFExportCardView: View {
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.richtext.fill")
                    .foregroundColor(Color.emeraldMint)
                    .font(.system(size: 18))

                Text("Report Clinico per l'Ortodontista")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()
            }

            Text("Genera un documento PDF professionale con il grafico delle ore portate, conformità al 22h e storico cambi per il tuo dentista.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Button(action: onGenerate) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14))
                    Text("Genera e Condividi Report PDF (WhatsApp / Stampa)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.emeraldMint, Color.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - 5. Notification Settings Card
struct NotificationSettingsCardView: View {
    @ObservedObject var dataManager: AlignerDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))

                Text("Notifiche Anti-Dimenticanza")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()
            }

            Text("Quando togli la mascherina, l'iPhone ti avvisa dopo un tempo prestabilito per ricordarti di rimetterla.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                Text("Avvisami dopo:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(dataManager.notificationDelayMinutes) minuti")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }

            HStack(spacing: 8) {
                ForEach([20, 30, 45, 60], id: \.self) { min in
                    Button("\(min)m") {
                        dataManager.notificationDelayMinutes = min
                        dataManager.saveData()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(dataManager.notificationDelayMinutes == min ? Color.orange : Color(uiColor: .tertiarySystemGroupedBackground))
                    .foregroundColor(dataManager.notificationDelayMinutes == min ? .white : .primary)
                    .cornerRadius(8)
                }
            }

            Button {
                NotificationManager.shared.requestAuthorization()
                NotificationManager.shared.scheduleTimerNotification(
                    title: "🔔 Test Notifica AlignerTrack",
                    body: "Le notifiche funzionano perfettamente! Riceverai i promemoria quando togli la mascherina.",
                    delaySeconds: 2,
                    identifier: "test_notification"
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bell.and.waveform")
                    Text("Prova Notifica di Test (2 sec)")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.orange)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - UIActivityViewController Wrapper for Sharing
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {}
}
