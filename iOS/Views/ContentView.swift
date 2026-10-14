import SwiftUI

public struct ContentView: View {
    @StateObject private var dataManager = AlignerDataManager.shared
    @State private var selectedTab: TabItem = .today

    public enum TabItem: String, Hashable {
        case today = "Oggi"
        case calendar = "Calendario"
        case tools = "Strumenti"
        case treatment = "Trattamento"
        case stats = "Statistiche"
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

            CareToolsView(dataManager: dataManager)
                .tabItem {
                    Label("Strumenti", systemImage: "cross.case.fill")
                }
                .tag(TabItem.tools)

            TreatmentManagementView(dataManager: dataManager)
                .tabItem {
                    Label("Trattamento", systemImage: "slider.horizontal.3")
                }
                .tag(TabItem.treatment)

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
