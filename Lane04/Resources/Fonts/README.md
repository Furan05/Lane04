# Resources/Fonts

Déposer ici les fichiers de police de marque (licence **OFL**), avec leur `OFL.txt`.

Attendu :

- **Archivo** — variable (axes weight + width, pour obtenir *Expanded*). Voix : titres, navigation, boutons.
- **JetBrains Mono** — Regular + Medium. Donnée : toute valeur métrique (chiffres tabulaires).

Une fois déposés :

1. Ils sont **automatiquement inclus** dans le bundle (groupe Xcode synchronisé) et enregistrés au lancement par `FontRegistrar.registerAll()`.
2. Vérifier en DEBUG le log `[LANE04]` qui liste les familles/noms PostScript réellement disponibles.
3. Ajuster si besoin les noms dans `BrandFont` (`Lane04/Theme/Typography.swift`) pour qu'ils correspondent exactement — notamment la sélection de la largeur *Expanded* sur la variable font Archivo.

Tant que les fichiers sont absents, `Font.custom` retombe sur SF Pro / SF Mono : l'app reste fonctionnelle, la typographie de marque n'est simplement pas encore appliquée.
