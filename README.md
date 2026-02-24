# 🚗 KOOGWE — Guide de connexion Frontend ↔ Backend

## Architecture

```
koogwe_final/          ← Application Flutter (mobile)
backend_final/         ← API NestJS (serveur)
```

---

## 🔧 Configuration en 3 étapes

### Étape 1 — Déployer le backend sur Railway

1. Créez un projet sur [railway.app](https://railway.app)
2. Ajoutez une base de données **PostgreSQL**
3. Déployez le dossier `backend_final/`
4. Ajoutez ces variables d'environnement dans Railway :

```env
DATABASE_URL=postgresql://...       # Auto-généré par Railway
JWT_SECRET=un_secret_tres_long_et_aleatoire_minimum_32_chars
JWT_EXPIRES_IN=7d

# Email (Gmail)
GMAIL_USER=votre@gmail.com
GMAIL_PASS=votre_app_password_gmail

# AWS (pour vérification faciale)
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=koogwe-faces

# Stripe (pour les paiements)
STRIPE_SECRET_KEY=sk_test_...
```

5. Notez votre URL Railway : `https://votre-app.railway.app`

---

### Étape 2 — Configurer le Flutter

Dans `lib/services/api_service.dart`, remplacez :

```dart
static const String baseUrl = 'https://VOTRE-APP.railway.app';
```

Par votre vraie URL Railway.

---

### Étape 3 — Lancer l'app Flutter

```bash
cd koogwe_final
flutter pub get
flutter run
```

---

## 📁 Structure du projet Flutter

```
lib/
├── main.dart                          # Point d'entrée + auto-login
├── models/
│   └── models.dart                    # UserModel, RideModel, TransactionModel...
├── services/
│   ├── api_service.dart               # Tous les appels HTTP (Auth, Rides, Wallet...)
│   └── socket_service.dart            # Connexion Socket.io temps réel
├── theme/
│   └── app_theme.dart                 # Couleurs et thème
├── widgets/
│   └── koogwe_widgets.dart            # Composants réutilisables
└── screens/
    ├── splash_screen.dart             # Auto-login selon le rôle
    ├── welcome_screen.dart            # Écran d'accueil
    ├── auth/
    │   ├── login_screen.dart          # ✅ Connecté à /auth/login
    │   ├── register_screen.dart       # ✅ Connecté à /auth/signup
    │   └── otp_screen.dart            # ✅ Connecté à /auth/verify
    ├── passenger/
    │   ├── home_screen.dart           # ✅ Affiche le nom réel de l'utilisateur
    │   ├── confort_screen.dart        # ✅ Connecté à POST /rides
    │   ├── tracking_screen.dart       # ✅ Socket.io temps réel
    │   ├── wallet_screen.dart         # ✅ Connecté à GET /wallet/balance & /transactions
    │   └── historique_screen.dart     # ✅ Connecté à GET /rides/history
    └── driver/
        ├── driver_home_screen.dart    # ✅ Socket.io + GET /rides/driver/stats
        ├── driver_wallet_screen.dart  # ✅ Connecté à wallet + stats
        ├── driver_historique_screen.dart # ✅ Connecté à GET /rides/history
        ├── driver_document_screen.dart
        ├── driver_facial_screen.dart
        └── pending_screen.dart
```

---

## 📁 Structure du backend

```
src/
├── main.ts                    # Démarrage + CORS + ValidationPipe
├── app.module.ts              # Module principal
├── prisma.service.ts          # Connexion PostgreSQL
├── mail.service.ts            # Envoi d'emails
├── auth/
│   ├── auth.controller.ts     # POST /auth/signup, /login, /verify
│   ├── auth.service.ts        # Logique auth + JWT
│   ├── auth.guard.ts          # Middleware JWT ✅ Sécurisé
│   └── email-verification.service.ts  # Code OTP
├── users/
│   ├── users.controller.ts    # GET /users/me, PATCH /users/update-vehicle
│   └── users.service.ts       # Profil, statut chauffeur
├── rides/
│   ├── rides.controller.ts    # POST /rides, GET /rides/history, /driver/stats
│   ├── rides.service.ts       # Logique des courses
│   └── rides.gateway.ts       # ✅ WebSocket sécurisé avec JWT
├── wallet/
│   ├── wallet.controller.ts   # GET /wallet/balance, POST /recharge-card, /pay-ride
│   └── wallet.service.ts      # Paiements Stripe + Transactions
└── face-verification/
    ├── face-verification.controller.ts
    ├── face-verification.service.ts
    └── aws-rekognition.service.ts     # AWS Rekognition
```

---

## 🔄 Flux complet d'une course

```
PASSAGER                    SERVEUR                    CHAUFFEUR
   │                           │                           │
   ├──── POST /rides ─────────►│                           │
   │                           ├──── emit 'new_ride' ─────►│
   │                           │                           │
   ├──── join_ride(rideId) ───►│◄──── accept_ride ─────────┤
   │                           │                           │
   │◄── ride_status ACCEPTED ──┤                           │
   │                           │                           │
   │◄── ride_status ARRIVED ───┤◄──── driver_arrived ──────┤
   │                           │                           │
   │◄── ride_status IN_PROGRESS┤◄──── start_trip ──────────┤
   │                           │                           │
   │◄── driver_location ───────┤◄──── update_location ─────┤
   │                           │                           │
   │◄── ride_status COMPLETED ─┤◄──── finish_trip ──────────┤
   │◄── trip_finished ─────────┤                           │
```

---

## ✅ Corrections apportées

### Frontend
- ✅ Authentification réelle (login/register/OTP) connectée au backend
- ✅ Auto-login au démarrage selon le rôle (PASSENGER/DRIVER)
- ✅ Socket.io connecté (temps réel tracking, nouvelles courses)
- ✅ Wallet passager et chauffeur avec vraies données
- ✅ Historique des courses en temps réel
- ✅ Chauffeur : bouton "En ligne" connecté au socket
- ✅ Chauffeur : accepter/refuser une course via socket
- ✅ Tracking passager mis à jour via socket events
- ✅ Déconnexion propre (token + socket)
- ✅ Gestion des erreurs avec messages utilisateur

### Backend  
- ✅ **SÉCURITÉ CRITIQUE** : `accept_ride` vérifie maintenant le JWT du socket — un chauffeur ne peut pas accepter comme un autre
- ✅ `rides.gateway.ts` : Authentification JWT à la connexion socket
- ✅ `finish_trip` met à jour `totalRides` et `totalEarnings` dans `driverProfile`
- ✅ Timestamps `acceptedAt`, `arrivedAt`, `startedAt`, `completedAt` correctement renseignés
- ✅ `ConfigService` injecté dans le gateway
- ✅ `app.module.ts` commenté avec les variables d'environnement requises

---

## ⚠️ À faire avant la production

1. `isVerified: true` → mettre `false` dans `auth.service.ts` et activer l'envoi d'email OTP
2. CORS → restreindre `origin: '*'` à votre domaine de prod
3. Geolocator → remplacer les coordonnées hardcodées dans `confort_screen.dart` par les vraies coords GPS
4. Google Maps ou flutter_map → configurer une vraie carte
5. Stripe → tester en mode live avec de vrais moyens de paiement
