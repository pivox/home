# Architecture

À deux est une application native SwiftUI pour iPhone, en français, avec trois onglets : Aujourd’hui, Planning et Maison. Le paquet Swift contient des modules partagés compilables sur macOS ; `App/` contient l’intégration iOS.

| Module | Dépend de | Rôle |
| --- | --- | --- |
| DeuxCore | Foundation | Tâches, historique, règles, calendrier, bilan |
| DeuxPersistence | DeuxCore, Core Data, CloudKit, Combine | Graphe du foyer, sauvegarde, snapshots observables, partage |
| DeuxUI | DeuxCore, DeuxPersistence, SwiftUI | Écrans, édition, filtres, onboarding |
| DeuxNotifications | DeuxCore, UserNotifications | Plan de rappels pur et synchronisation des demandes locales |
| App | Ces quatre modules, UIKit | Cycle de vie, invitations, feuille de partage, permissions |

## Parcours des données

Une action de la vue appelle `HouseholdStore`. Le store valide la demande, modifie les objets du contexte principal, enregistre puis republie des snapshots `HouseTask` et `TaskCompletion`. Les vues ne modifient jamais directement les tableaux publiés. En cas d’échec de mutation, le contexte est annulé et une erreur visible est conservée.

Le modèle Core Data est construit dans `ManagedModel.swift`. Un `HouseholdRecord` possède des `TaskRecord` et `CompletionRecord` avec relations inverses. Les snapshots des enfants sont stockés en données JSON. Les nouveaux objets sont affectés au magasin de leur foyer avant sauvegarde. Aucun exemple n’est ajouté automatiquement.

Le nom du foyer et les deux prénoms sont partagés ; `currentPerson` et le foyer sélectionné sont propres à l’appareil. `personOne` et `personTwo` sont des rôles stables : modifier un prénom ne doit jamais inverser les attributions. `anyone` permet de laisser une tâche à prendre.

## Validation et récurrence

Une tâche unique conserve sa date de réalisation. Une routine conserve son identifiant, crée une occurrence dans l’historique et avance son échéance au-delà du jour de validation. Le calcul utilise `Calendar`, et préserve l’heure locale lors du changement d’heure. Les mois courts sont bornés au dernier jour disponible. Après une validation mensuelle séparée, ce jour borné devient la nouvelle référence (31 janvier → 28 février → 28 mars).

L’annulation restaure l’échéance précédente et supprime la validation, uniquement pour la dernière occurrence disponible. La suppression d’une tâche conserve son historique. Le bilan se calcule depuis les occurrences réalisées et déduplique leurs identifiants.

## iCloud

Le schéma local ouvre `private.sqlite` sans CloudKit. À identifiant d’application identique, sans désinstallation, le schéma iCloud ouvre le même magasin privé, plus `shared.sqlite` avec la portée `.shared`. Les imports et exports passent par `NSPersistentCloudKitContainer`. Le foyer est la racine d’un `CKShare` privé, en lecture et écriture. Voir [la configuration Apple](apple-setup.md).

Le store observe les changements distants et les événements du conteneur ; une dernière opération réussie ne prouve pas que l’autre iPhone est à jour. Les sauvegardes Core Data restent locales hors connexion. La cohérence est éventuelle, pas instantanée. Le contenu JSON d’une tâche constitue l’unité de conflit : deux modifications concurrentes de la même tâche ne fusionnent pas champ par champ. Une validation simultanée de la même routine depuis deux appareils peut créer deux entrées d’historique ; ce cas nécessite un protocole de déduplication d’occurrence avant diffusion large.

## Rappels

La permission est demandée après une action explicite. Seules les tâches non réalisées, futures, avec rappel activé, attribuées à la personne de cet iPhone ou à prendre, sont programmées. Le plan conserve les 60 échéances les plus proches. La file d’application est sérialisée pour éviter qu’une ancienne mise à jour réintroduise un rappel supprimé.

Les demandes sont recalculées après changement des tâches, d’identité et retour au premier plan. Chaque routine programme son échéance actuelle ; sa prochaine occurrence sera programmée après sa validation et la prochaine actualisation de l’app. L’app ne promet aucun service de notification permanent en arrière-plan.

## Vérification

`make test` couvre les règles, la persistance et le plan de rappels. `make build` compile les vues partagées sur macOS. `make ios-build` compile l’application pour le simulateur et requiert Xcode complet. Le partage doit également être testé sur deux comptes iCloud distincts. Les fichiers `docs/superpowers/` conservent les décisions et le plan initial ; le code, ce document et les tests décrivent le fonctionnement livré.
