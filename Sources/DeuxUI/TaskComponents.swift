import SwiftUI
import DeuxCore
import DeuxPersistence

enum PersonFilter: String, CaseIterable, Identifiable {
    case everyone, personOne, personTwo, anyone
    var id: Self { self }

    @MainActor func title(in store: HouseholdStore) -> String {
        switch self {
        case .everyone: return "Tout le monde"
        case .personOne: return store.personOneName
        case .personTwo: return store.personTwoName
        case .anyone: return "Au choix"
        }
    }

    func includes(_ task: HouseTask) -> Bool {
        includes(assignee: task.assignee)
    }

    func includes(assignee: Assignee) -> Bool {
        switch self {
        case .everyone: return true
        case .personOne: return assignee == .personOne
        case .personTwo: return assignee == .personTwo
        case .anyone: return assignee == .anyone
        }
    }
}

struct CompletionCard: View {
    let completion: TaskCompletion
    let personName: String
    let undo: () -> Void

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(DeuxStyle.forest)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(completion.title).font(.body.weight(.semibold))
                        Text("\(personName) · \(DeuxStyle.duration(completion.effortMinutes)) · \(completion.completedAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: "fr_FR"))))")
                            .font(.caption).foregroundStyle(DeuxStyle.secondary)
                    }
                    Spacer(minLength: 0)
                }.accessibilityElement(children: .combine)
                Button(action: undo) { Label("Annuler ce geste", systemImage: "arrow.uturn.backward") }
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 5)
                    .accessibilityLabel("Annuler la validation de \(completion.title)")
            }
        }
    }
}

struct PersonFilters: View {
    @ObservedObject var store: HouseholdStore
    @Binding var selection: PersonFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PersonFilter.allCases) { person in
                    FilterPill(title: person.title(in: store), selected: selection == person) { selection = person }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Filtrer par personne")
    }
}

struct TaskRow: View {
    let task: HouseTask
    let assigneeName: String
    let complete: () -> Void
    let edit: () -> Void

    private var isOverdue: Bool {
        task.completedAt == nil && Calendar.current.startOfDay(for: task.dueDate) < Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: complete) {
                Image(systemName: "circle")
                    .font(.system(size: 27, weight: .light))
                    .foregroundStyle(DeuxStyle.forest.opacity(0.60))
                    .frame(width: 44, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Terminer : \(task.title)")
            .accessibilityHint("Enregistrer cette tâche comme réalisée par vous")

            Button(action: edit) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(task.category.title, systemImage: task.category.symbolName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DeuxStyle.secondary)
                        Text(task.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(DeuxStyle.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { taskMetadata }
                            VStack(alignment: .leading, spacing: 6) { taskMetadata }
                        }
                        if isOverdue {
                            Label("En retard · \(DeuxStyle.date(task.dueDate))", systemImage: "clock.arrow.circlepath")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DeuxStyle.rust)
                        } else if !Calendar.current.isDateInToday(task.dueDate) {
                            Text(DeuxStyle.date(task.dueDate, weekday: true))
                                .font(.caption).foregroundStyle(DeuxStyle.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        .foregroundStyle(DeuxStyle.secondary.opacity(0.7)).padding(.top, 25)
                }
                .padding(.vertical, 18)
                .padding(.trailing, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Modifier la tâche")
        }
        .padding(.leading, 8)
        .background(DeuxStyle.paper, in: RoundedRectangle(cornerRadius: 21))
    }

    @ViewBuilder private var taskMetadata: some View {
        Label(DeuxStyle.duration(task.effortMinutes), systemImage: "clock")
            .font(.caption).foregroundStyle(DeuxStyle.secondary)
        Text(assigneeName)
            .font(.caption.weight(.medium))
            .foregroundStyle(DeuxStyle.forest)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(task.assignee == .personTwo ? DeuxStyle.apricot.opacity(0.55) : DeuxStyle.sage.opacity(0.65), in: Capsule())
        if task.recurrence != .none {
            Image(systemName: "repeat").font(.caption).foregroundStyle(DeuxStyle.secondary)
                .accessibilityLabel(task.recurrence.title)
        }
    }
}

struct StoreErrorBanner: View {
    @ObservedObject var store: HouseholdStore

    var body: some View {
        if let error = store.errorMessage {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(DeuxStyle.rust)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Une petite interruption").font(.subheadline.weight(.semibold))
                    Text(error).font(.caption).foregroundStyle(DeuxStyle.secondary)
                    Button("Réessayer") { Task { await store.load() } }.font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
                Button { store.clearError() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Masquer l’erreur")
            }
            .padding(16)
            .background(DeuxStyle.apricot.opacity(0.30), in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
