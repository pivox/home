import SwiftUI
import DeuxCore
import DeuxPersistence

struct ProfileEditorView: View {
    @ObservedObject var store: HouseholdStore
    @Environment(\.dismiss) private var dismiss
    @ViewState private var householdName: String
    @ViewState private var firstName: String
    @ViewState private var secondName: String
    @ViewState private var identity: Assignee
    @ViewState private var error: String?

    init(store: HouseholdStore) {
        self.store = store
        _householdName = State(initialValue: store.householdName)
        _firstName = State(initialValue: store.personOneName)
        _secondName = State(initialValue: store.personTwoName)
        _identity = State(initialValue: store.currentPerson)
    }

    private var isValid: Bool {
        [householdName, firstName, secondName].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Votre foyer") {
                    TextField("Nom du foyer", text: $householdName).accessibilityLabel("Nom du foyer")
                }
                Section {
                    TextField("Premier prénom", text: $firstName).textContentType(.givenName).accessibilityLabel("Premier prénom")
                    TextField("Deuxième prénom", text: $secondName).textContentType(.givenName).accessibilityLabel("Deuxième prénom")
                } header: { Text("Votre équipe") }
                  footer: { Text("Les tâches restent liées à la même personne lorsque vous changez son prénom.") }
                Section {
                    Picker("Je suis", selection: $identity) {
                        Text(firstName.isEmpty ? "Première personne" : firstName).tag(Assignee.personOne)
                        Text(secondName.isEmpty ? "Deuxième personne" : secondName).tag(Assignee.personTwo)
                        Text("Nous deux, sur ce même iPhone").tag(Assignee.anyone)
                    }.pickerStyle(.inline)
                } header: { Text("Mon identité sur cet appareil") }
                  footer: { Text(identity == .anyone
                                 ? "Chaque validation demandera qui a fait la tâche. Les rappels couvrent toutes les tâches."
                                 : "Ce choix reste propre à cet appareil. Vos validations et vos rappels utilisent cette identité.") }
            }
            .scrollContentBackground(.hidden).background(DeuxStyle.canvas)
            .navigationTitle("Notre équipe").inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer", action: save).fontWeight(.semibold).disabled(!isValid) }
            }
            .alert("Les changements n’ont pas été enregistrés", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("D’accord", role: .cancel) { error = nil }
            } message: { Text(error ?? "Réessayez dans un instant.") }
        }
        .tint(DeuxStyle.forest).preferredColorScheme(.light)
    }

    private func save() {
        do {
            try store.updateHousehold(name: householdName.trimmingCharacters(in: .whitespacesAndNewlines), personOne: firstName.trimmingCharacters(in: .whitespacesAndNewlines), personTwo: secondName.trimmingCharacters(in: .whitespacesAndNewlines))
            store.currentPerson = identity
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
