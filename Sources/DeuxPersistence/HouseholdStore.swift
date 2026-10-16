import Foundation
import CoreData
import CloudKit
import Combine
import DeuxCore

public struct HouseholdSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let isShared: Bool

    public init(id: UUID, name: String, isShared: Bool) {
        self.id = id
        self.name = name
        self.isShared = isShared
    }
}

public enum HouseholdStoreError: LocalizedError {
    case notReady, noHousehold, invalidHousehold, missingTask, missingCompletion, staleCompletion, chooseIdentity, cloudDisabled, unavailableShare, invalidRecord

    public var errorDescription: String? {
        switch self {
        case .notReady: return "Le stockage n’est pas encore prêt. Réessayez après le chargement."
        case .noHousehold: return "Créez ou sélectionnez un foyer pour continuer."
        case .invalidHousehold: return "Renseignez le nom du foyer et les deux prénoms."
        case .missingTask: return "Cette tâche n’est plus disponible. Actualisez le foyer."
        case .missingCompletion: return "Cette validation n’est plus disponible."
        case .staleCompletion: return "Annulez d’abord la validation la plus récente de cette routine."
        case .chooseIdentity: return "Indiquez qui a réalisé cette tâche."
        case .cloudDisabled: return "Le partage n’est pas activé dans cette version. Vos tâches restent disponibles sur cet iPhone."
        case .unavailableShare: return "Le partage iCloud est indisponible pour le moment. Réessayez."
        case .invalidRecord: return "Une donnée du foyer est illisible. Elle a été conservée ; réessayez après la synchronisation."
        }
    }
}

@MainActor
public final class HouseholdStore: ObservableObject {
    @Published public private(set) var tasks: [HouseTask] = []
    @Published public private(set) var completions: [TaskCompletion] = []
    @Published public private(set) var householdName = ""
    @Published public private(set) var personOneName = ""
    @Published public private(set) var personTwoName = ""
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var cloudStatus: String
    @Published public private(set) var hasHousehold = false
    @Published public private(set) var availableHouseholds: [HouseholdSummary] = []
    @Published public var currentPerson: Assignee {
        didSet { defaults.set(currentPerson.rawValue, forKey: "ADeux.currentPerson") }
    }

    public let container: NSPersistentCloudKitContainer
    public private(set) var activeHousehold: NSManagedObject?
    public private(set) var sharedStore: NSPersistentStore?
    public let cloudContainerIdentifier: String
    public let cloudEnabled: Bool

    private let defaults: UserDefaults
    private let directory: URL
    private let inMemory: Bool
    private var isReady = false
    private var loadTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var shareStores: [CKRecord.ID: NSPersistentStore] = [:]
    private var context: NSManagedObjectContext { container.viewContext }

    public init(inMemory: Bool = false, cloudEnabled: Bool = false, storeDirectory: URL? = nil, userDefaults: UserDefaults = .standard) {
        self.inMemory = inMemory
        self.cloudEnabled = cloudEnabled && !inMemory
        self.defaults = userDefaults
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        self.directory = storeDirectory ?? (inMemory ? FileManager.default.temporaryDirectory : supportDirectory).appendingPathComponent("ADeux", isDirectory: true)
        cloudContainerIdentifier = Bundle.main.object(forInfoDictionaryKey: "ADeuxCloudContainerIdentifier") as? String ?? "iCloud.fr.adeux.app"
        currentPerson = userDefaults.string(forKey: "ADeux.currentPerson").flatMap(Assignee.init(rawValue:)) ?? .personOne
        cloudStatus = self.cloudEnabled ? "iCloud configuré — connexion en cours" : "Sur cet appareil"
        container = NSPersistentCloudKitContainer(name: "ADeux", managedObjectModel: ManagedModel.make())
        let primary = NSPersistentStoreDescription(url: directory.appendingPathComponent("private.sqlite"))
        primary.type = inMemory ? NSInMemoryStoreType : NSSQLiteStoreType
        primary.shouldMigrateStoreAutomatically = true
        primary.shouldInferMappingModelAutomatically = true
        primary.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        if self.cloudEnabled {
            primary.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        var descriptions = [primary]
        if self.cloudEnabled {
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudContainerIdentifier)
            options.databaseScope = .private
            primary.cloudKitContainerOptions = options
            let shared = NSPersistentStoreDescription(url: directory.appendingPathComponent("shared.sqlite"))
            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudContainerIdentifier)
            sharedOptions.databaseScope = .shared
            shared.cloudKitContainerOptions = sharedOptions
            shared.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            shared.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            descriptions.append(shared)
        }
        container.persistentStoreDescriptions = descriptions
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        observers.append(NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isReady else { return }
                do { try self.refresh() } catch { self.report(error) }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: container, queue: .main) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error = event.error {
                    self.cloudStatus = "iCloud — synchronisation à réessayer"
                    self.report(error)
                } else if event.endDate != nil, event.succeeded {
                    self.cloudStatus = "iCloud — dernière opération réussie"
                    if self.isReady { do { try self.refresh() } catch { self.report(error) } }
                } else {
                    self.cloudStatus = "iCloud — synchronisation en cours"
                }
            }
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    /// Concurrent callers await the same loading operation. A failed load may be retried.
    public func load() async {
        if isReady {
            do { try refresh() } catch { report(error) }
            return
        }
        if let loadTask { await loadTask.value; return }
        let task = Task<Void, Never> { @MainActor [weak self] in await self?.loadStores() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    private func loadStores() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if !inMemory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
            let expected = container.persistentStoreDescriptions.count
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let progress = StoreLoadingProgress(expected: expected, continuation: continuation)
                container.loadPersistentStores { _, error in progress.finished(error) }
            }
            sharedStore = container.persistentStoreCoordinator.persistentStores.first { $0.url?.lastPathComponent == "shared.sqlite" }
            isReady = true
            try refresh()
            errorMessage = nil
            if cloudEnabled { cloudStatus = "iCloud configuré — synchronisation en attente" }
        } catch {
            isReady = false
            report(error)
            // Detach partial loads before retry; never remove a database file.
            for store in container.persistentStoreCoordinator.persistentStores {
                try? container.persistentStoreCoordinator.remove(store)
            }
        }
    }

    public func refresh() throws {
        guard isReady else { throw HouseholdStoreError.notReady }
        let request = NSFetchRequest<NSManagedObject>(entityName: "HouseholdRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        let roots = try context.fetch(request)
        let summaries = try roots.map { root -> HouseholdSummary in
            guard let id = root.value(forKey: "id") as? UUID else { throw HouseholdStoreError.invalidRecord }
            return HouseholdSummary(id: id, name: root.value(forKey: "name") as? String ?? "Foyer", isShared: root.objectID.persistentStore === sharedStore)
        }
        let selected = defaults.string(forKey: "ADeux.selectedHousehold").flatMap(UUID.init(uuidString:))
        let root = roots.first { ($0.value(forKey: "id") as? UUID) == selected } ?? roots.first
        let loadedTasks: [HouseTask] = try children("TaskRecord", root: root).map { try decode($0) }
        let history: [TaskCompletion] = try children("CompletionRecord", root: root).map { try decode($0) }
        availableHouseholds = summaries
        activeHousehold = root
        hasHousehold = root != nil
        householdName = root?.value(forKey: "name") as? String ?? ""
        personOneName = root?.value(forKey: "personOneName") as? String ?? ""
        personTwoName = root?.value(forKey: "personTwoName") as? String ?? ""
        tasks = loadedTasks.sorted { $0.dueDate == $1.dueDate ? $0.id.uuidString < $1.id.uuidString : $0.dueDate < $1.dueDate }
        completions = history.sorted { $0.completedAt > $1.completedAt }
    }

    public func createHousehold(name: String, personOne: String, personTwo: String) throws {
        try mutate {
            try validateNames(name, personOne, personTwo)
            let root = NSEntityDescription.insertNewObject(forEntityName: "HouseholdRecord", into: context)
            guard let privateStore = container.persistentStoreCoordinator.persistentStores.first(where: { $0 !== sharedStore }) else { throw HouseholdStoreError.notReady }
            context.assign(root, to: privateStore)
            let id = UUID()
            root.setValue(id, forKey: "id")
            root.setValue(Date(), forKey: "createdAt")
            setNames(root, name, personOne, personTwo)
            try context.save()
            defaults.set(id.uuidString, forKey: "ADeux.selectedHousehold")
        }
    }

    public func updateHousehold(name: String, personOne: String, personTwo: String) throws {
        try mutate {
            try validateNames(name, personOne, personTwo)
            setNames(try requireRoot(), name, personOne, personTwo)
        }
    }

    public func selectHousehold(id: UUID) throws {
        do {
            guard availableHouseholds.contains(where: { $0.id == id }) else { throw HouseholdStoreError.noHousehold }
            defaults.set(id.uuidString, forKey: "ADeux.selectedHousehold")
            try refresh()
        } catch { report(error); throw error }
    }

    public func saveTask(_ task: HouseTask) throws {
        try mutate {
            try TaskRules.validate(task)
            try write(task, entity: "TaskRecord", id: task.id)
        }
    }

    public func deleteTask(_ task: HouseTask) throws {
        try mutate { context.delete(try requireTask(task.id)) }
    }

    /// `true` when both people use this device; each completion then names who did it.
    public var isSharedDevice: Bool { currentPerson == .anyone }

    public func completeTask(_ task: HouseTask, by person: Assignee? = nil, at date: Date = Date()) throws {
        try mutate {
            let completer = person ?? currentPerson
            guard completer != .anyone else { throw HouseholdStoreError.chooseIdentity }
            let record = try requireTask(task.id)
            let saved: HouseTask = try decode(record)
            let result = try TaskRules.complete(task: saved, by: completer, at: date, calendar: .current)
            record.setValue(try JSONEncoder().encode(result.task), forKey: "payload")
            try write(result.completion, entity: "CompletionRecord", id: result.completion.id)
        }
    }

    public func undoCompletion(_ completion: TaskCompletion) throws {
        try mutate {
            guard let completionRecord = try record(entity: "CompletionRecord", id: completion.id) else { throw HouseholdStoreError.missingCompletion }
            let savedCompletion: TaskCompletion = try decode(completionRecord)
            let taskRecord = try requireTask(savedCompletion.taskID)
            let savedTask: HouseTask = try decode(taskRecord)
            // Undo only the latest validation; an older routine entry would rewind a newer cycle.
            let history: [TaskCompletion] = try children("CompletionRecord", root: activeHousehold).map { try decode($0) }
            guard !history.contains(where: {
                $0.taskID == savedCompletion.taskID &&
                ($0.completedAt > savedCompletion.completedAt ||
                 ($0.completedAt == savedCompletion.completedAt && $0.previousDueDate > savedCompletion.previousDueDate))
            }) else { throw HouseholdStoreError.staleCompletion }
            let restored = try TaskRules.undo(task: savedTask, completion: savedCompletion)
            taskRecord.setValue(try JSONEncoder().encode(restored), forKey: "payload")
            context.delete(completionRecord)
        }
    }

    public func addStarterTasks() throws {
        try mutate {
            let starters: [(String, TaskCategory, TaskRecurrence, Int)] = [
                ("Faire les courses", .groceries, .weekly, 30), ("Passer l’aspirateur", .cleaning, .weekly, 20),
                ("Lancer une lessive", .laundry, .weekly, 15), ("Préparer les repas", .meals, .daily, 30)
            ]
            let existing = Set(tasks.map(\.title))
            for (title, category, recurrence, minutes) in starters where !existing.contains(title) {
                let task = HouseTask(title: title, category: category, dueDate: Date(), recurrence: recurrence, effortMinutes: minutes)
                try write(task, entity: "TaskRecord", id: task.id)
            }
        }
    }

    public func name(for person: Assignee) -> String {
        switch person {
        case .personOne: return personOneName.isEmpty ? "Personne 1" : personOneName
        case .personTwo: return personTwoName.isEmpty ? "Personne 2" : personTwoName
        case .anyone: return "À deux"
        }
    }

    /// Greeting label for this device: one first name, or both when the iPhone is shared.
    public var deviceName: String {
        isSharedDevice ? "\(name(for: .personOne)) et \(name(for: .personTwo))" : name(for: currentPerson)
    }

    public func clearError() { errorMessage = nil }

    public func acceptShare(_ metadata: CKShare.Metadata) async throws {
        await load()
        do {
            guard cloudEnabled else { throw HouseholdStoreError.cloudDisabled }
            guard isReady, let sharedStore else { throw HouseholdStoreError.notReady }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
            cloudStatus = "Invitation acceptée — réception du foyer en cours"
            try refresh()
        } catch { report(error); throw error }
    }

    public func prepareShare() async throws -> CKShare {
        await load()
        do {
            guard cloudEnabled else { throw HouseholdStoreError.cloudDisabled }
            let root = try requireRoot()
            try context.save()
            guard let rootStore = root.objectID.persistentStore else { throw HouseholdStoreError.notReady }
            let title = householdName
            if let existing = try container.fetchShares(matching: [root.objectID])[root.objectID] {
                shareStores[existing.recordID] = rootStore
                return existing
            }
            let share = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKShare, Error>) in
                container.share([root], to: nil) { _, share, _, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let share { continuation.resume(returning: share) }
                    else { continuation.resume(throwing: HouseholdStoreError.unavailableShare) }
                }
            }
            share[CKShare.SystemFieldKey.title] = title as CKRecordValue
            shareStores[share.recordID] = rootStore
            share.publicPermission = .none
            try await persistShare(share)
            return share
        } catch { report(error); throw error }
    }

    public func persistShare(_ share: CKShare) async throws {
        do {
            guard cloudEnabled else { throw HouseholdStoreError.cloudDisabled }
            guard isReady else { throw HouseholdStoreError.notReady }
            let store = try persistentStore(for: share)
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                container.persistUpdatedShare(share, in: store) { _, error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } catch { report(error); throw error }
    }

    /// Called after the native sheet confirms leaving/stopping a share.
    /// Only a participant's shared store may be purged; an owner's private data is retained.
    public func finishStoppedShare(_ share: CKShare) async throws {
        do {
            guard cloudEnabled else { throw HouseholdStoreError.cloudDisabled }
            guard isReady else { throw HouseholdStoreError.notReady }
            let sourceStore = try persistentStore(for: share)
            if let sharedStore, sourceStore === sharedStore {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: sharedStore) { _, error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
                shareStores.removeValue(forKey: share.recordID)
                context.refreshAllObjects()
                cloudStatus = "Vous avez quitté le foyer partagé"
            } else {
                cloudStatus = "Partage arrêté — actualisation iCloud en attente"
            }
            try refresh()
        } catch { report(error); throw error }
    }

    private func persistentStore(for share: CKShare) throws -> NSPersistentStore {
        if let cached = shareStores[share.recordID] { return cached }
        for candidate in container.persistentStoreCoordinator.persistentStores {
            if try container.fetchShares(in: candidate).contains(where: { $0.recordID == share.recordID }) {
                shareStores[share.recordID] = candidate
                return candidate
            }
        }
        throw HouseholdStoreError.unavailableShare
    }

    private func mutate(_ changes: () throws -> Void) throws {
        do {
            guard isReady else { throw HouseholdStoreError.notReady }
            try changes()
            if context.hasChanges { try context.save() }
            try refresh()
        } catch {
            context.rollback()
            report(error)
            throw error
        }
    }

    private func requireRoot() throws -> NSManagedObject {
        guard isReady else { throw HouseholdStoreError.notReady }
        guard let activeHousehold else { throw HouseholdStoreError.noHousehold }
        return activeHousehold
    }

    private func children(_ entity: String, root: NSManagedObject?) throws -> [NSManagedObject] {
        guard let root else { return [] }
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "household == %@", root)
        return try context.fetch(request)
    }

    private func record(entity: String, id: UUID) throws -> NSManagedObject? {
        let root = try requireRoot()
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@ AND household == %@", id as NSUUID, root)
        return try context.fetch(request).first
    }

    private func requireTask(_ id: UUID) throws -> NSManagedObject {
        guard let result = try record(entity: "TaskRecord", id: id) else { throw HouseholdStoreError.missingTask }
        return result
    }

    private func write<T: Encodable>(_ value: T, entity: String, id: UUID) throws {
        let root = try requireRoot()
        let object: NSManagedObject
        if let existing = try record(entity: entity, id: id) { object = existing }
        else {
            object = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
            guard let store = root.objectID.persistentStore else { throw HouseholdStoreError.notReady }
            context.assign(object, to: store)
            object.setValue(id, forKey: "id")
            object.setValue(root, forKey: "household")
        }
        object.setValue(try JSONEncoder().encode(value), forKey: "payload")
    }

    private func decode<T: Decodable>(_ object: NSManagedObject) throws -> T {
        guard let data = object.value(forKey: "payload") as? Data else { throw HouseholdStoreError.invalidRecord }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validateNames(_ names: String...) throws {
        guard names.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw HouseholdStoreError.invalidHousehold }
    }

    private func setNames(_ root: NSManagedObject, _ name: String, _ one: String, _ two: String) {
        root.setValue(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "name")
        root.setValue(one.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "personOneName")
        root.setValue(two.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "personTwoName")
    }

    private func report(_ error: Error) { errorMessage = error.localizedDescription }
}

private final class StoreLoadingProgress {
    private let lock = NSLock()
    private var remaining: Int
    private var firstError: Error?
    private let continuation: CheckedContinuation<Void, Error>

    init(expected: Int, continuation: CheckedContinuation<Void, Error>) {
        remaining = expected
        self.continuation = continuation
    }

    func finished(_ error: Error?) {
        lock.lock()
        firstError = firstError ?? error
        remaining -= 1
        let done = remaining == 0
        let result = firstError
        lock.unlock()
        if done {
            if let result { continuation.resume(throwing: result) } else { continuation.resume() }
        }
    }
}
