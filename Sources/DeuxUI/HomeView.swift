import SwiftUI
import DeuxCore
import DeuxPersistence

private enum HomeSheet: String, Identifiable {
    case profile, history
    var id: Self { self }
}

struct HomeView: View {
    @ObservedObject var store: HouseholdStore
    let onShare: () -> Void
    let onRequestNotifications: () -> Void
    @ViewState private var sheet: HomeSheet?
    @ViewState private var confirmStarters = false
    @ViewState private var error: String?
    @ViewState private var starterNotice = false

    private var weekCompletions: [TaskCompletion] { TaskInsights.weekCompletions(store.completions) }
    private var totalMinutes: Int { TaskInsights.effortMinutes(weekCompletions) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Notre chez-nous")
                    Text(store.householdName).font(DeuxStyle.title(36)).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Votre petit monde, à votre rythme.").font(.subheadline).foregroundStyle(DeuxStyle.secondary)
                }
                StoreErrorBanner(store: store)
                teamCard
                peopleCard
                sharingCard
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Pour se simplifier la vie")
                    PaperCard {
                        VStack(spacing: 0) {
                            actionRow(symbol: "clock.arrow.circlepath", title: "Les gestes déjà faits", subtitle: "Votre historique, avec la possibilité d’annuler") { sheet = .history }
                            Divider().padding(.vertical, 14)
                            actionRow(symbol: "leaf", title: "Des routines pour commencer", subtitle: "Quelques habitudes à adopter, si vous le souhaitez") { confirmStarters = true }
                            Divider().padding(.vertical, 14)
                            actionRow(symbol: "bell", title: "Les rappels, à votre choix", subtitle: "Gérer l’autorisation sur cet appareil", action: onRequestNotifications)
                        }
                    }
                }
                if starterNotice {
                    Label("Les routines de départ sont prêtes dans Planning.", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(DeuxStyle.forest)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(DeuxStyle.sage, in: RoundedRectangle(cornerRadius: 16))
                }
                if store.availableHouseholds.count > 1 { householdSelector }
                VStack(spacing: 6) {
                    Text("À deux").font(DeuxStyle.title(24)).foregroundStyle(DeuxStyle.forest)
                    Text("Moins de charge. Plus de nous.").font(.caption).foregroundStyle(DeuxStyle.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 28)
            .frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(DeuxStyle.canvas)
        .screenChrome()
        .refreshable { await store.load() }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .profile: ProfileEditorView(store: store).comfortableSheet()
            case .history: HistoryView(store: store).comfortableSheet()
            }
        }
        .confirmationDialog("Un petit coup de pouce pour commencer ?", isPresented: $confirmStarters, titleVisibility: .visible) {
            Button("Ajouter les routines de départ") {
                do { try store.addStarterTasks(); starterNotice = true }
                catch { self.error = error.localizedDescription }
            }
            Button("Plus tard", role: .cancel) {}
        } message: { Text("Des tâches récurrentes seront ajoutées à votre foyer. Vous pourrez modifier leur personne, leur durée et leur échéance, ou les supprimer.") }
        .alert("L’action n’a pas abouti", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("D’accord", role: .cancel) { error = nil }
        } message: { Text(error ?? "Réessayez dans un instant.") }
    }

    private var teamCard: some View {
        PaperCard(color: DeuxStyle.sage) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Eyebrow(text: "Cette semaine, ensemble", color: DeuxStyle.forest)
                    Spacer(minLength: 0)
                    Image(systemName: "hands.sparkles").font(.title3).foregroundStyle(DeuxStyle.forest)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(DeuxStyle.duration(totalMinutes)).font(DeuxStyle.title(44)).foregroundStyle(DeuxStyle.forest)
                    Text("pour notre maison").font(.subheadline).foregroundStyle(DeuxStyle.forest)
                }
                Text(weekCompletions.isEmpty ? "Chaque geste compte. Les vôtres trouveront leur place ici." : "\(weekCompletions.count) \(weekCompletions.count == 1 ? "geste réalisé" : "gestes réalisés"). Du temps donné, et une maison qui respire.")
                    .font(.subheadline).foregroundStyle(DeuxStyle.forest).lineSpacing(3)
                Divider().overlay(DeuxStyle.forest.opacity(0.10))
                contribution(.personOne)
                contribution(.personTwo)
                let unassigned = TaskInsights.effortMinutes(weekCompletions, by: .anyone)
                if unassigned > 0 {
                    HStack {
                        Label("Sans attribution", systemImage: "person.2").font(.subheadline)
                        Spacer()
                        Text(DeuxStyle.duration(unassigned)).font(.subheadline.weight(.medium))
                    }.foregroundStyle(DeuxStyle.forest)
                }
                Text("Le temps est estimé à partir des tâches. On partage l’effort, sans classement.")
                    .font(.caption).foregroundStyle(DeuxStyle.forest.opacity(0.85))
            }
        }
    }

    private func contribution(_ person: Assignee) -> some View {
        HStack(spacing: 10) {
            PersonAvatar(name: store.name(for: person), second: person == .personTwo, size: 30)
            Text(store.name(for: person)).font(.subheadline.weight(.medium))
            Spacer(minLength: 6)
            Text(DeuxStyle.duration(TaskInsights.effortMinutes(weekCompletions, by: person))).font(.subheadline)
        }.foregroundStyle(DeuxStyle.forest).accessibilityElement(children: .combine)
    }

    private var peopleCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Eyebrow(text: "Notre équipe")
                        Text("\(store.personOneName) & \(store.personTwoName)")
                            .font(DeuxStyle.title(26)).foregroundStyle(DeuxStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: -9) {
                        PersonAvatar(name: store.personOneName)
                        PersonAvatar(name: store.personTwoName, second: true)
                            .overlay(Circle().strokeBorder(DeuxStyle.paper, lineWidth: 3))
                    }
                }
                Label("Sur cet appareil : \(store.name(for: store.currentPerson))", systemImage: "person.crop.circle")
                    .font(.subheadline).foregroundStyle(DeuxStyle.secondary)
                Button { sheet = .profile } label: {
                    HStack {
                        Text("Prénoms et identité").font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                    }.padding(.top, 2)
                }.buttonStyle(.plain)
            }
        }
    }

    private var sharingCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    Image(systemName: store.cloudEnabled ? "icloud" : "internaldrive")
                        .font(.title2).foregroundStyle(DeuxStyle.forest)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.cloudEnabled ? "Votre foyer avec iCloud" : "Votre foyer sur cet appareil")
                            .font(.subheadline.weight(.semibold))
                        Text(store.cloudStatus).font(.caption).foregroundStyle(DeuxStyle.secondary)
                    }
                }
                Text(store.cloudEnabled
                     ? "Invitez votre partenaire avec un lien iCloud. Chaque personne choisit son identité sur son propre appareil. Les modifications restent possibles hors connexion."
                     : "Vos tâches sont enregistrées sur cet iPhone. Le partage n’est pas activé dans cette version.")
                    .font(.subheadline).foregroundStyle(DeuxStyle.secondary).lineSpacing(3)
                if store.cloudEnabled {
                    Button(action: onShare) { Label("Inviter ou gérer le partage", systemImage: "person.badge.plus") }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Label("iCloud n’est pas activé", systemImage: "info.circle")
                        .font(.caption.weight(.medium)).foregroundStyle(DeuxStyle.secondary)
                }
            }
        }
    }

    private var householdSelector: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Vos foyers")
                Text("Ouvrir un autre foyer").font(DeuxStyle.title(23))
                ForEach(store.availableHouseholds) { household in
                    Button {
                        do { try store.selectHousehold(id: household.id) }
                        catch { self.error = error.localizedDescription }
                    } label: {
                        HStack {
                            Label(household.name, systemImage: household.isShared ? "person.2" : "house")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(.vertical, 8)
                    }
                }
                Text("Vérifiez ensuite votre identité dans « Prénoms et identité ».")
                    .font(.caption).foregroundStyle(DeuxStyle.secondary)
            }
        }
    }

    private func actionRow(symbol: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(DeuxStyle.forest)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(DeuxStyle.ink)
                    Text(subtitle).font(.caption).foregroundStyle(DeuxStyle.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(DeuxStyle.secondary)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityElement(children: .combine)
    }
}
