import Foundation
import Combine
import WidgetKit

@MainActor
public class AlignerDataManager: ObservableObject {
    public static let shared = AlignerDataManager()

    private let defaults: UserDefaults

    @Published public var isAlignerRemoved: Bool = false
    @Published public var currentRemovalStartTime: Date? = nil
    @Published public var sessions: [RemovalSession] = []
    @Published public var cycles: [AlignerCycle] = []
    @Published public var currentCycleId: UUID? = nil

    public init() {
        if let sharedDefaults = UserDefaults(suiteName: AppGroupConstants.groupIdentifier) {
            self.defaults = sharedDefaults
        } else {
            self.defaults = UserDefaults.standard
        }
        loadData()
    }

    // MARK: - Persistence

    public func loadData() {
        self.isAlignerRemoved = defaults.bool(forKey: AppGroupConstants.stateKey)
        if let time = defaults.object(forKey: AppGroupConstants.removalStartTimeKey) as? Date {
            self.currentRemovalStartTime = time
        } else {
            self.currentRemovalStartTime = nil
        }

        if let data = defaults.data(forKey: AppGroupConstants.sessionsKey),
           let decoded = try? JSONDecoder().decode([RemovalSession].self, from: data) {
            self.sessions = decoded
        } else {
            self.sessions = []
        }

        if let cycleData = defaults.data(forKey: AppGroupConstants.cyclesKey),
           let decodedCycles = try? JSONDecoder().decode([AlignerCycle].self, from: cycleData) {
            self.cycles = decodedCycles
        } else {
            // Default first cycle if empty
            let firstCycle = AlignerCycle(
                cycleNumber: 1,
                startDate: Calendar.current.startOfDay(for: Date()),
                nominalDays: 14,
                recoveryDays: 0,
                colorHex: CycleColorPalette.color(forCycleNumber: 1)
            )
            self.cycles = [firstCycle]
            self.currentCycleId = firstCycle.id
            saveCycles()
        }

        if let idString = defaults.string(forKey: AppGroupConstants.currentCycleIdKey),
           let uuid = UUID(uuidString: idString) {
            self.currentCycleId = uuid
        } else if let first = cycles.first(where: { !$0.isCompleted }) ?? cycles.last {
            self.currentCycleId = first.id
        }
    }

    public func saveData() {
        defaults.set(isAlignerRemoved, forKey: AppGroupConstants.stateKey)
        defaults.set(currentRemovalStartTime, forKey: AppGroupConstants.removalStartTimeKey)
        if let data = try? JSONEncoder().encode(sessions) {
            defaults.set(data, forKey: AppGroupConstants.sessionsKey)
        }
        saveCycles()
        if let id = currentCycleId {
            defaults.set(id.uuidString, forKey: AppGroupConstants.currentCycleIdKey)
        }

        // Trigger widget reload
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveCycles() {
        if let data = try? JSONEncoder().encode(cycles) {
            defaults.set(data, forKey: AppGroupConstants.cyclesKey)
        }
    }

    // MARK: - Current Active Cycle

    public var currentCycle: AlignerCycle? {
        if let id = currentCycleId, let found = cycles.first(where: { $0.id == id }) {
            return found
        }
        return cycles.first(where: { !$0.isCompleted }) ?? cycles.last
    }

    // MARK: - Actions

    /// Alterna stato: da Rimesso a Tolto e viceversa
    public func toggleAligner() {
        if isAlignerRemoved {
            // Era tolto, adesso viene rimesso
            if let startTime = currentRemovalStartTime {
                let now = Date()
                let newSession = RemovalSession(startDate: startTime, endDate: now)
                sessions.append(newSession)
            }
            isAlignerRemoved = false
            currentRemovalStartTime = nil
        } else {
            // Era indossato, adesso viene tolto
            isAlignerRemoved = true
            currentRemovalStartTime = Date()
        }
        saveData()
    }

    /// Avvia un nuovo ciclo di 14 giorni
    public func startNewCycle(manualNumber: Int? = nil, startDate: Date = Date()) {
        // Se c'è un ciclo attivo, contrassegnalo completato
        if let current = currentCycle, let index = cycles.firstIndex(where: { $0.id == current.id }) {
            cycles[index].isCompleted = true
        }

        let nextNumber = manualNumber ?? ((cycles.map { $0.cycleNumber }.max() ?? 0) + 1)
        let color = CycleColorPalette.color(forCycleNumber: nextNumber)
        let newCycle = AlignerCycle(
            cycleNumber: nextNumber,
            startDate: Calendar.current.startOfDay(for: startDate),
            nominalDays: 14,
            recoveryDays: 0,
            colorHex: color
        )

        cycles.append(newCycle)
        currentCycleId = newCycle.id
        saveData()
    }

    /// Aggiorna i giorni di recupero per un determinato ciclo
    public func setRecoveryDays(for cycleId: UUID, days: Int) {
        if let index = cycles.firstIndex(where: { $0.id == cycleId }) {
            cycles[index].recoveryDays = max(0, days)
            saveCycles()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Aggiunge manualmente una sessione passata
    public func addManualSession(startDate: Date, endDate: Date, note: String = "") {
        guard endDate > startDate else { return }
        let session = RemovalSession(startDate: startDate, endDate: endDate, note: note)
        sessions.append(session)
        saveData()
    }

    /// Rimuove una sessione
    public func deleteSession(_ session: RemovalSession) {
        sessions.removeAll { $0.id == session.id }
        saveData()
    }

    // MARK: - Daily Calculations

    /// Calcola i secondi totali in cui l'apparecchio è stato tolto in un giorno specifico
    public func removedSeconds(for date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

        var totalSeconds: TimeInterval = 0

        // Calcola dalle sessioni concluse
        for session in sessions {
            let sessionStart = session.startDate
            let sessionEnd = session.endDate

            // Controlla intersezione tra la sessione e la giornata
            let overlapStart = max(dayStart, sessionStart)
            let overlapEnd = min(dayEnd, sessionEnd)

            if overlapEnd > overlapStart {
                totalSeconds += overlapEnd.timeIntervalSince(overlapStart)
            }
        }

        // Se oggi è la giornata richiesta ed è attualmente tolto, aggiungi il timer corrente
        if calendar.isDate(date, inSameDayAs: Date()), isAlignerRemoved, let startTime = currentRemovalStartTime {
            let overlapStart = max(dayStart, startTime)
            let overlapEnd = min(dayEnd, Date())
            if overlapEnd > overlapStart {
                totalSeconds += overlapEnd.timeIntervalSince(overlapStart)
            }
        }

        return totalSeconds
    }

    /// Calcola i secondi totali in cui l'apparecchio è stato indossato in un dato giorno (24h - tolto)
    public func wornSeconds(for date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        
        let secondsInDay: TimeInterval
        if isToday {
            // Tempo trascorso dall'inizio della giornata ad adesso
            secondsInDay = Date().timeIntervalSince(calendar.startOfDay(for: date))
        } else {
            secondsInDay = 86400
        }

        let removed = removedSeconds(for: date)
        return max(0, secondsInDay - removed)
    }

    /// Tempo massimo consentito senza apparecchio al giorno: 2 ore (7200 secondi)
    public let dailyAllowedRemovalSeconds: TimeInterval = 2 * 3600 // 2h

    /// Target giornaliero di indossamento: 22 ore (79200 secondi)
    public let dailyTargetWearSeconds: TimeInterval = 22 * 3600 // 22h

    /// Restituisce la percentuale di obiettivo odierno (base 22h)
    public func todayWearProgress() -> Double {
        let worn = wornSeconds(for: Date())
        return min(1.0, worn / dailyTargetWearSeconds)
    }

    // MARK: - Cycle Analytics & Recovery Recommendation

    public struct CycleAnalysis {
        public let cycle: AlignerCycle
        public let totalNominalDays: Int
        public let daysElapsed: Int
        public let totalWornSeconds: TimeInterval
        public let totalDeficitSeconds: TimeInterval
        public let suggestedRecoveryDays: Int
        public let currentRecoveryDays: Int
        public let effectiveEndDate: Date
        public let nextCycleStartDate: Date
    }

    public func analyzeCycle(_ cycle: AlignerCycle) -> CycleAnalysis {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cycleStart = calendar.startOfDay(for: cycle.startDate)

        // Calcola quanti giorni del ciclo sono passati fino ad oggi (max nominalDays)
        let diffDays = calendar.dateComponents([.day], from: cycleStart, to: today).day ?? 0
        let daysPassed = max(1, min(cycle.nominalDays, diffDays + 1))

        var totalDeficitSeconds: TimeInterval = 0
        var totalWornSeconds: TimeInterval = 0

        for dayOffset in 0..<daysPassed {
            if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: cycleStart) {
                let worn = wornSeconds(for: dayDate)
                totalWornSeconds += worn
                
                // Se ha indossato meno di 22h per quel giorno, accumula deficit
                // (Per oggi, confrontiamo proporzionalmente se la giornata non è finita)
                let isToday = calendar.isDate(dayDate, inSameDayAs: today)
                if !isToday {
                    if worn < dailyTargetWearSeconds {
                        totalDeficitSeconds += (dailyTargetWearSeconds - worn)
                    }
                } else {
                    // Oggi: deficit calcolato se le ore rimosse superano le 2h consentite
                    let removedToday = removedSeconds(for: dayDate)
                    if removedToday > dailyAllowedRemovalSeconds {
                        totalDeficitSeconds += (removedToday - dailyAllowedRemovalSeconds)
                    }
                }
            }
        }

        // Calcolo suggerimento giorni di recupero:
        // Ogni giorno extra di recupero fornisce circa 22h di trazione/pressione corretta
        let deficitHours = totalDeficitSeconds / 3600.0
        let suggestedDays: Int
        if deficitHours < 3.0 {
            suggestedDays = 0
        } else {
            // Es. 4-22 ore perse -> 1 giorno; 23-44 ore -> 2 giorni
            suggestedDays = Int(ceil(deficitHours / 22.0))
        }

        return CycleAnalysis(
            cycle: cycle,
            totalNominalDays: cycle.nominalDays,
            daysElapsed: daysPassed,
            totalWornSeconds: totalWornSeconds,
            totalDeficitSeconds: totalDeficitSeconds,
            suggestedRecoveryDays: suggestedDays,
            currentRecoveryDays: cycle.recoveryDays,
            effectiveEndDate: cycle.calculatedEndDate,
            nextCycleStartDate: cycle.nextCycleStartDate
        )
    }

    /// Trova a quale ciclo appartiene una determinata data
    public func cycle(for date: Date) -> AlignerCycle? {
        let calendar = Calendar.current
        let target = calendar.startOfDay(for: date)

        for cycle in cycles {
            let start = calendar.startOfDay(for: cycle.startDate)
            let end = calendar.startOfDay(for: cycle.calculatedEndDate)
            if target >= start && target <= end {
                return cycle
            }
        }
        return nil
    }
}
