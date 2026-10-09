# 05 — Clients Windows / Android / Web : Stratégie « Tout en un »

> Un **seul produit HospiCore**, une **seule donnée** (noyau FHIR), **trois expériences natives** : Windows 10 (2004) / Windows 11, Android moderne, et Web (PWA).

---

## 5.1 Contrat de plateformes

| Plateforme | Versions supportées | Stack | Design system | Distribution |
|---|---|---|---|---|
| **Windows (application de travail clinique)** | **Windows 10 version 2004 (build 19041) et ultérieur ; Windows 11 (22H2/23H2/24H2+)** | **WinUI 3 + Windows App SDK 1.6+**, .NET 9, C# | **Fluent Design (Windows 11)** | **MSIX** (Microsoft Store + sideloading entreprise) ; MSIX Core pour déploiement legacy |
| **Android (soignants mobiles + portail patient)** | **Android moderne — cible Android 17 (API 37)**, minSdk 29 (Android 10) ; dynamic color sur Android 12+ (API 31+) | **Kotlin 2.x + Jetpack Compose + Material 3 (Material You)** | **Material You** (couleurs dynamiques, typographie expressive) | **AAB** sur Play Store (public) + APK/AAB signé pour distribution interne CHU/CHSLD (MDM) |
| **Web (portail patient + console admin)** | Navigateurs Evergreen (Chrome, Edge, Firefox, Safari — 2 dernières versions majeures) | **React 19 + TypeScript (strict)**, Vite, TanStack Query | Design system interne **HospiCore DS** aligné Fluent/Material | **PWA installable** (service worker, offline léger) |

## 5.2 Philosophie : « Un noyau, trois habillages natifs »

```text
┌────────────────────────────────────────────────────────────┐
│              NOYAU HOSPICORE (unique, FHIR R4)             │
│   API FHIR · RBAC/ABAC · Consentements · Audit · Cache     │
└───────────┬──────────────────────┬─────────────────────────┘
            │                      │
   ┌────────▼────────┐    ┌────────▼────────┐    ┌─────────▼────────┐
   │  WinUI 3 (Win)  │    │ Compose (Android)│    │  React PWA (Web) │
   │  Fluent Design  │    │  Material You    │    │  HospiCore DS    │
   │  Fenêtrage W11  │    │  Adaptatif       │    │  Responsive      │
   │  MSIX           │    │  AAB             │    │  Installable     │
   └─────────────────┘    └─────────────────┘    └──────────────────┘
            │                      │                      │
            └──────────────────────┴──────────────────────┘
                                   │
                    Couche « cœur partagé » (recommandée)
              Kotlin Multiplatform (KMP) ou bibliothèque .NET
        (modèles FHIR, règles métier, validation, offline sync)
```

**Pourquoi pas un seul framework multiplateforme (ex: .NET MAUI/Flutter) ?**
Parce que le contrat UX exige le **meilleur de chaque plateforme** : le fenêtrage Windows 11 (Snap Layouts, onglets, barre de titre personnalisée) et Material You sur Android ne sont pas atteignables fidèlement avec un rendu web embarqué. HospiCore investit dans **l'UX native** — c'est un différenciateur face aux DME vieillissants.

**Ce qui est partagé** (évite la divergence) :
- **Contrats FHIR R4** (générés : types TypeScript/Kotlin/C# depuis les profils FHIR — *FHIRенная code-gen* via Firely/Simplifier tooling).
- **Règles métier pures** : validation clinique, calculs (scores, péremption), mapping terminologies — embarquées via **Kotlin Multiplatform** (consommé par Android + backend JVM) et miroirs C# pour Windows.
- **Design tokens** (couleurs, espacements, typographie, rayons) versionnés dans ce dépôt (`design/tokens.json`) et consommés par les trois plateformes.
- **Stratégie offline/sync** identique (ADR-008).

## 5.3 Client Windows — WinUI 3 (résumé; détails au chapitre 06)

- **Framework** : WinUI 3 + Windows App SDK, .NET 9, C# 13.
- **UX** : Fluent Design Windows 11 (Mica, Acrylic, coins arrondis, ombre, animations implicites).
- **Fenêtrage** : `AppWindow` moderne, barre de titre personnalisée, **Snap Layouts**, onglets de dossiers patients (`TabView`), restauration de session.
- **Packaging** : **MSIX** (identité de package, auto-mise à jour, désinstallation propre), signature Authenticode, Store ou sideloading.
- **Sécurité** : crédentiels dans **Windows Hello** (biométrie), stockage chiffré local (DPAPI + AES-256), AppContainer.
- **Offline** : cache local chiffré (SQLite + SQLCipher) + file de sync.

## 5.4 Client Android — Jetpack Compose (résumé; détails au chapitre 07)

- **Framework** : Kotlin 2.x, Jetpack Compose, Material 3 (Material You), cible API 37 (Android 17), minSdk 29.
- **UX** : Material You — **couleurs dynamiques** (Monet) sur Android 12+, thème clair/sombre, typographie expressive, composants adaptatifs (phones, tablettes, pliables).
- **Navigation** : Navigation 3, bottom bar + rail/drawer selon taille d'écran.
- **Sécurité** : Android Keystore (clés biométriques), chiffrement local (Jetpack Security crypto / SQLCipher), certificate pinning (OkHttp), Biomètre via BiometricPrompt.
- **Distribution** : AAB Play Store + canal interne (CHU/CHSLD) ; mises à jour in-app (Play Core).
- **Offline** : Room chiffré + WorkManager pour sync différée.

## 5.5 Client Web — React PWA (résumé; détails au chapitre 08)

- **Framework** : React 19 + TypeScript (strict), Vite, TanStack Query, React Router.
- **PWA** : installable (manifest + service worker), mode offline lecture (résultats en cache chiffré navigateur — IndexedDB chiffré), notifications push (rappels RDV).
- **Portail patient** : RDV, résultats, messagerie sécurisée, consentements (Loi 25), export de son dossier (Bundle FHIR — droit à la portabilité).
- **Console admin** : gestion utilisateurs/rôles, audit, configuration tenant.
- **Sécurité** : CSP stricte, HttpOnly/Secure/SameSite cookies (ou tokens en mémoire), pas de PHI en localStorage.

## 5.6 Matrice des fonctionnalités par plateforme

| Fonctionnalité | Windows (WinUI 3) | Android (Compose) | Web (PWA) |
|---|:-:|:-:|:-:|
| Dossier patient (lecture/écriture) | ✅ complet | ✅ complet | ✅ portail (lecture + messagerie) |
| Notes SOAP | ✅ | ✅ | ❌ |
| MAR / administration médication | ✅ | ✅ (tablette soins) | ❌ |
| Agenda & RDV | ✅ | ✅ | ✅ (patient : prise de RDV) |
| Télésanté (vidéo) | ✅ (app) | ✅ (app) | ✅ (WebRTC navigateur) |
| Facturation RAMQ/assureurs | ✅ | ❌ | ❌ |
| Inventaire/stock | ✅ | ✅ (consultation lots) | ❌ |
| Portail patient (résultats, messagerie, consentements) | ❌ | ✅ (app patient) | ✅ (portail principal) |
| Console admin/audit | ✅ | ❌ | ✅ |
| Mode hors-ligne | ✅ (sync file) | ✅ (Room + WorkManager) | ⚠️ lecture cache |
| Scribe IA (dictée) | ✅ | ✅ | ⚠️ (Phase 4) |

## 5.7 Packaging & déploiement

| Plateforme | Format | Canal | Mise à jour |
|---|---|---|---|
| Windows | **MSIX** (+ `.msixbundle`), signé Authenticode | Microsoft Store, sideloading (App Installer), Intune/MDM | Auto-update MSIX (silencieuse en arrière-plan) |
| Android | **AAB** (Play) / APK signé (interne) | Play Store, MDM interne (Intune, Samsung Knox, VMware Workspace ONE) | Play Core in-app update / mise à jour silencieuse MDM |
| Web | PWA (HTTPS) | Hébergement CDN (résidence CA) + domaine client | Déploiement continu (GitOps), cache SW versionné |

**Note MDM** : les CHU/CHSLD déploient souvent via MDM d'entreprise — prévoir des builds « internes » (pas de Store requis) et la configuration distante (URL tenant, politique offline, durée de session).

## 5.8 Télémétrie & conformité (clients)

- **Aucun PHI** dans la télémétrie (crashs, perf) — identifiants de session aléatoires, données agrégées.
- **Consentement** explicite pour la télémétrie (Loi 25), désactivable.
- **Journaux clients** : chiffrés au repos, rotation, jamais de contenu clinique.

## 5.9 KPIs par plateforme

| KPI | Cible |
|---|---|
| Temps de démarrage à froid (Windows) | < 3 s |
| Temps de chargement dossier (p95, toutes plateformes) | < 1,5 s |
| Taille paquet MSIX | < 150 Mo (auto-contenu WAS) |
| Taille AAB | < 60 Mo |
| Score Lighthouse PWA (portail) | ≥ 90 (perf, a11y, best practices, SEO) |
| Couverture tests UI (Composants/Compose UI/Playwright) | ≥ 80 % parcours critiques |
| Crash-free sessions | ≥ 99,5 % |

*Voir aussi : [06 — UI/UX Windows 11](./06-direction-ui-ux-windows-11-fluent.md), [07 — UI/UX Android](./07-direction-ui-ux-android-material-you.md), [08 — Portail Web](./08-portail-patient-web-pwa.md), ADR-003/004/005/007/008*
