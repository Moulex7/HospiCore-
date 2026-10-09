# 07 — Direction UI/UX : Android Moderne (Material You / Material 3)

> Application HospiCore pour **Android moderne** : **cible Android 17 (API 37)**, `minSdk 29` (Android 10), `targetSdk`/`compileSdk` 37. Framework : **Kotlin 2.x + Jetpack Compose + Material 3 (Material You)**.
> Deux rôles : **app soignants** (tablettes de soins, CHSLD) et **app patient** (portail mobile).

---

## 7.1 Principes directeurs (Material You / Material 3)

| Principe | Application concrète dans HospiCore |
|---|---|
| **Personnel** | **Couleurs dynamiques** (Monet) extraites du fond d'écran sur Android 12+ (API 31+) ; sinon palette HospiCore (fallback). Thème clair/sombre/système. |
| **Adaptatif** | Layouts adaptatifs : téléphones, **tablettes de soins** (CHSLD), pliables. `WindowSizeClass` (compact/medium/expanded) → navigation rail / drawer. |
| **Expressif** | Typographie Material 3 expressive (titres plus affirmés), états riches (hover/focus/pressed/disabled), formes « expressives » (coins arrondis généreux : 12–28 px selon composant). |
| **Accessibilité** | TalkBack, Switch Access, contraste AA, cibles tactiles ≥ 48×48 dp. |
| **Conçu pour la santé** | Lisibilité maximale : pas de « dark pattern », pas de friction sur les actions de sécurité (alertes, consentements). Rouge sémantique réservé aux alertes critiques. |

## 7.2 Architecture UI (Compose)

```text
app/ (Kotlin, Jetpack Compose, Material 3)
├── ui/theme/          # HospiCoreTheme : couleurs dynamiques + fallback, typographie, formes
├── ui/components/     # Design system HospiCore (boutons, cartes, badges, champs)
├── ui/navigation/     # Navigation 3 (bottom bar / rail / drawer adaptatifs)
├── feature/patient/   # Dossier patient, timeline, résultats
├── feature/mar/       # Administration des médicaments (soins)
├── feature/vitals/    # Saisie des signes vitaux
├── feature/appointment/ # Agenda & RDV
├── feature/telehealth/  # Télésanté (WebRTC)
├── feature/portal/    # Portail patient (RDV, résultats, messagerie, consentements)
├── core/fhir/         # Client FHIR + modèles (KMP shared avec backend JVM)
├── core/sync/         # Moteur offline-first (Room chiffré + WorkManager)
└── core/security/     # Keystore, BiometricPrompt, certificate pinning
```

## 7.3 Navigation (adaptative)

| Taille d'écran | Pattern | Implémentation |
|---|---|---|
| Compact (téléphone) | **Bottom navigation bar** (5 destinations max) + top app bar | `NavigationBar` Material 3 |
| Medium/Expanded (tablette, pliable) | **Navigation rail** (vertical) | `NavigationRail` |
| Très large (pliable ouvert) | **Navigation drawer** (permanent ou modal) | `ModalNavigationDrawer` / permanent |

Destinations (app soignants) : **Patients**, **Agenda**, **Soins (MAR)**, **Télésanté**, **Profil**.
Destinations (app patient) : **Accueil**, **RDV**, **Résultats**, **Messages**, **Profil**.

## 7.4 Design system HospiCore (Compose)

| Composant | Spécification Material 3 | Usage |
|---|---|---|
| **Bouton principal** | `Button` (filled, hauteur 40 dp, radius « full » 20 dp ou forme expressive) | Une action primaire par écran (ex: « Confirmer l'administration ») |
| **Bouton secondaire** | `OutlinedButton` | Actions secondaires |
| **Bouton tertiaire** | `TextButton` | Actions tertiaires, « Annuler » |
| **Bouton dangereux** | `Button` avec `colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)` | Suppression, annulation d'ordonnance → **dialogue de confirmation** (`AlertDialog`) obligatoire |
| **Bouton flottant** | `ExtendedFloatingActionButton` / `FloatingActionButton` | Action contextuelle principale (ex: « + Saisir signes vitaux ») |
| **Cartes** | `Card` / `ElevatedCard` / `OutlinedCard` | Patient, ordonnance, résultat de labo (élevée si anormal) |
| **Champs** | `OutlinedTextField` (Material 3) | Saisie structurée ; `supportingText` pour aide/erreur ; `isError` |
| **Sélection** | `FilterChip`, `Checkbox`/`Switch`, `RadioButton` | Consentements : cases explicites **jamais pré-cochées** (Loi 25) |
| **Listes** | `LazyColumn` (virtualisée) | Dossier patient, résultats (CHU : milliers de lignes) |
| **Top app bar** | `TopAppBar` (small/medium/large selon scroll — `TopAppBarScrollBehavior`) | Contexte + actions |
| **Feedback** | `Snackbar` (non bloquant), `AlertDialog` (bloquant), `CircularProgressIndicator`, `LinearProgressIndicator` | Erreurs réseau, confirmations, chargements |
| **Badges** | `Badge` | Alertes non lues, statut (ex: « critique » en rouge + texte) |
| **Dates/heures** | `DatePicker` (Material 3 modal/docked), `TimePicker` | RDV, soins programmés |
| **Saisie clinique** | `Slider` (échelle douleur 0–10), `OutlinedTextField` multiligne (notes), formulaires dynamiques (FHIR Questionnaire → Compose) | SOAP, échelles validées |
| **Icônes** | Material Symbols (ronds/remplis, poids ajustable) + icônes métier (stéthoscope, seringue, cœur) | Cohérence : 24 dp standard, 20 dp compact |

## 7.5 Spécificités cliniques

- **Alerte allergie critique** : bannière `Card` rouge en haut du dossier (persistante), + `Snackbar` à l'ouverture, + badge sur l'onglet patient. Jamais dismissible sans acquittement.
- **MAR (administration médicaments)** : liste des administrations dues (heure, médicament, dose), scan **code-barres/DIN** (CameraX + ML Kit) pour sécurité « 5 bons » (bon patient, bon médicament, bonne dose, bonne voie, bon moment), double validation infirmière.
- **Saisie signes vitaux** : formulaire rapide (FC, PA, SpO2, température, douleur) → FHIR Observation (LOINC), validation de cohérence (ex: SpO2 ≤ 100 %), mode vocal (dictée locale Android, on-device).
- **Télésanté** : salle d'attente virtuelle, contrôles vidéo (micro/caméra/raccrocher en `FloatingActionButton`-bar), indicateur d'enregistrement.
- **Portail patient** : résultats avec interprétation (couleur + texte + tendance), prise de RDV (créneaux libres), messagerie sécurisée, **gestion des consentements** (Loi 25 : activer/révoquer, historique), **export du dossier** (Bundle FHIR, partage chiffré).

## 7.6 Accessibilité (WCAG 2.2 AA)

- **TalkBack** : `contentDescription` sur icônes, `stateDescription`, annonces pour états (sélectionné, erreur).
- **Contraste** : 4,5:1 texte / 3:1 composants (vérifié thèmes clair/sombre + couleurs dynamiques — testées avec fonds utilisateur variés).
- **Cibles tactiles** : ≥ 48×48 dp (`minimumTouchTargetSize()`).
- **Taille de police** : support `fontScale` jusqu'à 1,3–2,0 (sp) sans casse de layout (`fixedSize` interdit sur texte clinique).
- **Switch Access / clavier** : navigation complète sans toucher.

## 7.7 Sécurité & confidentialité (mobile)

| Mesure | Implémentation |
|---|---|
| Authentification | Biométrie (**BiometricPrompt** : empreinte/visage) + PIN fallback ; session courte (verrouillage app après 5 min inactivité, configurable tenant) |
| Stockage clés | **Android Keystore** (clés non exportables, `StrongBox` si dispo) |
| Chiffrement local | **Jetpack Security** (EncryptedSharedPreferences, EncryptedFile) + **SQLCipher** (Room) pour le cache offline |
| Réseau | **Certificate pinning** (OkHttp CertificatePinner), TLS 1.3, pas de HTTP clair (`android:usesCleartextTraffic="false"`, Network Security Config stricte) |
| Capture d'écran | `FLAG_SECURE` sur écrans sensibles (dossier patient, télésanté) — configurable (portail patient exclu pour accessibilité) |
| Télémétrie | Sans PHI, consentement explicite (Loi 25) |
| Effacement à distance | Politique MDM (wipe app data) + effacement local à la révocation de session |

## 7.8 Mode hors-ligne (offline-first)

- **Room** (SQLCipher chiffré) : cache lecture (dossiers récents) + file écriture (notes, MAR en attente).
- **WorkManager** : synchronisation différée à la reconnexion (contraintes réseau, batterie), politique de retry exponentielle.
- **Conflits** : « dernier auteur averti », notification à l'utilisateur, jamais d'écrasement silencieux.
- Indicateur UI : bannière « Hors-ligne — X éléments en attente ».

## 7.9 Packaging & distribution

| Élément | Détail |
|---|---|
| Format | **AAB** (Android App Bundle) — Play Store ; APK signé pour distribution interne |
| Signature | Signature Play App Signing / clé interne (CHU) ; rotation de clé supportée |
| Cible | `targetSdk 37` (Android 17), `compileSdk 37`, `minSdk 29` |
| Distribution interne | CHU/CHSLD : **MDM** (Intune, Samsung Knox, Workspace ONE) ou portail interne signé |
| Mises à jour | **Play Core** in-app update (flexible/immediate) ; canal interne : auto-update signé |
| Variantes | `soignants` (complet) / `patient` (portail allégé) — flavors ou app distinctes selon stratégie Store |
| Taille | AAB < 60 Mo (séparation ABI/densité par le bundle) |

## 7.10 Performance (budgets)

| Métrique | Budget |
|---|---|
| Démarrage à froid → premier écran | < 2,5 s (appareil milieu de gamme) |
| Ouverture dossier patient (p95) | < 1,5 s |
| Rendu liste 1 000 observations (LazyColumn) | < 400 ms, jank < 1 % |
| Consommation mémoire (dossier ouvert) | < 250 Mo |
| Taille APK installé (split) | < 80 Mo |

## 7.11 Références

- Material 3 / Material You : https://m3.material.io/
- Jetpack Compose : https://developer.android.com/compose
- Android 17 / API 37 (cible) : https://developer.android.com/about/versions
- Skills associés : `wshobson/agents/mobile-android-design`, `krutikjain/android-agent-skills` (34 skills : android-material3-design-system, android-security-best-practices, android-compose-accessibility, android-room-database, android-serialization-offline-sync…), `aldefy/compose-skill`, `hamen/material-3-skill` — voir [chapitre 12](./12-catalogue-skills-sh-integration.md)
