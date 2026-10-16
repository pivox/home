# Installer et tester sur vos deux iPhone

## Première ouverture locale

1. Installer Xcode 16 ou plus récent, puis ouvrir `ADeux.xcodeproj`.
2. Choisir le schéma **ADeux**, un simulateur iPhone avec iOS 17 ou plus récent, puis lancer avec ⌘R.
3. Sur un iPhone physique : copier `Config/Signing.local.xcconfig.example` vers `Config/Signing.local.xcconfig`, puis renseigner votre `DEVELOPMENT_TEAM` et un `PRODUCT_BUNDLE_IDENTIFIER` disponible. Ce fichier personnel est ignoré par Git et préservé par la régénération du projet.
4. Créer le foyer et saisir vos deux prénoms. Choisir le prénom qui représente la personne utilisant cet appareil.

Le schéma ADeux fonctionne en local, sans conteneur iCloud ni service tiers. Un compte de développement personnel peut servir au lancement local selon les possibilités de signature de votre équipe.

## Activer le partage entre deux comptes Apple

Le partage utilise le service iCloud d’Apple : il requiert une équipe Apple Developer avec les capacités CloudKit, un identifiant d’application et un conteneur appartenant à cette équipe. Aucun serveur n’est à héberger. Les noms et tâches sont stockés sur les appareils et dans le conteneur iCloud configuré ; aucune analyse d’usage n’est intégrée.

1. Créer `Config/Signing.local.xcconfig` à partir de l’exemple, puis renseigner votre équipe et votre `PRODUCT_BUNDLE_IDENTIFIER`.
2. Dans ce même fichier, remplacer `ADEUX_CLOUD_CONTAINER` par le conteneur de votre équipe, par exemple `iCloud.fr.votreequipe.adeux`. `Config/Project.xcconfig` charge ces valeurs pour toutes les configurations. Ne pas coder un autre identifiant dans les sources et ne pas commiter le fichier personnel. Les changements effectués directement dans le projet généré peuvent être remplacés par `make project` ; utiliser ce fichier de configuration pour les conserver.
3. Pour les configurations **Debug-iCloud** et **Release-iCloud**, vérifier `CODE_SIGN_ENTITLEMENTS = App/ADeux.entitlements`. Les capacités nécessaires sont iCloud / CloudKit, Push Notifications et Background Modes / Remote notifications. `App/Info.plist` contient `CKSharingSupported` et les entrées de réception d’invitation.
4. Sélectionner le schéma **ADeux-iCloud**, connecté au conteneur de l’équipe. Les configurations Debug et Release normales utilisent `App/Local.entitlements` et restent locales.
5. Conserver **le même identifiant d’application pour les schémas local et iCloud**, et mettre à jour l’app existante sans la désinstaller pour conserver son conteneur de données. Installer cette même application sur les deux iPhone, chacun connecté à son propre compte iCloud. Le premier conserve le rôle Personne 1 ; l’autre choisit Personne 2 dans Maison.
6. Sur le premier téléphone, créer le foyer, ajouter une tâche et attendre une opération iCloud réussie. Dans **Maison**, utiliser **Inviter** et envoyer le lien avec la feuille de partage native. Cette action est réalisée par vous dans l’app.
7. Sur le second, ouvrir ce lien, accepter et attendre l’import. Si un foyer local existe déjà, sélectionner le foyer partagé dans Maison. Choisir son prénom sur ce téléphone. Les foyers locaux existants ne sont pas fusionnés automatiquement.
8. Tester la création, l’attribution et la validation dans les deux sens. Vérifier aussi les noms et l’historique. Les erreurs iCloud restent visibles dans l’app ; une invitation acceptée n’est pas une preuve d’import terminé.

Pour une distribution TestFlight, déployer le schéma du conteneur vers **Production** dans CloudKit Console après les essais en développement. Utiliser la configuration **Release-iCloud** et la signature de distribution de l’équipe. Le projet ne contient aucun certificat, profil, secret ou compte Apple.

Revenir au schéma local masque temporairement les foyers reçus par partage : il n’ouvre pas `shared.sqlite`. Le fichier est conservé et les foyers partagés réapparaissent avec le schéma iCloud. Ce changement de schéma n’est pas une suppression.

## Checklist sur appareils réels

- [ ] Invitation reçue lorsque l’app est fermée, puis lorsque l’app est déjà ouverte.
- [ ] Les nouvelles tâches appartiennent au foyer partagé, y compris celles créées par la personne invitée.
- [ ] Les modifications et validations se propagent dans les deux sens.
- [ ] Hors connexion, une modification reste présente après redémarrage ; elle se propage après reconnexion.
- [ ] Une annulation récente se propage et une annulation d’une ancienne occurrence est refusée.
- [ ] Changer le prénom de l’utilisateur sur un iPhone ne change pas l’identité locale de l’autre.
- [ ] Une permission de notifications refusée n’empêche pas d’enregistrer la tâche.
- [ ] Un rappel est retiré après validation, suppression ou changement d’attribution.
- [ ] Arrêt du partage par le propriétaire : ses données restent disponibles ; l’invité perd l’accès.
- [ ] Départ de l’invité : les données du propriétaire restent disponibles et le foyer quitté disparaît après actualisation/import.
- [ ] Modifier le même objet et valider la même routine simultanément depuis les deux téléphones ; contrôler le comportement de conflit décrit dans `architecture.md`.

Les essais de fin/abandon du partage et de validation simultanée sont des points de validation avant diffusion à d’autres foyers. La compilation seule ne suffit pas à les garantir.

## Références Apple

- [Exemple de partage CloudKit](https://github.com/apple/sample-cloudkit-sharing)
- [Partager les objets Core Data entre comptes iCloud](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users)
- [Recevoir les invitations dans SwiftUI](https://developer.apple.com/documentation/coredata/accepting-share-invitations-in-a-swiftui-app)
- [Notifications locales](https://developer.apple.com/documentation/usernotifications)
