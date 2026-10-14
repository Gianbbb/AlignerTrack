import SwiftUI

public struct ContentView: View {
    @StateObject private var dataManager = AlignerDataManager.shared
    @State private var selectedTab: TabItem = .today

    public enum TabItem: String, Hashable {
        case today = "Oggi"
        case calendar = "Calendario"
        case treatment = "Trattamento"
        case recovery = "Recupero"
        case stats = "Statistiche"
        case history = "Storico"
    }

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            TodayDashboardView(dataManager: dataManager)
                .tabItem {
                    Label("Oggi", systemImage: "clock.badge.checkmark.fill")
                }
                .tag(TabItem.today)

            CalendarView(dataManager: dataManager)
                .tabItem {
                    Label("Calendario", systemImage: "calendar")
                }
                .tag(TabItem.calendar)

            TreatmentManagementView(dataManager: dataManager)
                .tabItem {
                    Label("Trattamento", systemImage: "slider.horizontal.3")
                }
                .tag(TabItem.treatment)

            RecoveryManagementView(dataManager: dataManager)
                .tabItem {
                    Label("Recupero", systemImage: "bandage.fill")
                }
                .tag(TabItem.recovery)

            StatsView(dataManager: dataManager)
                .tabItem {
                    Label("Statistiche", systemImage: "chart.bar.xaxis")
                }
                .tag(TabItem.stats)
        }
        .tint(Color.emeraldMint)
    }
}

#Preview {
    ContentView()
}
