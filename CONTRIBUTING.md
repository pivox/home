# Contribuer

Lire `AGENTS.md` et `docs/architecture.md`. Pour une évolution, décrire le comportement attendu et garder les changements dans le module concerné. Ajouter une régression pour un bug du moteur ou du stockage ; une modification purement visuelle peut être vérifiée par compilation et inspection du rendu.

Avant une livraison :

```sh
make validate
make test
make build
make ios-build
```

Rapporter séparément une commande non disponible et un test qui échoue. Les changements de partage exigent aussi la checklist à deux comptes de `docs/apple-setup.md`. Ne pas commiter de profils de provisioning, certificat, clé, compte Apple ou lien de partage privé.

Modifier le projet par `scripts/generate_project.py`, puis lancer `make project`. La validation compare les sorties générées dans un dossier temporaire, sans modifier le projet. Les choix de signature restent dans le fichier ignoré `Config/Signing.local.xcconfig`. Garder les skills dans `.agents/skills` ; `.claude/skills` est un lien vers cette source commune. Ne pas dupliquer les consignes entre `AGENTS.md`, `CLAUDE.md` et `agent.md`.

Les pull requests utilisent le modèle du dépôt pour présenter le problème, le changement et les vérifications. Les fonctionnalités sans lien direct avec la gestion de tâches du couple doivent d’abord avoir un périmètre explicite.
