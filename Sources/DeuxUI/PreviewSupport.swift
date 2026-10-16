import SwiftUI
import DeuxPersistence

/// Real screen content for previews. The caller supplies an isolated demonstration store.
/// This omits native tab chrome so macOS snapshots remain useful without an iOS simulator.
@MainActor public struct DeuxScreenPreview: View {
    public enum Screen: String, CaseIterable, Sendable {
        case today, planning, home, onboarding
    }

    @ObservedObject private var store: HouseholdStore
    private let screen: Screen

    public init(store: HouseholdStore, screen: Screen) {
        self.store = store
        self.screen = screen
    }

    public var body: some View {
        Group {
            switch screen {
            case .today: TodayView(store: store, add: {}, edit: { _ in }, complete: { _ in })
            case .planning: PlanningView(store: store, add: {}, edit: { _ in }, complete: { _ in })
            case .home: HomeView(store: store, onShare: {}, onRequestNotifications: {})
            case .onboarding: OnboardingView(store: store)
            }
        }
        .tint(DeuxStyle.forest)
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: "fr_FR"))
    }
}
