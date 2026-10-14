import SwiftUI

@main
struct AlignerTrackApp: App {
    init() {
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "alignertrack" else { return }
        let action = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        
        switch action {
        case "toggle":
            AlignerDataManager.shared.toggleAligner()
        case "tolto", "remove":
            if !AlignerDataManager.shared.isAlignerRemoved {
                AlignerDataManager.shared.toggleAligner()
            }
        case "rimesso", "wear":
            if AlignerDataManager.shared.isAlignerRemoved {
                AlignerDataManager.shared.toggleAligner()
            }
        default:
            break
        }
    }
}
