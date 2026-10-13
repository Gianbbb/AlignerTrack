import Foundation
import AppIntents
import WidgetKit

@available(iOS 16.0, *)
public struct ToggleAlignerIntent: AppIntent {
    public static var title: LocalizedStringResource = "Alterna Stato Mascherina"
    public static var description = IntentDescription("Registra quando togli o rimetti l'apparecchio")

    public init() {}

    public func perform() async throws -> some IntentResult {
        let defaults: UserDefaults
        if let shared = UserDefaults(suiteName: AppGroupConstants.groupIdentifier) {
            defaults = shared
        } else {
            defaults = UserDefaults.standard
        }

        let isCurrentlyRemoved = defaults.bool(forKey: AppGroupConstants.stateKey)
        let now = Date()

        if isCurrentlyRemoved {
            // Era tolto, adesso viene rimesso
            if let startTime = defaults.object(forKey: AppGroupConstants.removalStartTimeKey) as? Date {
                var sessions: [RemovalSession] = []
                if let data = defaults.data(forKey: AppGroupConstants.sessionsKey),
                   let decoded = try? JSONDecoder().decode([RemovalSession].self, from: data) {
                    sessions = decoded
                }
                
                let newSession = RemovalSession(startDate: startTime, endDate: now)
                sessions.append(newSession)
                
                if let encoded = try? JSONEncoder().encode(sessions) {
                    defaults.set(encoded, forKey: AppGroupConstants.sessionsKey)
                }
            }
            defaults.set(false, forKey: AppGroupConstants.stateKey)
            defaults.removeObject(forKey: AppGroupConstants.removalStartTimeKey)
        } else {
            // Era indossato, adesso viene tolto
            defaults.set(true, forKey: AppGroupConstants.stateKey)
            defaults.set(now, forKey: AppGroupConstants.removalStartTimeKey)
        }

        // Ricarica la timeline del widget immediatamente
        WidgetCenter.shared.reloadAllTimelines()

        return .result()
    }
}
