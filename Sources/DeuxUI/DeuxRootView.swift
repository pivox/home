import SwiftUI
import DeuxCore
import DeuxPersistence

@MainActor public struct DeuxRootView: View {
    @ObservedObject private var store: HouseholdStore
    private let onShare: () -> Void
    private let onRequestNotifications: () -> Void
    @ViewState private var selectedTab = 0
    @ViewState private var editor: TaskEditorRoute?
    @ViewState private var error: String?
    @ViewState private var lastCompletion: TaskCompletion?
    @ViewState private var feedbackID = UUID()
    @ViewState private var requestNotificationsAfterEditor = false
    @ViewState private var pendingCompletion: HouseTask?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(store: HouseholdStore, onShare: @escaping () -> Void = {}, onRequestNotifications: @escaping () -> Void = {}) {
        self.store = store
        self.onShare = onShare
        self.onRequestNotifications = onRequestNotifications
    }

    public var body: some View {
        Group {
            if store.isLoading && !store.hasHousehold {
                loadingView
            } else if !store.hasHousehold {
                OnboardingView(store: store)
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        TodayView(store: store, add: addTask, edit: editTask, complete: completeTask)
                            .safeAreaInset(edge: .bottom, spacing: 0) { feedbackInset }
                    }
                    .tabItem { Label("Aujourd’hui", systemImage: "sun.max") }.tag(0)
                    NavigationStack {
                        PlanningView(store: store, add: addTask, edit: editTask, complete: completeTask)
                            .safeAreaInset(edge: .bottom, spacing: 0) { feedbackInset }
                    }
                    .tabItem { Label("Planning", systemImage: "calendar") }.tag(1)
                    NavigationStack {
                        HomeView(store: store, onShare: onShare, onRequestNotifications: onRequestNotifications)
                            .safeAreaInset(edge: .bottom, spacing: 0) { feedbackInset }
                    }
                    .tabItem { Label("Maison", systemImage: "house") }.tag(2)
                }
            }
        }
        .tint(DeuxStyle.forest)
        .foregroundStyle(DeuxStyle.ink)
        .preferredColorScheme(.light)
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .sheet(item: $editor, onDismiss: {
            if requestNotificationsAfterEditor {
                requestNotificationsAfterEditor = false
                onRequestNotifications()
            }
        }) { route in
            TaskEditorView(store: store, task: route.task, onRequestNotifications: { requestNotificationsAfterEditor = true })
                .comfortableSheet()
        }
        .confirmationDialog("Qui l’a fait ?", isPresented: Binding(get: { pendingCompletion != nil }, set: { if !$0 { pendingCompletion = nil } }), titleVisibility: .visible, presenting: pendingCompletion) { task in
            ForEach(completerOrder(for: task), id: \.self) { person in
                Button(store.name(for: person)) { completeTask(task, by: person) }
            }
            Button("Annuler", role: .cancel) {}
        } message: { task in Text(task.title) }
        .alert("Impossible de terminer l’action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("D’accord", role: .cancel) { error = nil }
        } message: { Text(error ?? "Réessayez dans un instant.") }
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            HouseIllustration()
            Text("On ouvre la maison…").font(DeuxStyle.title(28))
            ProgressView().tint(DeuxStyle.forest)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DeuxStyle.canvas)
    }

    private func addTask() { editor = TaskEditorRoute(task: nil) }
    private func editTask(_ task: HouseTask) { editor = TaskEditorRoute(task: task) }

    @ViewBuilder private var feedbackInset: some View {
        if let lastCompletion {
            completionFeedback(lastCompletion)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(DeuxStyle.canvas)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func completeTask(_ task: HouseTask) {
        if store.isSharedDevice { pendingCompletion = task }
        else { completeTask(task, by: nil) }
    }

    /// On a shared iPhone, the assigned person is offered first.
    private func completerOrder(for task: HouseTask) -> [Assignee] {
        task.assignee == .personTwo ? [.personTwo, .personOne] : [.personOne, .personTwo]
    }

    private func completeTask(_ task: HouseTask, by person: Assignee?) {
        pendingCompletion = nil
        do {
            let previousIDs = Set(store.completions.map(\.id))
            try store.completeTask(task, by: person)
            let completion = store.completions.first { !previousIDs.contains($0.id) && $0.taskID == task.id }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { lastCompletion = completion }
            let token = UUID()
            feedbackID = token
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(7))
                guard feedbackID == token else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { lastCompletion = nil }
            }
        } catch { self.error = error.localizedDescription }
    }

    private func completionFeedback(_ completion: TaskCompletion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(DeuxStyle.sage)
            Text("Un geste de plus, ensemble.").font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
            Button("Annuler") {
                do {
                    try store.undoCompletion(completion)
                    lastCompletion = nil
                } catch { self.error = error.localizedDescription }
            }
            .font(.subheadline.weight(.bold)).foregroundStyle(DeuxStyle.apricot)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(DeuxStyle.forest, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }
}

private struct TaskEditorRoute: Identifiable {
    let id = UUID()
    let task: HouseTask?
}
