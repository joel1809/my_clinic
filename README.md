# My Clinic — application mobile

Application Flutter pour les patients de la clinique. Elle consomme l'API REST v1
du backend Laravel situé dans `C:\wamp64\www\my-clinic` (authentification par
tokens Sanctum).

## Fonctionnalités

- **Compte patient** : inscription, connexion, déconnexion, session persistante,
  consultation et modification du profil (identité, téléphone, sexe, date de
  naissance, adresse).
- **Catalogue** : spécialités actives (avec nombre de médecins), liste des
  médecins filtrable par spécialité, fiche détaillée d'un médecin.
- **Prise de rendez-vous** en trois étapes : choix du jour de consultation,
  choix du créneau horaire (les créneaux occupés sont barrés), motif +
  téléphone puis confirmation. Gestion du conflit « créneau pris entre-temps »
  (les créneaux sont rechargés automatiquement).
- **Mes rendez-vous** : liste paginée (défilement infini), détail, annulation
  quand le rendez-vous le permet (`is_cancellable`).
- **Actualités** : articles publiés, paginés et filtrables par catégorie,
  fiche détaillée avec contenu et galerie.
- **Espace médecin** : gestion de ses plages de disponibilité (onglet
  « Créneaux ») — hebdomadaires ou à dates précises — dont découlent les
  créneaux proposés aux patients ; consultation des dossiers médicaux de ses
  patients entièrement dans l'app (images en plein écran, PDF dans le lecteur
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

### URL du backend

Par défaut :

| Plateforme                 | URL utilisée                 |
| -------------------------- | ---------------------------- |
| Android (téléphone physique) | `http://192.168.100.12:8000` |
| Windows / web              | `http://localhost:8000`      |

Le téléphone et le PC doivent être sur le même réseau Wi-Fi, et le backend
doit écouter sur toutes les interfaces :

```bash
php artisan serve --host=0.0.0.0 --port=8000
```

Si l'adresse IP du PC change (`ipconfig` pour la connaître), mettez à jour
`lib/core/app_config.dart` (ou lancez avec
`--dart-define=API_BASE_URL=http://<ip-du-pc>:8000`) **et** ajoutez la
nouvelle IP dans
`android/app/src/main/res/xml/network_security_config.xml` : le HTTP en
clair n'est autorisé que vers les hôtes de développement qui y sont listés.

## Architecture

```
lib/
├── core/           # Configuration, client HTTP, exceptions, stockage du token
├── models/         # Modèles calqués sur les Resources de l'API (User, Doctor, ...)
├── repositories/   # Appels à l'API v1 (auth, catalogue, rendez-vous, articles)
├── state/          # AuthState (Provider) : session, profil, déconnexion sur 401
├── screens/        # Écrans par domaine (auth, home, doctors, booking, ...)
└── widgets/        # Composants partagés (erreurs, vues vides, images réseau)
```

## Tests

```bash
flutter test
```
