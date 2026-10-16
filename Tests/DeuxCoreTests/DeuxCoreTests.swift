import Foundation
import Testing
@testable import DeuxCore

@Suite struct DeuxCoreTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Paris")!
        value.firstWeekday = 2
        value.minimumDaysInFirstWeek = 4
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
    private func task(due: Date? = nil, recurrence: TaskRecurrence = .none) -> HouseTask {
        HouseTask(title: "Arroser les plantes", category: .other, assignee: .personOne,
                  dueDate: due ?? date(2026, 10, 16), recurrence: recurrence, effortMinutes: 15)
    }

    @Test func testOneOffCompletionRecordsSnapshotAndClosesTask() throws {
        let original = task()
        let now = date(2026, 10, 16, 11)
        let result = try TaskRules.complete(task: original, by: .personTwo, at: now, calendar: calendar)
        expectEqual(result.task.completedAt, now)
        expectEqual(result.task.dueDate, original.dueDate)
        expectEqual(result.completion.taskID, original.id)
        expectEqual(result.completion.completedBy, .personTwo)
        expectEqual(result.completion.title, original.title)
        expectEqual(result.completion.effortMinutes, 15)
        expectEqual(result.completion.previousDueDate, original.dueDate)
    }
    @Test func testCannotCompleteAlreadyFinishedTask() throws {
        let done = try TaskRules.complete(task: task(), by: .personOne, calendar: calendar).task
        expectThrows(try TaskRules.complete(task: done, by: .personTwo, calendar: calendar))
    }
    @Test func testDailyOverdueCompletionAdvancesBeyondTodayAtOriginalHour() throws {
        let result = try TaskRules.complete(task: task(due: date(2026, 10, 10, 8, 15), recurrence: .daily),
                                            by: .personOne, at: date(2026, 10, 16, 7), calendar: calendar)
        expectEqual(result.task.dueDate, date(2026, 10, 17, 8, 15))
        expectNil(result.task.completedAt)
    }
    @Test func testWeeklyOverdueCompletionPreservesWeekdayCadence() throws {
        let result = try TaskRules.complete(task: task(due: date(2026, 10, 5), recurrence: .weekly),
                                            by: .personOne, at: date(2026, 10, 16), calendar: calendar)
        expectEqual(result.task.dueDate, date(2026, 10, 19))
    }
    @Test func testEarlyCompletionAdvancesFromScheduledDate() throws {
        let result = try TaskRules.complete(task: task(due: date(2026, 10, 20), recurrence: .weekly),
                                            by: .personOne, at: date(2026, 10, 16), calendar: calendar)
        expectEqual(result.task.dueDate, date(2026, 10, 27))
    }
    @Test func testMonthlyOverdueJumpUsesOriginalDayRatherThanClampingEveryStep() throws {
        let result = try TaskRules.complete(task: task(due: date(2026, 1, 31), recurrence: .monthly),
                                            by: .personOne, at: date(2026, 3, 10), calendar: calendar)
        expectEqual(result.task.dueDate, date(2026, 3, 31))
    }
    @Test func testMonthlyCompletionClampsToShortMonth() throws {
        let result = try TaskRules.complete(task: task(due: date(2026, 1, 31), recurrence: .monthly),
                                            by: .personOne, at: date(2026, 1, 31), calendar: calendar)
        expectEqual(result.task.dueDate, date(2026, 2, 28))
    }
    @Test func testDailyRecurrencePreservesWallClockAcrossDaylightSaving() throws {
        let result = try TaskRules.complete(task: task(due: date(2026, 3, 28, 9), recurrence: .daily),
                                            by: .personOne, at: date(2026, 3, 28, 10), calendar: calendar)
        expectEqual(result.task.dueDate, date(2026, 3, 29, 9))
        expectEqual(result.task.dueDate.timeIntervalSince(date(2026, 3, 28, 9)), 23 * 3600)
    }
    @Test func testUndoRestoresOneOffTask() throws {
        let original = task()
        let done = try TaskRules.complete(task: original, by: .personOne, at: date(2026, 10, 16), calendar: calendar)
        expectEqual(try TaskRules.undo(task: done.task, completion: done.completion), original)
    }
    @Test func testUndoRestoresRecurringDueDate() throws {
        let original = task(recurrence: .weekly)
        let done = try TaskRules.complete(task: original, by: .personOne, at: date(2026, 10, 16), calendar: calendar)
        expectEqual(try TaskRules.undo(task: done.task, completion: done.completion), original)
    }
    @Test func testUndoRejectsDifferentTask() throws {
        let done = try TaskRules.complete(task: task(), by: .personOne, calendar: calendar)
        expectThrows(try TaskRules.undo(task: task(), completion: done.completion))
    }
    @Test func testValidationRejectsWhitespaceTitle() {
        var value = task()
        value.title = " \n \t"
        expectThrows(try TaskRules.validate(value))
    }
    @Test func testValidationEnforcesEffortRange() {
        for minutes in [Int.min, 0, 481, Int.max] {
            var value = task()
            value.effortMinutes = minutes
            expectThrows(try TaskRules.validate(value))
        }
        for minutes in [1, 480] {
            var value = task()
            value.effortMinutes = minutes
            expectNoThrow(try TaskRules.validate(value))
        }
    }
    @Test func testCompletionAlsoValidatesInput() {
        var value = task()
        value.title = ""
        expectThrows(try TaskRules.complete(task: value, by: .personOne, calendar: calendar))
    }
    @Test func testTodayAndOverdueExcludeCompletedTasksAndUseCalendarDays() throws {
        let yesterday = task(due: date(2026, 10, 15, 23))
        let today = task(due: date(2026, 10, 16, 23))
        let tomorrow = task(due: date(2026, 10, 17, 0))
        let completed = try TaskRules.complete(task: task(), by: .personOne, calendar: calendar).task
        let tasks = [tomorrow, completed, today, yesterday]
        expectEqual(TaskInsights.todayTasks(tasks, on: date(2026, 10, 16, 12), calendar: calendar), [today])
        expectEqual(TaskInsights.overdueTasks(tasks, on: date(2026, 10, 16, 12), calendar: calendar), [yesterday])
    }
    @Test func testCivilWeekUsesInjectedMondayBoundaryAcrossYear() throws {
        let dates = [date(2025, 12, 28, 23), date(2025, 12, 29), date(2026, 1, 4, 23), date(2026, 1, 5)]
        let completions = try dates.map { try TaskRules.complete(task: task(), by: .personOne, at: $0, calendar: calendar).completion }
        expectEqual(TaskInsights.weekCompletions(completions, containing: date(2026, 1, 1), calendar: calendar), Array(completions[1...2]))
    }
    @Test func testEffortCountsEachOccurrenceOnceAndCanFilterPerson() throws {
        let original = task(recurrence: .daily)
        let first = try TaskRules.complete(task: original, by: .personOne, at: date(2026, 10, 16), calendar: calendar)
        let second = try TaskRules.complete(task: first.task, by: .personTwo, at: date(2026, 10, 17), calendar: calendar)
        let completions = [first.completion, second.completion, first.completion]
        expectEqual(TaskInsights.effortMinutes(completions), 30)
        expectEqual(TaskInsights.effortMinutes(completions, by: .personOne), 15)
        expectEqual(TaskInsights.weeklyEffortMinutes(completions, containing: date(2026, 10, 16), calendar: calendar), 30)
    }
    @Test func testSnapshotsRoundTripThroughJSON() throws {
        let result = try TaskRules.complete(task: task(), by: .personTwo, calendar: calendar)
        expectEqual(try JSONDecoder().decode(HouseTask.self, from: JSONEncoder().encode(result.task)), result.task)
        expectEqual(try JSONDecoder().decode(TaskCompletion.self, from: JSONEncoder().encode(result.completion)), result.completion)
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T) {
    #expect(actual == expected)
}
private func expectNil<T>(_ actual: T?) {
    #expect(actual == nil)
}
private func expectThrows<T>(_ expression: @autoclosure () throws -> T) {
    #expect(throws: (any Error).self) { _ = try expression() }
}
private func expectNoThrow<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() }
    catch { Issue.record("Unexpected error: \(error)") }
}
