import Foundation

public enum TaskInsights {
    public static func todayTasks(_ tasks: [HouseTask], on date: Date = Date(), calendar: Calendar = .current) -> [HouseTask] {
        tasks.filter { $0.completedAt == nil && calendar.isDate($0.dueDate, inSameDayAs: date) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    public static func overdueTasks(_ tasks: [HouseTask], on date: Date = Date(), calendar: Calendar = .current) -> [HouseTask] {
        let start = calendar.startOfDay(for: date)
        return tasks.filter { $0.completedAt == nil && $0.dueDate < start }
            .sorted { $0.dueDate < $1.dueDate }
    }

    public static func weekCompletions(_ completions: [TaskCompletion], containing date: Date = Date(),
                                       calendar: Calendar = .current) -> [TaskCompletion] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return unique(completions).filter { $0.completedAt >= week.start && $0.completedAt < week.end }
            .sorted { $0.completedAt < $1.completedAt }
    }

    /// Completion snapshots are the sole source of effort; recurring task records are never added again.
    public static func effortMinutes(_ completions: [TaskCompletion], by person: Assignee? = nil) -> Int {
        unique(completions).filter { person == nil || $0.completedBy == person }
            .reduce(0) { $0 + $1.effortMinutes }
    }

    public static func weeklyEffortMinutes(_ completions: [TaskCompletion], by person: Assignee? = nil,
                                           containing date: Date = Date(), calendar: Calendar = .current) -> Int {
        effortMinutes(weekCompletions(completions, containing: date, calendar: calendar), by: person)
    }

    private static func unique(_ completions: [TaskCompletion]) -> [TaskCompletion] {
        var seen = Set<UUID>()
        return completions.filter { seen.insert($0.id).inserted }
    }
}
