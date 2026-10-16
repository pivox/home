import SwiftUI
import DeuxCore
import DeuxPersistence

struct TaskEditorView: View {
    @ObservedObject var store: HouseholdStore
    let task: HouseTask?
    let onRequestNotifications: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ViewState private var draft: HouseTask
    @ViewState private var error: String?
    @ViewState private var confirmDelete = false
    @FocusState private var titleFocused: Bool

    init(store: HouseholdStore, task: HouseTask?, onRequestNotifications: @escaping () -> Void) {
        self.store = store
        self.task = task
        self.onRequestNotifications = onRequestNotifications
        _draft = State(initialValue: task ?? HouseTask(title: "", dueDate: Date().addingTimeInterval(3600)))
    }

    private var isValidTitle: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Par exemple, faire les courses", text: $draft.title, axis: .vertical)
                        .font(.title3.weight(.medium))
                        .lineLimit(1...3)
                        .focused($titleFocused)
                        .accessibilityLabel("Nom de la tâche")
                    TextField("Un détail pour se faciliter la vie…", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityLabel("Notes facultatives")
                } header: { Text("Le petit geste") }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 9)], spacing: 9) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            categoryButton(category)
                        }
                    }
                    .padding(.vertical, 7)
                } header: { Text("Dans quelle catégorie ?") }

                Section {
                    personOption(.personOne)
                    personOption(.personTwo)
                    personOption(.anyone)
                } header: { Text("Qui s’en occupe ?") }
                  footer: { Text("« Au choix » : la personne disponible s’en charge. La validation est attribuée à l’identité choisie sur cet appareil.") }

                Section {
                    DatePicker("Échéance", selection: $draft.dueDate, displayedComponents: draft.reminderEnabled ? [.date, .hourAndMinute] : [.date])
                    Picker("Répéter", selection: $draft.recurrence) {
                        ForEach(TaskRecurrence.allCases, id: \.self) { recurrence in
                            Text(recurrence.title).tag(recurrence)
                        }
                    }
                    HStack(spacing: 12) {
                        Label("Temps estimé", systemImage: "clock")
                        Spacer(minLength: 8)
                        TextField("Minutes", value: $draft.effortMinutes, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 66)
                            .minutesKeyboard()
                            .accessibilityLabel("Durée estimée en minutes")
                        Text("min").foregroundStyle(DeuxStyle.secondary)
                    }
                } header: { Text("Le bon moment") }
                  footer: {
                      Text(draft.recurrence == .none
                           ? "De 1 à 480 minutes. Une estimation, pour rendre visible le temps consacré à la maison."
                           : "Après validation, la prochaine échéance sera calculée à partir de la précédente. De 1 à 480 minutes par occurrence.")
                  }

                Section {
                    Toggle(isOn: $draft.reminderEnabled) {
                        Label("Me rappeler à l’échéance", systemImage: "bell")
                    }
                } footer: {
                    Text(draft.reminderEnabled
                         ? "Choisissez l’heure ci-dessus. Après l’enregistrement, iOS vous demandera l’autorisation si nécessaire. Cet appareil rappelle uniquement vos tâches et celles au choix."
                         : "Facultatif. Un petit rappel au moment choisi, avec votre autorisation.")
                }

                if task != nil {
                    Section {
                        Button("Supprimer cette tâche", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                    } footer: { Text("L’historique des gestes déjà réalisés reste conservé.") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DeuxStyle.canvas)
            .navigationTitle(task == nil ? "Un nouveau petit geste" : "Modifier la tâche")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save).fontWeight(.semibold).disabled(!isValidTitle)
                }
            }
            .confirmationDialog("Supprimer « \(draft.title) » ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer la tâche", role: .destructive, action: delete)
                Button("Conserver", role: .cancel) {}
            } message: { Text("Cette tâche et ses prochaines échéances seront supprimées.") }
            .alert("L’action n’a pas abouti", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("D’accord", role: .cancel) { error = nil }
            } message: { Text(error ?? "Réessayez dans un instant.") }
        }
        .tint(DeuxStyle.forest)
        .environment(\.locale, Locale(identifier: "fr_FR"))
        .preferredColorScheme(.light)
    }

    private func categoryButton(_ category: TaskCategory) -> some View {
        let selected = draft.category == category
        return Button { draft.category = category } label: {
            VStack(spacing: 9) {
                Image(systemName: category.symbolName).font(.title3)
                Text(category.title).font(.caption.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 65)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? .white : DeuxStyle.forest)
            .background(selected ? DeuxStyle.forest : DeuxStyle.sage.opacity(0.45), in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func personOption(_ person: Assignee) -> some View {
        let selected = draft.assignee == person
        let name = person == .anyone ? "Au choix" : store.name(for: person)
        return Button { draft.assignee = person } label: {
            HStack(spacing: 13) {
                if person == .anyone {
                    Image(systemName: "hands.sparkles").font(.title3).foregroundStyle(DeuxStyle.forest)
                        .frame(width: 38, height: 38).background(DeuxStyle.sage.opacity(0.6), in: Circle())
                } else { PersonAvatar(name: name, second: person == .personTwo, size: 38) }
                Text(name).foregroundStyle(DeuxStyle.ink).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? DeuxStyle.forest : DeuxStyle.secondary.opacity(0.5))
            }.padding(.vertical, 3).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func save() {
        do {
            draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            try TaskRules.validate(draft)
            try store.saveTask(draft)
            let requestReminder = draft.reminderEnabled
            dismiss()
            if requestReminder { onRequestNotifications() }
        } catch { self.error = error.localizedDescription }
    }

    private func delete() {
        guard let task else { return }
        do { try store.deleteTask(task); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

private extension View {
    @ViewBuilder func minutesKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
