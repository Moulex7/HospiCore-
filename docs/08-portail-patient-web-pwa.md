# 08 — Portail Patient Web (PWA) & Console Admin

> Interface **Web** d'HospiCore : **portail patient** (React 19 + TypeScript, PWA installable) et **console d'administration** (audit, utilisateurs, configuration). Navigateurs Evergreen (2 dernières versions majeures).

---

## 8.1 Objectifs

1. **Autonomiser le patient** : RDV, résultats, messagerie sécurisée, consentements (Loi 25), export de son dossier.
2. **Alléger l'administration** : console opérateur (réception, admin établissement, audit).
3. **Être installable** (PWA) pour une expérience « app-like » sur mobile et desktop.
4. **Être exemplaire** : WCAG 2.2 AA, performance (Lighthouse ≥ 90), sécurité (CSP stricte).

## 8.2 Stack

| Couche | Technologie |
|---|---|
| Framework | **React 19 + TypeScript (strict, `noUncheckedIndexedAccess`)** |
| Build | **Vite** (dev rapide, bundles optimaux) |
| Routing | React Router (data APIs) |
| État serveur | **TanStack Query** (cache, revalidation, offline) |
| Formulaires | React Hook Form + **Zod** (validation schéma, alignée FHIR) |
| UI | Design system **HospiCore DS** (tokens partagés) + composants accessibles (base Radix UI) |
| PWA | **Vite PWA Plugin** (Workbox) : manifest, service worker, stratégies de cache |
| Tests | Vitest (unit), React Testing Library, **Playwright** (E2E), **axe-core** (a11y) |
| Télésanté | **WebRTC** (navigateur) — salle d'attente virtuelle côté portail |

## 8.3 Design system HospiCore DS (web)

- **Tokens** (`design/tokens.json` partagé avec Windows/Android) : couleurs (sémantiques clinique : `--color-danger`, `--color-warning`, `--color-success`, `--color-info`), espacements (4-pt grid), rayons, typographie (Inter ou **Segoe UI** si Windows), ombres, durées d'animation.
- **Thèmes** : clair / sombre / contraste élevé (respect `prefers-contrast` + `prefers-color-scheme`).
- **Composants** : Button (primary/secondary/danger/ghost), Card, Badge, TextField, Select, DatePicker, Dialog (modale accessible, focus trap), Toast, InfoBar (4 niveaux), DataTable (tri/filtre/pagination serveur), Timeline (chronologie clinique), Skeleton (chargement).
- **Règle clinique** : l'information vitale n'est **jamais** véhiculée par la couleur seule (icône + texte + couleur).

## 8.4 Portail patient — parcours

| Écran | Fonctionnalités | FHIR |
|---|---|---|
| **Accueil** | Prochain RDV, alertes (résultats nouveaux, rappels vaccins), raccourcis | `Appointment`, `Observation`, `Immunization` |
| **Prise de RDV** | Choix praticien/spécialité/lieu, créneaux libres, confirmation, annulation, rappels SMS/courriel | `Slot`, `Appointment` |
| **Résultats** | Labos/imagerie avec interprétation (valeur, référence, tendance graphique), téléchargement PDF signé | `Observation`, `DiagnosticReport`, `DocumentReference` |
| **Dossier** | Antécédents, allergies, médicaments actuels, vaccins (lecture seule) | `Condition`, `AllergyIntolerance`, `MedicationRequest`, `Immunization` |
| **Messagerie sécurisée** | Écrire à l'équipe soignante, pièces jointes chiffrées, fils de discussion | `Communication` |
| **Télésanté** | Salle d'attente virtuelle, test micro/caméra, rejoindre la consultation | WebRTC + `Encounter` (class=VR) |
| **Consentements (Loi 25)** | Voir, **donner, révoquer** ses consentements, historique horodaté | `Consent` |
| **Mes données** | **Export complet** (Bundle FHIR — droit à la portabilité), demande de rectification, préférence de contact | `Patient/$everything` |

## 8.5 Console admin — parcours

| Écran | Rôle |
|---|---|
| Utilisateurs & rôles | CRUD utilisateurs, rôles RBAC, réinitialisation MFA (admin établissement) |
| Audit | Piste d'audit (qui a vu quoi), filtres, export (DPO/auditeur) |
| Configuration tenant | Rétention, politiques offline, intégration RAMQ, terminologies |
| Télésanté | Salles actives, qualité, journaux (sans contenu) |
| Incidents | Registre des incidents de confidentialité (Loi 25), workflow déclaration CAI |

## 8.6 PWA (capacités offline)

| Capacité | Stratégie (Workbox) |
|---|---|
| Shell app | **Precache** (app shell versionné) |
| API FHIR | **NetworkFirst** (TTL 5 min) pour données fraîches, fallback cache |
| Résultats consultés | Cache **chiffré** côté client (IndexedDB + WebCrypto AES-GCM) — TTL 8 h, effacé à la déconnexion |
| Actions offline | File locale chiffrée (messages non envoyés, brouillons) — sync au retour en ligne |
| Notifications push | Rappels RDV, résultats disponibles (consentement explicite) |
| Installation | Manifest (nom, icônes, `display: standalone`, thème) + « Ajouter à l'écran d'accueil » |

**Sécurité PWA** : pas de PHI en clair dans le cache SW (les données sensibles passent par IndexedDB **chiffré**, jamais par le cache HTTP des réponses API brutes). Pas de PHI dans `localStorage` (préférer sessionStorage chiffré ou mémoire).

## 8.7 Accessibilité (WCAG 2.2 AA — bloquant)

- HTML sémantique, `lang="fr"`, landmarks, titres hiérarchisés.
- Clavier complet (focus visible, skip links, focus trap dialogues, `Esc`).
- `aria-live` pour toasts/résultats nouveaux ; `role="alert"` pour erreurs.
- Contraste ≥ 4,5:1 ; cible 44×44 px (tactile) ; zoom 200 % sans perte.
- Tests **axe-core** automatisés (CI) + audit manuel annuel (Narrator/VoiceOver).

## 8.8 Sécurité web

| Mesure | Détail |
|---|---|
| Authentification | OIDC (Keycloak) + MFA ; session courte (15 min inactivité portail) |
| Cookies | `HttpOnly`, `Secure`, `SameSite=Strict` (session), jetons en mémoire (pas localStorage) |
| CSP | `default-src 'self'`, `connect-src` limité (API + WebRTC), `frame-ancestors 'none'`, `object-src 'none'` |
| Headers | HSTS, X-Content-Type-Options, Referrer-Policy, Permissions-Policy |
| Dépendances | Audit npm (CI), Snyk/Dependabot, lockfile figé |
| Télésanté Web | WebRTC chiffré (DTLS-SRTP), TURN/STUN souverains QC, consentement enregistrement |

## 8.9 Performance (budgets)

| Métrique | Budget |
|---|---|
| LCP (portail, connexion rapide) | < 2,0 s |
| INP (interaction) | < 200 ms |
| Bundle initial (JS gzip) | < 250 Ko |
| Lighthouse (Perf/A11y/BP/SEO) | ≥ 90 / 100 / 100 / 90 |
| Cache hit ratio (2e visite) | ≥ 80 % |

## 8.10 Références

- Skills associés : `anthropics/skills/frontend-design`, `hieutrtr/ai1-skills/react-frontend-expert`, `supercent-io/skills-template/web-accessibility`, `wshobson/agents/accessibility-compliance`, `testdino-hq/playwright-skill`, `fugazi/test-automation-skills-agents/playwright-e2e-testing`, `pramoddutta/qaskills` (axe-core, WCAG, gdpr compliance testing) — voir [chapitre 12](./12-catalogue-skills-sh-integration.md)
