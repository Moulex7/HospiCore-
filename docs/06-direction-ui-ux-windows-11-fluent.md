# 06 — Direction UI/UX : Windows 11 (Fluent Design)

> Application de travail clinique HospiCore pour **Windows 10 (version 2004 / build 19041) et ultérieur**, optimisée pour **Windows 11**. Framework : **WinUI 3 / Windows App SDK**, packagée **MSIX**.
> Objectif : une app **native, rapide, accessible et rassurante** — digne d'un poste de travail clinique (CHU/CHSLD).

---

## 6.1 Principes directeurs (Fluent Design — Windows 11)

| Principe | Application concrète dans HospiCore |
|---|---|
| **Lumière** | Hiérarchie claire : contenu avant chrome. Pas de décoration gratuite. |
| **Profondeur** | Ombres subtiles, élévation des panneaux (cartes patient, alertes) pour la priorité visuelle. |
| **Mouvement** | **Animations implicites** (Connected/Implicit animations) — transitions 150–300 ms, courbes standard (ease-out). Jamais de mouvement superflu en contexte clinique. |
| **Matériaux** | **Mica** (fond fenêtre principale — sobre, performant), **Acrylic** (barre de navigation/commandes, avec fallback si transparence désactivée). Respecter les préférences système (transparence off → fond uni). |
| **Géométrie** | **Coins arrondis** (radius 4–8 px selon niveau), contours fins (1 px, `CardStrokeColorDefaultBrush`). |
| **Typographie** | **Segoe UI Variable** (système) ; échelle Fluent (Caption 12 / Body 14 / Subtitle 20 / Title 28 / Display 40). Contraste AA obligatoire. |
| **Couleur** | Palette système (clair/sombre/contraste élevé), **accent utilisateur** Windows pour les éléments interactifs primaires. Sémantique clinique réservée : rouge = alerte/allergie critique, orange = avertissement, vert = OK, bleu = information (jamais de couleur seule pour l'info — toujours + icône + texte). |
| **Icônes** | **Fluent System Icons** (cohérentes, 16/20/24/32 px), style régulier (outline) par défaut, rempli pour l'état sélectionné. Taille tactile/clavier : 20 px dans les listes, 16 px en densité compacte. |

## 6.2 Fenêtrage (Windowing — cœur de l'identité Windows 11)

| Élément | Spécification |
|---|---|
| **Fenêtre** | `AppWindow` (Windows App SDK) — pas de `HWND` legacy. Taille min 1024×640 ; mémoriser position/taille à la fermeture (par utilisateur). |
| **Barre de titre** | `ExtendsContentIntoTitleBar = true` + `SetTitleBar()` custom : logo HospiCore, **recherche globale** (dossier patient, patient par NAM), boutons fenêtre natifs (min/max/fermer) conservés. Hauteur 48 px. |
| **Snap Layouts** | Support natif Windows 11 : disposition en « grille de dossiers » (2–3 patients côte à côte). Bouton maximize survol → Snap Layouts ; raccourci `Win + Z`. |
| **Onglets de dossiers** | `TabView` : un onglet = un **dossier patient** (max 8 ouverts, au-delà menu « … »). Badge sur l'onglet : alertes non lues (allergies critiques, résultats nouveaux). Fermeture avec confirmation si note non enregistrée. **Restauration de session** au redémarrage (liste des onglets, sans PHI en clair dans le cache de session). |
| **Fenêtres secondaires** | `AppWindow` modales légères pour : nouvelle ordonnance, consentement, télésanté (fenêtre flottante toujours-au-dessus optionnelle). Jamais de `Window.ShowDialog()` bloquant le UI thread. |
| **Multi-fenêtres** | Support : détacher un dossier patient dans une **seconde fenêtre** (scénario bi-écran CHU). Synchronisation temps réel (SignalR) entre fenêtres. |
| **État réduit** | Minimiser vers la barre des tâches avec **aperçu live** (dernier onglet actif). |

## 6.3 Navigation & structure de l'interface

```text
┌──────────────────────────────────────────────────────────────┐
│ [≡] HospiCore   [ Recherche globale.............. ]  [🔔][👤] │  ← Barre de titre (Mica)
├────────┬─────────────────────────────────────────────────────┤
│        │  [TabView : onglets dossiers patients]               │
│  NAV   │  ┌─────────────────────────────────────────────┐    │
│        │  │  COMMAND BAR (contexte dossier)             │    │
│  ▼     │  │  [Nouvelle note] [Ordonnance] [Signes vitaux]│   │
│  Patient│  └─────────────────────────────────────────────┘    │
│  Agenda │                                                     │
│  Télésanté│      CONTENU (2–3 colonnes selon largeur)        │
│  Facturation│   ┌─────────┐ ┌──────────────┐ ┌───────────┐   │
│  Stock │   │ Résumé  │ │ Chronologie  │ │ Alertes   │   │
│  Admin │   │ patient │ │ (timeline    │ │ (allergies│   │
│        │   │ (carte) │ │  observations│ │  critiques│   │
│        │   │         │ │  notes, RDV) │ │  résultats)│  │
│        │   └─────────┘ └──────────────┘ └───────────┘   │
├────────┴─────────────────────────────────────────────────────┤
│  Barre d'état : établissement · utilisateur · rôle · synchro │  ← statut offline/online
└──────────────────────────────────────────────────────────────┘
```

| Composant | Contrôle WinUI 3 | Règles |
|---|---|---|
| Navigation latérale | `NavigationView` (mode LeftCompact → Left, auto selon largeur) | Icône + libellé ; section « clinique » vs « admin » ; item actif surligné (accent). Panneau rétractable (clavier + geste). |
| Fil d'Ariane | `BreadcrumbBar` | Toujours visible dans un dossier : Accueil / Patient / Note du 2026-10-09. |
| Contenu | Grilles adaptatives (`AdaptiveTrigger`, 4 paliers : <720 / 720–1000 / 1000–1400 / >1400 px) | Colonnes empilées sur étroit, côte à côte sur large. |
| Commandes contextuelles | `CommandBar` (flottante en haut du contenu dossier) + `CommandBarFlyout` (menus contextuels `…`) | Actions fréquentes visibles, le reste dans « ⋯ » (max 5 primaires). |
| Listes | `ListView`/`ItemsView` avec virtualisation | Dossier patient = liste virtualisée (CHU : 100k+ patients/tenant). |
| Onglets internes | `TabView` secondaire ou `Pivot` | Sections du dossier : Résumé / Notes / Ordonnances / Résultats / Historique. |

## 6.4 Interactions & contrôles (bibliothèque de patterns)

| Contrôle | Usage | Spécificité HospiCore |
|---|---|---|
| **Bouton principal** | `Button` style `AccentButtonStyle` | Une seule action primaire visible par écran (ex: « Enregistrer la note »). Rayon 4 px, hauteur 32 px, icône 16 px + libellé. |
| **Bouton secondaire** | `Button` (défaut) | Actions secondaires (Annuler, Fermer). |
| **Bouton dangereux** | `Button` + `SubtleButtonStyle` ou style rouge sémantique | « Supprimer », « Annuler l'ordonnance » → **confirmation obligatoire** (`ContentDialog`) + motif. |
| **Case à cocher / Radio** | `CheckBox` / `RadioButtons` | Consentements (Loi 25) : cases explicites, jamais pré-cochées. |
| **Saisie** | `TextBox` / `NumberBox` / `AutoSuggestBox` | Validation à la saisie (bordure rouge + `InfoBar` message). `AutoSuggestBox` pour médicaments (RxNorm), diagnostics (ICD-10-CA/SNOMED), patients (NAM). |
| **Date/heure** | `CalendarDatePicker` + `TimePicker` | RDV, dates de soins. |
| **Notifications** | `InfoBar` (inline, 4 niveaux : Informational/Success/Warning/Error) + `TeachingTip` (aide contextuelle) + `Notification` (toast système pour alertes critiques) | Alertes allergie critique = `InfoBar` Error **persistante** en haut du dossier + toast. |
| **Dialogues** | `ContentDialog` (modale, focus piégé, Échap ferme) | Jamais pour de la simple confirmation destructive — préférer `InfoBar` + bouton. Titre explicite, boutons : primaire à droite. |
| **Menus** | `MenuFlyout` / `CommandBarFlyout` | Raccourcis clavier affichés (`Ctrl+N` nouvelle note…). |
| **Recherche** | `AutoSuggestBox` global (barre de titre) + filtres par liste (`AutoSuggestBox` + `DropDownButton` filtres) | Recherche patient : nom, NAM, RAMQ, DDN — résultats triés par pertinence (trigramme). |
| **Tableaux** | `DataGrid` (CommunityToolkit) ou `ItemsView` custom | Résultats de labo : colonnes LOINC, valeur, unité, référence, interprétation (badge couleur + texte). Tri + filtre par colonne. |
| **Saisie clinique structurée** | Formulaires dynamiques (JSON FHIR Questionnaire → contrôles) | Notes SOAP, échelles (PHQ-9, douleur 0–10 `Slider`/`RatingControl`). |
| **Indicateurs** | `ProgressRing` (chargement), `ProgressBar`, `Badge`/`PersonPicture` | Patient : `PersonPicture` (initiales si pas de photo, photo chiffrée sinon). |

## 6.5 Raccourcis clavier & productivité (clinique = vitesse)

| Raccourci | Action |
|---|---|
| `Ctrl + K` | Recherche globale (palette de commandes, style VS Code — `CommandPalette` custom) |
| `Ctrl + N` | Nouvelle note SOAP |
| `Ctrl + Shift + O` | Nouvelle ordonnance |
| `Ctrl + 1..9` | Basculer onglet dossier |
| `Ctrl + T` | Nouvel onglet (nouveau patient via recherche) |
| `Ctrl + W` | Fermer onglet (confirmation si non enregistré) |
| `Ctrl + ,` | Paramètres |
| `F5` | Rafraîchir / synchroniser |
| `Échap` | Fermer dialogue/flyout, quitter la recherche |
| `Tab` / `Maj+Tab` | Navigation complète au clavier (ordre logique) |
| `Win + Z` | Snap Layouts (natif) |

**Palette de commandes** (`Ctrl+K`) : recherche universelle (patients, actions, paramètres, aide) — pattern « command palette » pour les utilisateurs avancés.

## 6.6 Accessibilité (obligatoire — WCAG 2.2 AA)

- **Narrator** : `AutomationProperties.Name/HelpText` sur tout contrôle custom ; régions live (`LiveSetting.Polite`) pour les alertes nouvelles (résultat critique arrivé).
- **Clavier seul** : tout parcours clinique réalisable sans souris ; focus visible (`FocusVisualPrimaryBrush`, épaisseur 2 px, jamais supprimé).
- **Contraste** : ≥ 4,5:1 (texte), ≥ 3:1 (UI) — vérifié clair/sombre/contraste élevé.
- **Thèmes** : Clair, Sombre, **Contraste élevé** (HighContrast theme supporté), préférences système respectées (`ApplicationTheme` + `ActualThemeChanged`).
- **Taille** : respect du facteur d'échelle Windows (100–200 %), pas de texte tronqué (vérifié à 200 %).
- **Réduction mouvement** : respecter « Afficher les animations » off (Windows) → désactiver animations implicites.
- **Lecteur d'écran clinique** : annonce structurée des alertes (allergie = `LiveSetting.Assertive`).

## 6.7 Télésanté (module vidéo dans l'app Windows)

- Salle d'attente virtuelle (liste patients, état « prêt »), bouton « Admettre ».
- Fenêtre vidéo : contrôles flottants (micro/caméra/raccrocher), taille ajustable, **toujours au-dessus** optionnel.
- Indicateur visuel « ENREGISTREMENT EN COURS » (si consentement) + bannière rouge persistante.
- Partage d'écran (ducation patient) avec consentement explicite.

## 6.8 Mode hors-ligne & synchronisation

- Bannière `InfoBar` discrète : « Mode hors-ligne — 3 éléments en attente de synchronisation ».
- File locale chiffrée (SQLite + SQLCipher) : brouillons de notes, saisies MAR en attente.
- Synchronisation à la reconnexion (ordre chronologique, résolution de conflits « dernier auteur averti », jamais d'écrasement silencieux).
- Lecture seule des dossiers récemment consultés (cache chiffré, TTL 8 h, effacé à la déconnexion si politique tenant l'exige).

## 6.9 Packaging & déploiement (MSIX)

| Élément | Détail |
|---|---|
| Format | **MSIX** (`.msix` / `.msixbundle`), runtime **Windows App SDK auto-contenu** (self-contained) |
| Cibles | Windows 10 2004 (19041)+ → Windows 11 24H2+ (`TargetDeviceFamily` Windows.Universal, min 10.0.19041.0) |
| Signature | Certificat **Authenticode** (EV recommandé pour la confiance CHU) |
| Identité | `Package/Identity` (Name `HospiCore`, Publisher CN=<org>, Version 4-parties) |
| Capacités | `internetClient`, `privateNetworkClientServer` (télésanté locale), **pas** de `runFullTrust` non justifiée ; accès biométrie via Windows Hello (API système, pas de capacité brute) |
| Mise à jour | Auto-update MSIX (App Installer), canal : Store / sideload / **Intune** |
| Désinstallation | Propre (pas de résidu registre) — requis pour les hôpitaux |
| Taille | Objectif < 150 Mo (runtime self-contained inclus) |

## 6.10 Performance (budgets)

| Métrique | Budget |
|---|---|
| Démarrage à froid → premier écran | < 3 s (SSD, machine clinique standard) |
| Ouverture dossier patient (p95) | < 1,5 s |
| Rendu liste 1 000 observations | < 500 ms (virtualisation) |
| Consommation mémoire (1 dossier ouvert) | < 350 Mo |
| Temps de réponse saisie (AutoSuggest RxNorm) | < 200 ms (cache local + API) |

## 6.11 Références

- Fluent Design System : https://fluent2.microsoft.design/
- WinUI 3 / Windows App SDK : https://learn.microsoft.com/windows/apps/windows-app-sdk/
- Fluent System Icons : https://github.com/microsoft/fluentui-system-icons
- Windows App SDK samples (windowing, TabView) : https://github.com/microsoft/WindowsAppSDK-Samples
- Skills associés : `microsoft/win-dev-skills`, `openai/skills/winui-app`, `wshaddix/dotnet-skills` (dotnet-winui, dotnet-msix), `managedcode/dotnet-skills`, `novotnyllc/dotnet-artisan` (dotnet-winui, dotnet-accessibility) — voir [chapitre 12](./12-catalogue-skills-sh-integration.md)
