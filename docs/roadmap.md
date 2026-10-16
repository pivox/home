# Suite du projet

## Avant usage quotidien à deux

1. Installer Xcode, attribuer l’identifiant d’application et le conteneur CloudKit à votre équipe.
2. Lancer le build iPhone et corriger tout problème spécifique au SDK iOS relevé par la CI.
3. Parcourir l’invitation froide/chaude, les modifications dans les deux sens et le mode hors connexion sur vos deux comptes.
4. Tester les rappels autorisés/refusés, l’heure locale et le retrait après validation.
5. Inspecter les écrans sur petit iPhone et en grande taille de texte avec VoiceOver.

## Fiabilité du partage

- Dédupliquer une occurrence validée simultanément sur deux appareils, puis ajouter une régression d’import de doublons.
- Vérifier la fin du partage côté propriétaire et le départ de l’invité, sans suppression des données du propriétaire.
- Décider si la fusion champ par champ des modifications d’une même tâche est nécessaire ; les snapshots JSON actuels constituent une seule unité de conflit.
- Définir les migrations du modèle avant toute évolution incompatible et les tester sur un magasin SQLite conservé.

## Évolutions produit possibles

Choisir selon votre usage réel : liste de courses dédiée, modèles de routines par pièce, alternance automatique d’attribution, widget « Aujourd’hui », raccourcis Siri. Ces éléments ne sont pas inclus dans cette première version et ne nécessitent pas d’ajouter de compte ou de serveur par défaut.
