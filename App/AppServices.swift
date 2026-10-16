import Foundation
import Combine
import CloudKit
import UserNotifications
import DeuxCore
import DeuxPersistence
import DeuxNotifications

struct AppMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

struct SharePresentation: Identifiable {
    var id: CKRecord.ID { share.recordID }
    let share: CKShare
}

@MainActor
final class AppServices: ObservableObject {
    static let shared = AppServices()
    let store: HouseholdStore
    private let reminders = ReminderScheduler()
    @Published var presentedShare: SharePresentation?
    @Published var message: AppMessage?
    private var subscriptions: Set<AnyCancellable> = []
    private var acceptedInvitations: Set<CKRecord.ID> = []
    private var refreshTask: Task<Void, Never>?

    private init() {
        let cloudValue = Bundle.main.object(forInfoDictionaryKey: "ADeuxCloudEnabled")
        let enabled = (cloudValue as? NSNumber)?.boolValue ?? (cloudValue as? NSString)?.boolValue ?? false
        store = HouseholdStore(cloudEnabled: enabled)
        Publishers.CombineLatest(store.$tasks, store.$currentPerson)
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleRefresh() }
            .store(in: &subscriptions)
    }

    func start() async {
        await store.load()
        await updateReminders()
    }

    func refresh() async {
        await store.load()
        await updateReminders()
    }

    func enableNotifications() async {
        do {
            let allowed = try await reminders.requestAuthorization()
            guard allowed else {
                message = AppMessage(title: "Les rappels sont désactivés", text: "Vous pouvez les autoriser dans Réglages > Notifications > À deux. Vos tâches restent enregistrées.")
                return
            }
            await updateReminders()
        } catch {
            message = AppMessage(title: "Rappels", text: error.localizedDescription)
        }
    }

    func prepareShare() async {
        guard !store.isLoading else { return }
        do {
            let share = try await store.prepareShare()
            presentedShare = SharePresentation(share: share)
        } catch {
            message = AppMessage(title: "Inviter dans notre maison", text: error.localizedDescription)
        }
    }

    func acceptInvitation(_ metadata: CKShare.Metadata) async {
        let key = metadata.share.recordID
        guard acceptedInvitations.insert(key).inserted else { return }
        await store.load()
        do {
            try await store.acceptShare(metadata)
            message = AppMessage(title: "Bienvenue à deux", text: "L’invitation est acceptée. Le foyer apparaîtra après son import iCloud. Dans Maison, sélectionnez le foyer partagé puis votre prénom sur cet iPhone.")
        } catch {
            acceptedInvitations.remove(key)
            message = AppMessage(title: "Invitation iCloud", text: error.localizedDescription)
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { await updateReminders() }
    }

    private func updateReminders() async {
        do {
            try await reminders.synchronize(tasks: store.tasks, person: store.currentPerson)
        } catch is CancellationError {
            // A newer task snapshot superseded this request.
        } catch {
            message = AppMessage(title: "Un rappel n’a pas pu être programmé", text: error.localizedDescription)
        }
    }
}
