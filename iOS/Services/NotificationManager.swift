import Foundation
import UserNotifications

public class NotificationManager {
    public static let shared = NotificationManager()

    private let removalReminderId = "aligner_removal_reminder"
    private let cycleChangeReminderId = "aligner_cycle_change_reminder"

    private init() {}

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    /// Programma una notifica dopo N minuti dalla rimozione
    public func scheduleRemovalReminder(minutes: Int) {
        cancelRemovalReminder()
        guard minutes > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "⏰ Ricordati la Mascherina!"
        content.body = "L'apparecchio è tolto da \(minutes) minuti. Rimettilo per mantenere il ritmo del trattamento!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: removalReminderId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Cancella la notifica di promemoria rimozione (quando la mascherina viene rimessa)
    public func cancelRemovalReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [removalReminderId])
    }

    /// Programma un avviso per il giorno del cambio mascherina (alle ore 09:00 e alle 20:00)
    public func scheduleCycleChangeNotification(on date: Date, nextCycleNumber: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [cycleChangeReminderId])

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = 20
        dateComponents.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "✨ Tempo di Cambio Mascherina!"
        content.body = "Oggi è il momento di passare alla Mascherina #\(nextCycleNumber). Non dimenticare di scattare la foto del sorriso!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: cycleChangeReminderId, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Notifica istantanea per fine pulizia o fine chewies
    public func scheduleTimerNotification(title: String, body: String, delaySeconds: TimeInterval, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
