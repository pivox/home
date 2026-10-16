import Foundation
import UserNotifications
import DeuxCore

/// Notification permission is requested only through an explicit user action.
@MainActor
public final class ReminderScheduler {
    private let center: UNUserNotificationCenter
    private var generation = 0
    private var synchronizationTask: Task<Void, Error>?

    public init(center: UNUserNotificationCenter = .current()) { self.center = center }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func synchronize(tasks: [HouseTask], person: Assignee, now: Date = Date()) async throws {
        generation += 1
        let requestGeneration = generation
        let previous = synchronizationTask
        let operation = Task { @MainActor in
            if let previous { _ = await previous.result }
            try Task.checkCancellation()
            guard self.generation == requestGeneration else { return }
            try await self.apply(tasks: tasks, person: person, now: now)
        }
        synchronizationTask = operation
        try await withTaskCancellationHandler {
            try await operation.value
        } onCancel: {
            operation.cancel()
        }
    }

    private func apply(tasks: [HouseTask], person: Assignee, now: Date) async throws {
        let settings = await center.notificationSettings()
        try Task.checkCancellation()
        let pending = await center.pendingNotificationRequests()
        try Task.checkCancellation()
        let owned = pending.filter { $0.identifier.hasPrefix("adeux-task.") }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: owned)
        var permitted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        #if os(iOS)
        permitted = permitted || settings.authorizationStatus == .ephemeral
        #endif
        guard permitted else { return }
        let calendar = Calendar.current
        for planned in ReminderPlanner.plan(tasks: tasks, person: person, now: now) {
            try Task.checkCancellation()
            let content = UNMutableNotificationContent()
            content.title = "Un petit geste pour la maison"
            content.body = planned.title
            content.sound = .default
            content.threadIdentifier = "adeux-maison"
            content.userInfo = ["taskID": planned.taskID.uuidString]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: planned.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(UNNotificationRequest(identifier: planned.identifier, content: content, trigger: trigger))
        }
    }
}
