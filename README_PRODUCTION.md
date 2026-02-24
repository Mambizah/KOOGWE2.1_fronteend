# KOOGWE Frontend11 — Guide Production

## 🚀 État : Prêt pour la production

---

## ✅ BUGS CORRIGÉS (critiques)

### BUG #1 — Boucle infinie de 401 (token perdu)
**Fichier :** `lib/services/api_service.dart`
- `ApiService.init()` appelé **une seule fois** dans `main.dart` (guard `_initialized`)
- Quand 401 → `AuthService.logout()` + navigation automatique vers `WelcomeScreen`
- Token stocké dans headers Dio globalement (plus d'oubli par requête)

### BUG #2 — Race condition Socket / Navigation
**Fichier :** `lib/screens/auth/otp_screen.dart`
- `await SocketService.connect()` avant `Navigator.push()`
- Catch block : connecte socket UNIQUEMENT si token présent

### BUG #3 — Coordonnées GPS codées en dur (Lomé hardcodé)
**Fichier :** `lib/screens/passenger/confort_screen.dart`
- GPS réel via `LocationService.getCurrentPosition()`
- Recherche destination via OpenStreetMap (Nominatim)
- Calcul distance via OSRM (gratuit, sans API key)

### BUG #4 — Driver Wallet vide si driverId non chargé
**Fichier :** `lib/screens/driver/driver_wallet_screen.dart`
- Méthode `_resolveAndLoad()` : fallback vers SharedPreferences si `driverId` vide

### BUG #5 — OTP catch redirige sans token
**Fichier :** `lib/screens/auth/otp_screen.dart`
- Vérifie `prefs.getString('auth_token') != null` avant de naviguer

---

## 🆕 FONCTIONNALITÉS AJOUTÉES (depuis frontend2)

### 1. Vérification faciale avec caméra live (Camera package)
**Fichier :** `lib/screens/driver/driver_facial_screen.dart`
- **Preview live** de la caméra frontale (package `camera`)
- Cadre ovale animé (pulsation) pour guider le positionnement
- 4 étapes avec instructions et barre de progression
- Flash vert de confirmation à chaque capture
- Upload vers `/face-verification/verify-movements`
- Fallback gracieux si caméra indisponible

### 2. Carte interactive OpenStreetMap (flutter_map)
**Fichier :** `lib/widgets/koogwe_widgets.dart` → `MapPlaceholder`
- Carte OpenStreetMap via Nominatim (gratuit, sans API key)
- Position GPS réelle de l'utilisateur
- Marqueur chauffeur en temps réel (via socket)
- Fonctionne sur Android et iOS

### 3. Suivi GPS chauffeur en temps réel
**Fichier :** `lib/screens/driver/driver_active_ride_screen.dart`
- `Geolocator.getPositionStream()` pour mises à jour continues
- Émission socket `update_location` toutes les 20m de déplacement
- Timer fallback toutes les 8 secondes si pas de mouvement
- Arrêt automatique à la fin de la course

### 4. Notation post-course passager
**Fichier :** `lib/screens/passenger/tracking_screen.dart`
- Dialog de notation (1-5 étoiles) s'affiche automatiquement à la fin
- Appel API `POST /rides/:id/rate`
- Vibration haptic à l'arrivée du chauffeur et fin de course

### 5. Annulation de course
**Fichier :** `lib/screens/passenger/tracking_screen.dart`
- Bouton "Annuler" visible pendant le statut ACCEPTED
- Dialog de confirmation
- Appel API `PATCH /rides/:id/cancel`

### 6. Appel téléphonique chauffeur
**Fichiers :** `tracking_screen.dart`, `driver_active_ride_screen.dart`
- Bouton d'appel direct via `url_launcher`
- Fonctionne sur Android et iOS

### 7. Système multilingue (4 langues)
**Fichier :** `lib/services/i18n_service.dart`
- Français 🇫🇷, English 🇬🇧, Español 🇪🇸, Português 🇧🇷
- Sélection au premier lancement
- Changeable depuis les paramètres

### 8. Upload de documents avec progression
**Fichier :** `lib/screens/driver/driver_document_screen.dart`
- 6 documents (CNI recto/verso, selfie, permis, carte grise, assurance)
- Barre de progression `X/6 documents`
- Choix photo ou galerie
- Upload individuel avec pourcentage

### 9. Inscription véhicule complète
**Fichier :** `lib/screens/driver/vehicle_registration_screen.dart`
- Marque, modèle, couleur, plaque, type de véhicule
- Appel API via `UsersService.updateVehicle()` (URL correcte)
- Validation des champs

### 10. Écran d'attente validation admin
**Fichier :** `lib/screens/driver/pending_screen.dart`
- Animations pulsation et flottement
- Accès pour modifier les documents
- Déconnexion sécurisée

### 11. Profil éditable (passager et chauffeur)
- Modification nom et téléphone
- Toggle notifications
- Stats rapides (courses, note, FCFA)
- Historique des courses

### 12. Reconnexion socket automatique (backoff exponentiel)
**Fichier :** `lib/services/socket_service.dart`
- Reconnexion automatique jusqu'à 10 tentatives
- Délai croissant : 2s → 4s → 8s... → 60s max
- Heartbeat toutes les 25 secondes
- Restauration des listeners après reconnexion

---

## 📦 DÉPENDANCES REQUISES

```yaml
# pubspec.yaml — tous déjà présents
camera: ^0.10.5+9        # Caméra live (vérification faciale)
flutter_map: ^6.1.0      # Carte OSM
geolocator: ^11.0.0      # GPS
url_launcher: ^6.2.6     # Appels téléphoniques
socket_io_client: ^2.0.3+1  # Temps réel
dio: ^5.4.0              # HTTP avec interceptors
image_picker: ^1.1.2     # Documents
```

---

## ⚙️ CONFIGURATION ANDROID REQUISE

### `android/app/src/main/AndroidManifest.xml`
```xml
<!-- Permissions requises -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
```

### `android/app/build.gradle`
```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21  // Requis pour camera
        targetSdkVersion 34
    }
}
```

---

## ⚙️ CONFIGURATION iOS REQUISE

### `ios/Runner/Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>Utilisé pour la vérification faciale du chauffeur</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Requis pour vous localiser et trouver des chauffeurs proches</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Requis pour la navigation en arrière-plan</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Pour sélectionner vos documents depuis la galerie</string>
```

---

## 🌐 URL BACKEND

Backend actif : `https://web-production-13628.up.railway.app`

Configurable dans `lib/services/api_service.dart` :
```dart
static const String _railwayUrl = 'https://web-production-13628.up.railway.app';

// En développement Android (émulateur) → 10.0.2.2:3000 automatique
static String get baseUrl {
  if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return _railwayUrl;
}
```

---

## 🔄 FLUX TEMPS RÉEL (Socket.io)

| Événement émis | Direction | Description |
|---|---|---|
| `driver_online` | Driver → Server | Chauffeur disponible |
| `driver_offline` | Driver → Server | Chauffeur indisponible |
| `accept_ride` | Driver → Server | Accepter une course |
| `driver_arrived` | Driver → Server | Arrivé au point de collecte |
| `start_trip` | Driver → Server | Démarrer la course |
| `finish_trip` | Driver → Server | Terminer la course |
| `update_location` | Driver → Server | Position GPS en temps réel |
| `join_ride` | Passenger → Server | S'abonner aux updates d'une course |
| `heartbeat` | Client → Server | Maintien de connexion (25s) |

| Événement reçu | Direction | Description |
|---|---|---|
| `new_ride` | Server → Driver | Nouvelle demande de course |
| `ride_status_<id>` | Server → Passenger | Changement de statut |
| `driver_location_<id>` | Server → Passenger | Position GPS chauffeur |

---

## 🚦 FLUX D'INSCRIPTION CHAUFFEUR

```
Register → OTP Verification → Vehicle Registration 
  → Facial Verification (caméra live) → Document Upload 
  → Pending Validation → Driver Home
```

---

## 🐛 POINTS DE VIGILANCE

1. **Camera package** : Sur certains émulateurs, la caméra frontale peut ne pas être disponible → fallback gracieux affiché
2. **GPS en production** : `LocationAccuracy.high` peut vider la batterie → envisager `LocationAccuracy.balanced` hors course active
3. **Nominatim rate limit** : 1 requête/seconde. Le debounce de 500ms dans `ConfortScreen` gère ça correctement.
4. **Token expiration** : Le token JWT doit être renouvelé côté backend. L'interceptor 401 redirige vers login si expiré.
5. **Socket reconnexion** : Si l'app est en arrière-plan >60s, le socket se reconnecte automatiquement à la prochaine requête.
