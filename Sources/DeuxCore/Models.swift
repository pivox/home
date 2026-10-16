import Foundation

public enum TaskCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case cleaning, groceries, laundry, admin, meals, other

    public var title: String {
        switch self {
        case .cleaning: return "Ménage"
        case .groceries: return "Courses"
        case .laundry: return "Linge"
        case .admin: return "Administratif"
        case .meals: return "Repas"
        case .other: return "Autre"
        }
    }
    public var symbolName: String {
        switch self {
        case .cleaning: return "sparkles"
        case .groceries: return "basket"
        case .laundry: return "tshirt"
        case .admin: return "doc.text"
        case .meals: return "fork.knife"
        case .other: return "square.grid.2x2"
        }
    }
}

public enum Assignee: String, CaseIterable, Codable, Hashable, Sendable {
    case personOne, personTwo, anyone

    public var title: String {
        switch self {
        case .personOne: return "Personne 1"
        case .personTwo: return "Personne 2"
        case .anyone: return "À se répartir"
        }
    }
    public var symbolName: String { self == .anyone ? "person.2" : "person" }
}

public enum TaskRecurrence: String, CaseIterable, Codable, Hashable, Sendable {
    case none, daily, weekly, monthly

    public var title: String {
        switch self {
        case .none: return "Une seule fois"
        case .daily: return "Chaque jour"
        case .weekly: return "Chaque semaine"
        case .monthly: return "Chaque mois"
        }
    }
}

public struct HouseTask: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var category: TaskCategory
    public var assignee: Assignee
    public var dueDate: Date
    public var recurrence: TaskRecurrence
    public var effortMinutes: Int
    public var reminderEnabled: Bool
    public var createdAt: Date
    public var completedAt: Date?

    public init(id: UUID = UUID(), title: String, notes: String = "", category: TaskCategory = .other,
                assignee: Assignee = .anyone, dueDate: Date = Date(), recurrence: TaskRecurrence = .none,
                effortMinutes: Int = 15, reminderEnabled: Bool = false,
                createdAt: Date = Date(), completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.assignee = assignee
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.effortMinutes = effortMinutes
        self.reminderEnabled = reminderEnabled
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

/// Immutable-in-time details of one completed occurrence, independent of later task edits.
public struct TaskCompletion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var taskID: UUID
    public var title: String
    public var completedBy: Assignee
    public var completedAt: Date
    public var effortMinutes: Int
    public var previousDueDate: Date
    public var recurrence: TaskRecurrence

    public init(id: UUID = UUID(), taskID: UUID, title: String, completedBy: Assignee,
                completedAt: Date = Date(), effortMinutes: Int = 15,
                previousDueDate: Date = Date(), recurrence: TaskRecurrence = .none) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.completedBy = completedBy
        self.completedAt = completedAt
        self.effortMinutes = effortMinutes
        self.previousDueDate = previousDueDate
        self.recurrence = recurrence
    }
}
