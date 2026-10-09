# ADR-005 — Web : React 19 + TypeScript (PWA) pour le portail patient & la console admin

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, lead Web, UX lead, DPO

## Contexte

Le **portail patient** (RDV, résultats, messagerie, consentements, export du dossier) doit être accessible **partout** (téléphone, tablette, ordinateur — y compris postes partagés) sans installation, et la **console admin** doit être utilisable depuis un navigateur. Contraintes : WCAG 2.2 AA, sécurité (pas de PHI côté client en clair), performance (Lighthouse ≥ 90).

## Décision

Le web est en **React 19 + TypeScript (strict) + Vite + TanStack Query**, en **PWA installable** :

- **Portail patient** : RDV (FHIR Slot/Appointment), résultats (Observation/DiagnosticReport), messagerie (Communication), **consentements (FHIR Consent — Loi 25)**, export Bundle FHIR (`Patient/$everything`), télésanté (WebRTC navigateur).
- **Console admin** : utilisateurs/rôles, audit, configuration tenant, registre incidents.
- **PWA** : manifest + service worker (Workbox) : shell precache, API NetworkFirst, résultats en cache **chiffré** (IndexedDB + WebCrypto AES-GCM), notifications push (rappels).
- **Sécurité** : OIDC (Keycloak) + MFA, cookies HttpOnly/Secure/SameSite, CSP stricte, **pas de PHI en localStorage**.
- **Accessibilité** : WCAG 2.2 AA (axe-core en CI, tests clavier/Narrator/VoiceOver).

## Conséquences

- ✅ Aucune installation pour le patient ; accessible sur tout appareil.
- ✅ Écosystème riche (React, tests Playwright, a11y) et compétences faciles à recruter.
- ✅ PWA = expérience « app » (icône, plein écran, notifications, offline lecture).
- ⚠️ Télésanté WebRTC : support navigateur à vérifier (Evergreen OK), TURN/STUN souverains QC requis.
- ⚠️ Cache navigateur : données chiffrées uniquement, TTL court, effacement à la déconnexion.

## Alternatives considérées

- **Blazor (WASM)** : cohérence .NET, mais écosystème PWA/a11y moins mature et perf WASM pour listes cliniques — rejeté pour le portail.
- **Angular** : enterprise, mais courbe plus lourde et écosystème a11y/PWA en retrait — rejeté.
- **Next.js (SSR)** : intéressant pour le SEO/landing, mais le portail est une app authentifiée (SPA/PWA suffit) — non retenu en v1.
