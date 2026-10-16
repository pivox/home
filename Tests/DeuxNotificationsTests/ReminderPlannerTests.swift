import Foundation
import Testing
import DeuxCore
@testable import DeuxNotifications

struct ReminderPlannerTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func testOnlyFutureOpenTasksForThisPersonAndAnyoneAreScheduled() {
        let own = task("Le linge", assignee: .personOne)
        let shared = task("Les courses", assignee: .anyone)
        var finished = task("Déjà fait", assignee: .personOne)
        finished.completedAt = now
        let other = task("Pas à moi", assignee: .personTwo)
        var disabled = task("Sans rappel", assignee: .anyone)
        disabled.reminderEnabled = false
        var past = task("Trop tard", assignee: .personOne)
        past.dueDate = now.addingTimeInterval(-1)
        let result = ReminderPlanner.plan(tasks: [own, shared, finished, other, disabled, past], person: .personOne, now: now)
        #expect(Set(result.map(\.taskID)) == Set([own.id, shared.id]))
    }

    @Test func testSharedDeviceSchedulesEveryoneTasks() {
        let one = task("Le linge", assignee: .personOne)
        let two = task("Les courses", assignee: .personTwo)
        let anyone = task("La vaisselle", assignee: .anyone)
        let result = ReminderPlanner.plan(tasks: [one, two, anyone], person: .anyone, now: now)
        #expect(Set(result.map(\.taskID)) == Set([one.id, two.id, anyone.id]))
    }

    @Test func testNearestRemindersWinWhenSystemCapacityIsLimited() {
        let tasks = (1...80).reversed().map { offset -> HouseTask in
            var value = task("Tâche \(offset)", assignee: .anyone)
            value.dueDate = now.addingTimeInterval(Double(offset * 60))
            return value
        }
        let result = ReminderPlanner.plan(tasks: tasks, person: .personTwo, now: now)
        #expect(result.count == 60)
        #expect(result.first?.title == "Tâche 1")
        #expect(result.last?.title == "Tâche 60")
        #expect(result.allSatisfy { $0.identifier.hasPrefix("adeux-task.") })
    }

    @Test func testChangingIdentityChangesWhichPersonalRemindersArePlanned() {
        let first = task("Moi", assignee: .personOne)
        let second = task("Toi", assignee: .personTwo)
        #expect(ReminderPlanner.plan(tasks: [first, second], person: .personTwo, now: now).map(\.taskID) == [second.id])
    }

    private func task(_ title: String, assignee: Assignee) -> HouseTask {
        HouseTask(title: title, assignee: assignee, dueDate: now.addingTimeInterval(600), reminderEnabled: true)
    }
}
