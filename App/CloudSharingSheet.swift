import SwiftUI
import UIKit
import CloudKit
import DeuxPersistence

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let store: HouseholdStore
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(share: share, store: store, onError: onError) }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: CKContainer(identifier: store.cloudContainerIdentifier))
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let initialShare: CKShare
        private let store: HouseholdStore
        private let onError: (Error) -> Void
        init(share: CKShare, store: HouseholdStore, onError: @escaping (Error) -> Void) {
            self.initialShare = share
            self.store = store
            self.onError = onError
        }
        func itemTitle(for csc: UICloudSharingController) -> String? { store.householdName }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) { onError(error) }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            guard let share = csc.share else { return }
            Task {
                do { try await store.persistShare(share) }
                catch { onError(error) }
            }
        }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task {
                do { try await store.finishStoppedShare(initialShare) }
                catch { onError(error) }
            }
        }
    }
}
