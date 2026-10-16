import Foundation

public enum TaskRuleError: Error, Equatable, LocalizedError, Sendable {
    case emptyTitle
    case invalidEffort
    case alreadyCompleted
    case unrelatedCompletion
    case taskChangedSinceCompletion
    case invalidDate

    public var errorDescription: String? {
        switch self {
        case .emptyTitle: return "Donnez un nom à cette tâche."
        case .invalidEffort: return "La durée doit être comprise entre 1 et 480 minutes."
        case .alreadyCompleted: return "Cette tâche est déjà terminée."
        case .unrelatedCompletion: return "Cette validation appartient à une autre tâche."
        case .taskChangedSinceCompletion: return "Cette tâche a changé depuis sa validation."
        case .invalidDate: return "La prochaine échéance ne peut pas être calculée."
        }
    }
}

public enum TaskRules {
    public static func validate(_ task: HouseTask) throws {
        guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskRuleError.emptyTitle
        }
        guard (1...480).contains(task.effortMinutes) else { throw TaskRuleError.invalidEffort }
        guard task.dueDate.timeIntervalSinceReferenceDate.isFinite,
              task.createdAt.timeIntervalSinceReferenceDate.isFinite else { throw TaskRuleError.invalidDate }
    }

    public static func complete(task: HouseTask, by person: Assignee, at date: Date = Date(),
                                calendar: Calendar = .current) throws -> (task: HouseTask, completion: TaskCompletion) {
        try validate(task)
        guard task.completedAt == nil else { throw TaskRuleError.alreadyCompleted }
        guard date.timeIntervalSinceReferenceDate.isFinite else { throw TaskRuleError.invalidDate }
        var updated = task
        if task.recurrence == .none {
            updated.completedAt = date
        } else {
            updated.dueDate = try nextDueDate(for: task, completedAt: date, calendar: calendar)
        }
        let completion = TaskCompletion(taskID: task.id, title: task.title, completedBy: person,
                                        completedAt: date, effortMinutes: task.effortMinutes,
                                        previousDueDate: task.dueDate, recurrence: task.recurrence)
        return (updated, completion)
    }

    /// The repository must only undo the latest remaining completion for a recurring task.
    public static func undo(task: HouseTask, completion: TaskCompletion) throws -> HouseTask {
        guard task.id == completion.taskID else { throw TaskRuleError.unrelatedCompletion }
        guard task.recurrence == completion.recurrence else { throw TaskRuleError.taskChangedSinceCompletion }
        if task.recurrence == .none {
            guard task.completedAt == completion.completedAt else { throw TaskRuleError.taskChangedSinceCompletion }
        } else {
            guard task.completedAt == nil, task.dueDate > completion.previousDueDate else {
                throw TaskRuleError.taskChangedSinceCompletion
            }
        }
        var restored = task
        restored.dueDate = completion.previousDueDate
        restored.completedAt = nil
        return restored
    }

    private static func nextDueDate(for task: HouseTask, completedAt date: Date, calendar: Calendar) throws -> Date {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
            throw TaskRuleError.invalidDate
        }
        let component: Calendar.Component
        let step: Int
        switch task.recurrence {
        case .daily: (component, step) = (.day, 1)
        case .weekly: (component, step) = (.day, 7)
        case .monthly: (component, step) = (.month, 1)
        case .none: return task.dueDate
        }
        let elapsed = calendar.dateComponents([component], from: task.dueDate, to: tomorrow).value(for: component) ?? 0
        var intervalCount = max(1, elapsed / step)
        // Always add from the scheduled date: repeated month additions would drift after February.
        while true {
            let (amount, overflow) = intervalCount.multipliedReportingOverflow(by: step)
            guard !overflow, let candidate = calendar.date(byAdding: component, value: amount, to: task.dueDate) else {
                throw TaskRuleError.invalidDate
            }
            if candidate >= tomorrow { return candidate }
            let (next, incrementOverflow) = intervalCount.addingReportingOverflow(1)
            guard !incrementOverflow else { throw TaskRuleError.invalidDate }
            intervalCount = next
        }
    }
}
