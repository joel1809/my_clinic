# My Clinic — application mobile

Application Flutter pour les patients de la clinique. Elle consomme l'API REST v1
du backend Laravel situé dans `C:\wamp64\www\my-clinic` (authentification par
tokens Sanctum).

## Fonctionnalités

- **Identité visuelle synchronisée** (`GET /branding`) : le logo, le logo clair
  et les couleurs saisis dans « Paramètres du site » habillent l'application —
  écran de démarrage, connexion, boutons, accents et couleurs de texte. La
  charte est mise en cache et relue avant le premier écran (démarrage déjà aux
  bonnes couleurs, même hors ligne), puis revalidée à chaque lancement avec
  l'ETag renvoyé par l'API : 304 tant que rien n'a changé, et purge des logos
  en cache dès que la version change.
- **Compte patient** : inscription, connexion, déconnexion, session persistante,
  consultation et modification du profil (identité, téléphone, sexe, date de
  naissance, adresse).
- **Catalogue** : spécialités actives (avec nombre de médecins), liste des
  médecins filtrable par spécialité, fiche détaillée d'un médecin.
- **Prise de rendez-vous** en trois étapes, avec fil d'étapes cliquable pour
  revenir en arrière : choix du jour (cartes datées, journées complètes
  signalées), choix du créneau (regroupés en matin / après-midi / soirée, les
  créneaux occupés sont barrés), puis récapitulatif avec motif + téléphone et
  motifs fréquents proposés en un geste. Gestion du conflit « créneau pris
  entre-temps » (les créneaux sont rechargés automatiquement).
- **Mes rendez-vous** : liste paginée (défilement infini) filtrable
  (« À venir » / « Historique »), détail, annulation quand le rendez-vous le
  permet (`is_cancellable`).
- **Actualités** : articles publiés, paginés et filtrables par catégorie,
  fiche détaillée avec contenu et galerie.
- **Espace médecin** : **confirmation et annulation des rendez-vous** de ses
  patients depuis la liste ou le détail (filtre « À confirmer » avec compteur
  des demandes en attente, appel du patient en un tap) ; gestion de ses plages
  de disponibilité (onglet « Créneaux ») — hebdomadaires ou à dates précises —
  dont découlent les créneaux proposés aux patients ; consultation des dossiers
  médicaux de ses patients entièrement dans l'app (synthèse clinique,
  assurances couvrant le patient, images en plein écran, PDF dans le lecteur
  intégré `pdfx`).

## Démarrage

1. Lancer le backend :

   ```bash
   cd C:\wamp64\www\my-clinic
   php artisan serve   # http://localhost:8000
   ```

2. Lancer l'application :

   ```bash
   flutter pub get
   flutter run
   ```

### Icône de lancement et logos embarqués

Les logos affichés **dans** l'application suivent le site tout seuls, via l'API
`/branding`. En revanche l'**icône de l'application** — celle de la liste des
applications du téléphone — fait partie du paquet installé : elle ne peut pas
changer à chaud. Après un changement de logo dans « Paramètres du site », il
faut donc la régénérer et reconstruire :

```bash
php artisan serve                      # côté backend
dart run tool/update_brand_assets.dart # récupère logos + emblème du site
dart run flutter_launcher_icons        # génère les icônes Android et iOS
flutter build apk                      # ou flutter run
```

`tool/update_brand_assets.dart` reprend le logo, le logo clair et le favicon
de la charte : les deux premiers deviennent les images de repli embarquées
(affichées avant la réponse de l'API), le favicon devient l'icône de
lancement. Si le backend n'est pas sur `localhost:8000` :
`dart run tool/update_brand_assets.dart --url=http://192.168.100.12:8000`.

### URL du backend

L'URL se fournit au lancement, avec
`--dart-define=API_BASE_URL=https://mon-backend`. Sans elle, **en
développement seulement**, l'application retombe sur :

| Plateforme                   | URL utilisée                                    |
| ---------------------------- | ----------------------------------------------- |
| Android (téléphone physique) | le tunnel ngrok déclaré dans `app_config.dart`   |
| Windows / web                | `http://localhost:8000`                          |

Pour un test en Wi-Fi local, le téléphone et le PC doivent être sur le même
réseau, et le backend doit écouter sur toutes les interfaces :

```bash
php artisan serve --host=0.0.0.0 --port=8000
flutter run --dart-define=API_BASE_URL=http://<ip-du-pc>:8000
```

Ajoutez alors l'IP du PC (`ipconfig` pour la connaître) dans
`android/app/src/debug/res/xml/network_security_config.xml` : le HTTP en clair
n'est autorisé qu'en build de débogage, et seulement vers les hôtes qui y sont
listés.

### Build de distribution

`API_BASE_URL` est **obligatoire** en `--release`, et doit être en HTTPS :

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.exemple.test
```

Sans elle, l'application s'arrête au démarrage avec un message explicite
(`AppConfig.checkConfiguration`). C'est volontaire : le repli de développement
est un tunnel ngrok, qui déchiffre le trafic qui le traverse et aboutit à un
poste de développement — dossiers médicaux et jetons de session compris. Un
APK partagé pour test doit donc nommer explicitement son backend, tunnel
compris :

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://delusion-obedient-banister.ngrok-free.dev
```

### Adresses renvoyées par l'API

Toutes les adresses reçues de l'API — documents du dossier médical, photos de
médecins, logos de la charte, illustrations et **lien du bouton d'un pop-up** —
sont ramenées à l'hôte du backend avant d'être ouvertes ou chargées
(`AppConfig.mediaUri`). Celle qui pointe ailleurs est écartée : sans quoi une
réponse forgée choisirait la page à ouvrir dans le navigateur du patient, ou
l'hôte vers lequel l'application émet une requête.

Les liens vers le site de la clinique lui-même passent, puisqu'il sert aussi
l'API. Pour qu'un **appel à l'action de pop-up vers un site externe** s'affiche,
son hôte doit être nommé à la construction :

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.exemple.test \
  --dart-define=ALLOWED_LINK_HOSTS=partenaire.test,sante.gouv.test
```

Des noms d'hôtes nus, séparés par des virgules — ni schéma, ni port, ni chemin,
ni joker ; une entrée mal formée arrête la build de distribution plutôt que de
laisser le lien silencieusement masqué. La comparaison est exacte :
`partenaire.test` n'ouvre pas `promo.partenaire.test`, et l'hôte n'est joint
qu'en HTTPS.

La liste vit **dans l'application**, jamais dans la réponse de l'API : c'est ce
qui la rend utile. Une liste servie par le backend ne protégerait de rien,
puisque la réponse qui désigne l'hôte à ouvrir désignerait aussi les hôtes
autorisés à l'être. Le backend refuse en plus un hôte non listé à
l'enregistrement du pop-up (`config/clinic.php`, clé `allowed_link_hosts`),
pour que l'administration le sache tout de suite — mais c'est un confort, pas
la barrière. **Les deux listes se tiennent à jour ensemble** : un domaine
ajouté au backend seul ne s'affichera pas tant que l'application n'a pas été
reconstruite.

## Architecture

```
lib/
├── core/           # Configuration, client HTTP, exceptions, stockage du token
├── models/         # Modèles calqués sur les Resources de l'API (User, Doctor, ...)
├── repositories/   # Appels à l'API v1 (auth, catalogue, rendez-vous, articles)
├── state/          # Provider : AuthState (session, 401) et BrandingState (charte)
├── screens/        # Écrans par domaine (auth, home, doctors, booking, ...)
└── widgets/        # Composants partagés (erreurs, vues vides, images réseau)
```

## Tests

```bash
flutter test
```
