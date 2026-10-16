import SwiftUI
import DeuxCore
import DeuxPersistence

struct OnboardingView: View {
    @ObservedObject var store: HouseholdStore
    @ViewState private var householdName = "Notre chez-nous"
    @ViewState private var firstName = ""
    @ViewState private var secondName = ""
    @ViewState private var identity: Assignee = .personOne
    @ViewState private var error: String?
    @ViewState private var creating = false

    private var isValid: Bool {
        [householdName, firstName, secondName].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("À DEUX", systemImage: "house.fill").font(.caption.weight(.bold)).tracking(3)
                    Spacer()
                    Text("ON FAIT ÉQUIPE").font(.caption2.weight(.medium)).tracking(1.5)
                }.foregroundStyle(DeuxStyle.forest)
                VStack(alignment: .leading, spacing: 12) {
                    HouseIllustration().frame(maxWidth: .infinity).padding(.top, 8)
                    Text("Une maison.\nDeux équipiers.")
                        .font(DeuxStyle.title(43)).foregroundStyle(DeuxStyle.forest)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Les petites choses du quotidien, partagées simplement. Et plus de place pour vous.")
                        .font(.body).foregroundStyle(DeuxStyle.secondary).lineSpacing(4)
                }
                StoreErrorBanner(store: store)
                PaperCard {
                    VStack(alignment: .leading, spacing: 19) {
                        Eyebrow(text: "Bienvenue chez vous")
                        field("Le nom de votre foyer", placeholder: "Notre chez-nous", text: $householdName)
                        Divider()
                        field("Votre premier prénom", placeholder: "Premier prénom", text: $firstName)
                        field("Et votre partenaire", placeholder: "Deuxième prénom", text: $secondName)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sur cet appareil, je suis…").font(.subheadline.weight(.semibold))
                    HStack(spacing: 10) {
                        identityButton(.personOne, name: firstName.isEmpty ? "Première personne" : firstName)
                        identityButton(.personTwo, name: secondName.isEmpty ? "Deuxième personne" : secondName)
                    }
                    Text("Ce choix attribue vos gestes à la bonne personne. Vous pourrez le changer dans Maison.")
                        .font(.caption).foregroundStyle(DeuxStyle.secondary)
                }
                Button {
                    creating = true
                    do {
                        try store.createHousehold(name: householdName.trimmingCharacters(in: .whitespacesAndNewlines), personOne: firstName.trimmingCharacters(in: .whitespacesAndNewlines), personTwo: secondName.trimmingCharacters(in: .whitespacesAndNewlines))
                        store.currentPerson = identity
                    } catch { self.error = error.localizedDescription }
                    creating = false
                } label: {
                    HStack {
                        Text("Ouvrir notre maison")
                        if creating { ProgressView().tint(.white) }
                        else { Image(systemName: "arrow.right") }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid || creating)
                .opacity(isValid ? 1 : 0.5)
                Text(store.cloudEnabled
                     ? "Votre foyer commence vide. Ajoutez vos tâches à votre rythme, puis invitez votre partenaire depuis Maison."
                     : "Votre foyer commence vide. Ajoutez vos tâches à votre rythme et retrouvez vos routines dans Maison.")
                    .font(.caption).foregroundStyle(DeuxStyle.secondary).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 26).padding(.vertical, 28)
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
        }
        .background(DeuxStyle.canvas)
        .alert("La maison n’a pas pu être créée", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("D’accord", role: .cancel) { error = nil }
        } message: { Text(error ?? "Réessayez dans un instant.") }
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(DeuxStyle.secondary)
            TextField(placeholder, text: text)
                .font(.body).textContentType(.name)
                .padding(12)
                .background(DeuxStyle.canvas, in: RoundedRectangle(cornerRadius: 11))
                .accessibilityLabel(title)
        }
    }

    private func identityButton(_ value: Assignee, name: String) -> some View {
        let selected = identity == value
        return Button { identity = value } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                Text(name).font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .padding(12)
            .foregroundStyle(DeuxStyle.forest)
            .background(selected ? DeuxStyle.sage : DeuxStyle.paper, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(selected ? DeuxStyle.forest : DeuxStyle.line, lineWidth: 1))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
