import Testing
import CoreData
import CloudKit
import DeuxCore
@testable import DeuxPersistence

@MainActor
struct HouseholdStoreTests {
    private func makeStore(directory: URL? = nil, defaults: UserDefaults? = nil) -> HouseholdStore {
        HouseholdStore(inMemory: directory == nil, storeDirectory: directory, userDefaults: defaults ?? UserDefaults(suiteName: UUID().uuidString)!)
    }

    @Test func testFreshLoadHasNoHouseholdOrSeedTasksAndIsIdempotent() async throws {
        let store = makeStore()
        await store.load()
        await store.load()
        #expect(!store.isLoading)
        #expect(store.errorMessage == nil)
        #expect(!store.hasHousehold)
        #expect(store.tasks.isEmpty)
        #expect(store.container.persistentStoreCoordinator.persistentStores.count == 1)
    }

    @Test func testHouseholdTaskCompletionUndoAndDelete() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Chez nous", personOne: "Camille", personTwo: "Alex")
        store.currentPerson = .personTwo
        let task = HouseTask(title: "Les plantes", dueDate: Date(timeIntervalSince1970: 1_800_000_000))
        try store.saveTask(task)
        #expect(store.tasks == [task])
        #expect(store.name(for: .personOne) == "Camille")
        try store.completeTask(task, at: Date(timeIntervalSince1970: 1_800_003_600))
        #expect(store.tasks.first?.completedAt != nil)
        #expect(store.completions.first?.completedBy == .personTwo)
        try store.undoCompletion(#require(store.completions.first))
        #expect(store.tasks == [task])
        #expect(store.completions.isEmpty)
        try store.deleteTask(task)
        #expect(store.tasks.isEmpty)
    }

    @Test func testInvalidMutationReportsErrorAndDoesNotChangeSavedTask() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let task = HouseTask(title: "Courses")
        try store.saveTask(task)
        var invalid = task
        invalid.title = "  "
        #expect(throws: (any Error).self) { try store.saveTask(invalid) }
        #expect(store.errorMessage != nil)
        #expect(store.tasks == [task])
        store.clearError()
        #expect(store.errorMessage == nil)
    }

    @Test func testTaskChildrenUseHouseholdStoreAndModelHasInverseRelationships() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let task = HouseTask(title: "Linge", recurrence: .weekly)
        try store.saveTask(task)
        try store.completeTask(task, at: Date())
        let root = try #require(store.activeHousehold)
        let children = try store.container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "TaskRecord"))
        #expect(children.count == 1)
        #expect(children[0].objectID.persistentStore === root.objectID.persistentStore)
        let history = try store.container.viewContext.fetch(NSFetchRequest<NSManagedObject>(entityName: "CompletionRecord"))
        #expect(history.count == 1)
        #expect(history[0].objectID.persistentStore === root.objectID.persistentStore)
        for entity in store.container.managedObjectModel.entities {
            for relationship in entity.relationshipsByName.values {
                #expect(relationship.inverseRelationship != nil)
                #expect(relationship.isOptional)
            }
        }
    }

    @Test func testRealDiskReloadPreservesHouseholdTasksHistoryAndLocalIdentity() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        var original: HouseholdStore? = makeStore(directory: directory, defaults: defaults)
        await original!.load()
        try original!.createHousehold(name: "Notre maison", personOne: "Lou", personTwo: "Sam")
        original!.currentPerson = .personTwo
        let task = HouseTask(title: "Cuisine", recurrence: .weekly)
        try original!.saveTask(task)
        try original!.completeTask(task, at: Date())
        let expectedTasks = original!.tasks
        let expectedHistory = original!.completions
        for persistentStore in original!.container.persistentStoreCoordinator.persistentStores {
            try original!.container.persistentStoreCoordinator.remove(persistentStore)
        }
        original = nil
        let reloaded = makeStore(directory: directory, defaults: defaults)
        await reloaded.load()
        #expect(reloaded.errorMessage == nil)
        #expect(reloaded.householdName == "Notre maison")
        #expect(reloaded.tasks == expectedTasks)
        #expect(reloaded.completions == expectedHistory)
        #expect(reloaded.currentPerson == .personTwo)
        let anotherDevice = makeStore(directory: directory)
        await anotherDevice.load()
        #expect(anotherDevice.currentPerson == .personOne)
    }

    @Test func testCannotCompleteAnyoneWithoutChoosingLocalIdentity() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let task = HouseTask(title: "Cuisine")
        try store.saveTask(task)
        store.currentPerson = .anyone
        #expect(throws: (any Error).self) { try store.completeTask(task, at: Date()) }
        #expect(store.completions.isEmpty)
    }

    @Test func testSharedDeviceRecordsTheChosenCompleter() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let task = HouseTask(title: "Vaisselle", assignee: .personOne)
        try store.saveTask(task)
        store.currentPerson = .anyone
        #expect(store.isSharedDevice)
        #expect(store.deviceName == "A et B")
        #expect(throws: (any Error).self) { try store.completeTask(task, by: .anyone, at: Date()) }
        try store.completeTask(task, by: .personTwo, at: Date())
        #expect(store.completions.first?.completedBy == .personTwo)
    }

    @Test func testLocalSharingFailsWithActionableError() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        do {
            _ = try await store.prepareShare()
            Issue.record("Local mode must not pretend to share")
        } catch {
            #expect(store.errorMessage != nil)
        }
    }
    @Test func testHouseholdSelectionKeepsTasksAndHistoryIsolated() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Premier", personOne: "A", personTwo: "B")
        let firstID = try #require(store.availableHouseholds.first?.id)
        let task = HouseTask(title: "Premier foyer")
        try store.saveTask(task)
        try store.createHousehold(name: "Second", personOne: "C", personTwo: "D")
        #expect(store.tasks.isEmpty)
        #expect(store.householdName == "Second")
        try store.selectHousehold(id: firstID)
        #expect(store.tasks == [task])
        #expect(store.personOneName == "A")
    }

    @Test func testStartersAreExplicitAndDoNotDuplicateOnRetry() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        #expect(store.tasks.isEmpty)
        try store.addStarterTasks()
        let firstIDs = Set(store.tasks.map(\.id))
        #expect(firstIDs.count == 4)
        try store.addStarterTasks()
        #expect(Set(store.tasks.map(\.id)) == firstIDs)
    }

    @Test func testOlderRoutineCompletionCannotUndoNewerCompletion() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let task = HouseTask(title: "Cuisine", recurrence: .daily)
        try store.saveTask(task)
        try store.completeTask(task, at: Date(timeIntervalSince1970: 1_800_000_000))
        let older = try #require(store.completions.first)
        try store.completeTask(task, at: Date(timeIntervalSince1970: 1_800_086_400))
        let expected = store.tasks
        #expect(throws: (any Error).self) { try store.undoCompletion(older) }
        #expect(store.tasks == expected)
        #expect(store.completions.count == 2)
    }

    @Test func testInvalidStoragePathReportsErrorAndCanRetry() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: path) }
        try Data("blocked".utf8).write(to: path)
        let store = makeStore(directory: path)
        await store.load()
        #expect(store.errorMessage != nil)
        #expect(!store.isLoading)
        #expect(!store.hasHousehold)
        try FileManager.default.removeItem(at: path)
        await store.load()
        #expect(store.errorMessage == nil)
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        #expect(store.hasHousehold)
    }

    @Test func testConcurrentLoadCallersAwaitOneStoreLoad() async throws {
        let store = makeStore()
        async let first: Void = store.load()
        async let second: Void = store.load()
        _ = await (first, second)
        #expect(store.errorMessage == nil)
        #expect(!store.isLoading)
        #expect(store.container.persistentStoreCoordinator.persistentStores.count == 1)
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        #expect(store.hasHousehold)
    }

    @Test func testOlderRoutineCannotBeUndoneWhenCompletionsHaveIdenticalTimestamps() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let task = HouseTask(title: "Cuisine", recurrence: .daily)
        try store.saveTask(task)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        try store.completeTask(task, at: timestamp)
        let older = try #require(store.completions.first)
        try store.completeTask(task, at: timestamp)
        #expect(throws: (any Error).self) { try store.undoCompletion(older) }
        #expect(store.completions.count == 2)
    }

    @Test func testCloudConfigurationReusesPrivateDatabaseAndAddsSharedScope() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let local = HouseholdStore(storeDirectory: directory)
        let cloud = HouseholdStore(cloudEnabled: true, storeDirectory: directory)
        #expect(local.container.persistentStoreDescriptions.count == 1)
        #expect(local.container.persistentStoreDescriptions[0].cloudKitContainerOptions == nil)
        #expect(cloud.container.persistentStoreDescriptions.count == 2)
        #expect(cloud.container.persistentStoreDescriptions[0].url == local.container.persistentStoreDescriptions[0].url)
        #expect(cloud.container.persistentStoreDescriptions[0].cloudKitContainerOptions?.databaseScope == .private)
        #expect(cloud.container.persistentStoreDescriptions[1].cloudKitContainerOptions?.databaseScope == .shared)
        #expect(cloud.container.persistentStoreDescriptions[0].cloudKitContainerOptions?.containerIdentifier == cloud.cloudContainerIdentifier)
    }

    @Test func testStoppedShareCannotDeleteLocalModeHousehold() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let task = HouseTask(title: "À conserver")
        try store.saveTask(task)
        let share = CKShare(recordZoneID: CKRecordZone.ID(zoneName: "Unrelated", ownerName: CKCurrentUserDefaultName))
        do {
            try await store.finishStoppedShare(share)
            Issue.record("Local mode must reject CloudKit cleanup")
        } catch {
            #expect(store.hasHousehold)
            #expect(store.tasks == [task])
            #expect(store.errorMessage != nil)
        }
    }

    @Test func testLatestRoutineUndoAfterReschedulingEarlierStillWorks() async throws {
        let store = makeStore()
        await store.load()
        try store.createHousehold(name: "Maison", personOne: "A", personTwo: "B")
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let task = HouseTask(title: "Cuisine", dueDate: timestamp.addingTimeInterval(10 * 86_400), recurrence: .daily)
        try store.saveTask(task)
        try store.completeTask(task, at: timestamp)
        var rescheduled = try #require(store.tasks.first)
        rescheduled.dueDate = timestamp.addingTimeInterval(-86_400)
        try store.saveTask(rescheduled)
        try store.completeTask(rescheduled, at: timestamp.addingTimeInterval(86_400))
        let latest = try #require(store.completions.first)
        try store.undoCompletion(latest)
        #expect(store.tasks.first?.dueDate == rescheduled.dueDate)
        #expect(store.completions.count == 1)
    }

}
