# Vérifications de la livraison initiale

16 octobre 2026. L’environnement local possède Swift 6.4 et le SDK macOS, sans Xcode complet ni SDK iOS.

| Vérification | Résultat observé |
| --- | --- |
| `make test` | **37 tests réussis**, 3 suites : 18 domaine, 16 persistance, 3 rappels |
| `make build` | Compilation de `DeuxUI` et ses dépendances réussie sur macOS |
| `make validate` dans le dépôt de livraison | **Réussis** : structure, skills, ressources, projet, syntaxe iOS et scripts |
| `./scripts/render-preview.sh` | Build de `DeuxPreview` réussi, 4 captures natives SwiftUI macOS non vides ; inspection visuelle des 4 écrans |
| `DeuxPreview --large-text` | Branche de mise en page accessible inspectée sur macOS ; ne simule pas entièrement le texte iPhone |
| Icône | PNG 1024 × 1024 sans canal alpha, inspecté visuellement |
| Génération Xcode | Projet et schémas déterministes ; validation dans un dossier temporaire sans modification des fichiers d’origine |
| Relecture indépendante | Domaine, stockage, intégration iCloud, notifications, scripts et documentation relus ; cas d’annulation, départ du partage et préservation de la signature corrigés |

## Ce qui nécessite Xcode ou des appareils Apple

`make ios-build` retourne un message explicite lorsque Xcode complet est absent. Le build iPhone est également prévu dans `.github/workflows/ci.yml`. Son statut effectif figure dans les exécutions GitHub Actions ; la présence du fichier ne signifie pas que le build est passé.

La signature, le lancement iPhone, les invitations iCloud à froid/à chaud, la propagation sur deux comptes, le départ d’un partage, les rappels sur appareil, le niveau maximal de Dynamic Type et VoiceOver nécessitent les essais décrits dans `apple-setup.md`.

Les configurations CloudKit sont testées localement ; le service iCloud réel ne l’a pas été dans cet environnement. Les snapshots JSON sont une unité de conflit complète et la validation simultanée d’une routine doit être durcie avant diffusion large, comme indiqué dans `architecture.md`.

## Environnement et instructions d’agents

Les scripts contournent l’interface privée PackageDescription périmée et les chemins Swift Testing des Command Line Tools uniquement dans un cache temporaire. Ils ne réparent ni ne modifient l’installation système. La compilation conserve un avertissement de dépréciation de `--build-system native` sur Swift 6.4 ; cette option n’est ajoutée que pour les Command Line Tools autonomes.

La sandbox interdit `.git` et `.agents` dans le dossier de travail initial. Le dépôt Git et les skills ont donc été assemblés dans un répertoire de livraison temporaire, contenant exactement les sources vérifiées et les trois skills. Le dépôt GitHub contient les chemins canoniques complets. Les tests structurels et scénarios d’application des skills sont détaillés dans `skill-validation.md`.
