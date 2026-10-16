import Foundation
import DeuxCore

public struct PlannedReminder: Equatable, Sendable {
    public let taskID: UUID
    public let title: String
    public let fireDate: Date
    public var identifier: String { "adeux-task.\(taskID.uuidString)" }
}

/// Keeps headroom below iOS's pending-notification limit. Only the active device's
/// identity and unclaimed tasks produce reminders; the household data is untouched.
public enum ReminderPlanner {
    public static func plan(tasks: [HouseTask], person: Assignee, now: Date = Date(), limit: Int = 60) -> [PlannedReminder] {
        tasks
            .filter { $0.reminderEnabled && $0.completedAt == nil && $0.dueDate > now && ($0.assignee == person || $0.assignee == .anyone) }
            .sorted { $0.dueDate == $1.dueDate ? $0.id.uuidString < $1.id.uuidString : $0.dueDate < $1.dueDate }
            .prefix(max(0, min(limit, 60)))
            .map { PlannedReminder(taskID: $0.id, title: $0.title, fireDate: $0.dueDate) }
    }
}
