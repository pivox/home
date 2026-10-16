import SwiftUI
import DeuxUI

@main
@MainActor
struct ADeuxApp: App {
    @UIApplicationDelegateAdaptor(ADeuxAppDelegate.self) private var appDelegate
    @StateObject private var services = AppServices.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DeuxRootView(
                store: services.store,
                onShare: { Task { await services.prepareShare() } },
                onRequestNotifications: { Task { await services.enableNotifications() } }
            )
            .preferredColorScheme(.light)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .task { await services.start() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await services.refresh() } }
            }
            .sheet(item: $services.presentedShare) { presentation in
                CloudSharingSheet(share: presentation.share, store: services.store) { error in
                    services.message = AppMessage(title: "Partage iCloud", text: error.localizedDescription)
                }
            }
            .alert(item: $services.message) { message in
                Alert(title: Text(message.title), message: Text(message.text), dismissButton: .default(Text("Compris")))
            }
        }
    }
}
