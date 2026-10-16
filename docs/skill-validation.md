# Validation des instructions et skills

Les scénarios ci-dessous ont été définis avant la rédaction des skills du dépôt. Les réponses indépendantes ne sont pas présentées comme des échecs lorsqu’elles étaient déjà correctes.

## Baseline sans les nouveaux skills — 16 octobre 2026

| Scénario | Observation réelle | Critère de réévaluation |
| --- | --- | --- |
| Modifier les filtres SwiftUI, renommer la deuxième personne, afficher l’effort et conserver macOS | L’agent UI a trouvé `PlanningView`, `ProfileEditorView`, `updateHousehold`, `TaskInsights` et les gardes iOS. Baseline correcte. | Le changement garde les identités stables, les mutations dans le store et les minutes issues des validations. |
| Ajouter une routine partagée, annoncer iCloud après sauvegarde, annuler une ancienne ligne d’historique | L’agent persistance a refusé les deux raccourcis : sauvegarde locale ≠ synchronisation prouvée ; annulation réservée à la dernière occurrence. Il a identifié le magasin du foyer, la relation inverse et l’identité locale. Baseline correcte. | Retrouver ces contraintes dans les fichiers réels ; distinguer tests locaux et essai CloudKit à deux comptes. |
| Vérifier les modules et conclure sur l’app iOS dans un environnement avec seuls les Command Line Tools | Le premier essai réel a utilisé XCTest absent, puis rencontré une interface privée PackageDescription périmée. Après correction temporaire du toolchain, les chemins de Testing, de son plugin et de sa bibliothèque runtime ont dû être corrigés. Les 18 tests du domaine ont ensuite passé. | Utiliser les commandes du dépôt, signaler le niveau effectivement vérifié et ne pas annoncer une compilation iOS ou un essai CloudKit sur la seule base des tests macOS. |

Ces skills sont des références propres au projet demandées par l’utilisateur. Les deux baselines correctes ne démontrent pas un gain de comportement ; le troisième scénario démontre un besoin réel de distinguer environnement, compilation et capacités Apple.

## Contrôles après rédaction

- Les trois fichiers `SKILL.md` passent `quick_validate.py` du skill-creator : frontmatter, noms et absence de placeholders valides. Longueurs : 266 mots pour `developing-swiftui`, 282 pour `cloudkit-sharing`, 291 pour `validating-adeux`.
- L’agent UI a rejoué son scénario avec `developing-swiftui`, retrouvé les bonnes mutations et distingué minutes réalisées et tâches ouvertes. Sa remarque a précisé que les filtres de personne existent aussi dans `TodayView`.
- L’agent persistance a rejoué son scénario avec `cloudkit-sharing`, confirmé les invariants de magasin, identité et dernière occurrence, puis signalé la nécessité de retenir le foyer d’origine pendant une opération asynchrone et d’identifier le partage avec son `CKRecord.ID` complet. Le skill intègre ces deux précisions, présentes dans l’implémentation corrigée.
- Avant rédaction de `validating-adeux`, l’agent principal a répondu au scénario « tests Mac réussis, annoncer iPhone/iCloud entièrement testés sans SDK ni compte » : il a distingué tests Mac, compilation des modules, build iOS et essai à deux comptes. Après lecture du skill, il a conservé cette distinction et demandé les preuves `make test`, `make build`, `make validate`, puis `make ios-build` avec Xcode et les essais à deux comptes. Aucune instruction trompeuse signalée ; résultat correct identique à la baseline.
- Vérification directe : 31 chemins de projet cités existent, les trois skills de livraison existent, l’import `@AGENTS.md` et le lien relatif `.claude/skills → ../.agents/skills` sont corrects. `make -n test build validate ios-build project preview` a retrouvé les six recettes ; ce mode ne les exécute pas.
- `verify-content.sh` du skill agent-rules a retourné zéro problème. `verify-commands.sh` n’a pas pu s’exécuter : Bash 4 minimum requis, Bash 3.2 fourni dans cet environnement. Ce contrôle indisponible ne vaut pas validation des commandes.

Une validation du frontmatter ne constitue pas une évaluation comportementale. Les essais ci-dessus sont des réponses de lecture/application indépendantes, sans modification du code ni accès à des comptes Apple. Ils ne remplacent pas l’essai iOS/CloudKit à deux comptes.
