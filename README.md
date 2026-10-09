# 🏥 HospiCore

> **HospiCore** est une plateforme intelligente de gestion hospitalière intégrant l’IA pour centraliser les dossiers médicaux électroniques (DME), optimiser le suivi des patients et faciliter leur orientation clinique. Elle privilégie la **sécurité**, la **confidentialité**, le **contrôle d’accès** et la **traçabilité** des données selon les normes internationales des DME (HL7 FHIR R4, Loi 25 QC, HIPAA, ISO 27001).

**Cibles** : CHU, CHSLD, cliniques multidisciplinaires (Québec/Canada).
**Plateformes** : **Windows 10 (2004+) / Windows 11** (WinUI 3 — Fluent Design, packagé MSIX) · **Android moderne** (Kotlin / Jetpack Compose — Material You) · **Web** (React PWA — portail patient & console admin).

---

## 📖 La Bible HospiCore (documentation complète)

> *« Ce n'est pas « juste du code » : c'est un projet d'ingénierie, de conformité légale et de confiance. »*

👉 **[INDEX DE LA BIBLE — point d'entrée](./docs/00-INDEX-DE-LA-BIBLE.md)**

| Chapitre | Contenu |
|---|---|
| [01 — Vision & Principes](./docs/01-vision-mission-principes.md) | Privacy by Design, souveraineté des données (QC/CA) |
| [02 — Bible de Conformité](./docs/02-bible-de-conformite.md) | Loi 25, HIPAA, ISO 27001, DSQ/Interop — matrice complète |
| [03 — Architecture Technique](./docs/03-architecture-technique-complete.md) | Microservices, stack, sécurité, infrastructure souveraine |
| [04 — Modèle de données FHIR R4](./docs/04-modele-de-donnees-fhir.md) | **Structure de la base de données du dossier patient selon FHIR** |
| [05 — Clients Windows/Android/Web](./docs/05-clients-windows-android-web.md) | Stratégie « tout en un », packaging, offline |
| [06 — UI/UX Windows 11 (Fluent)](./docs/06-direction-ui-ux-windows-11-fluent.md) | Fenêtrage, interface, interactions, boutons, icônes, MSIX |
| [07 — UI/UX Android (Material You)](./docs/07-direction-ui-ux-android-material-you.md) | Material 3, Jetpack Compose, adaptatif |
| [08 — Portail Web (PWA)](./docs/08-portail-patient-web-pwa.md) | React/TypeScript, WCAG 2.2 AA |
| [09 — Gouvernance & Sécurité](./docs/09-gouvernance-securite-risques.md) | DPO, comité médical, CISO, gestion des risques |
| [10 — Roadmap (4 phases)](./docs/10-roadmap-phases-developpement.md) | Mois 1–24 |
| [11 — Budget & Équipe](./docs/11-budget-equipe-recrutement.md) | 15–20 personnes, 3–5 M$ CAD/an |
| [12 — Catalogue Skills (skills.sh)](./docs/12-catalogue-skills-sh-integration.md) | Tous les skills à intégrer (DME & IA) + commandes |
| [13 — Standards Qualité & CI/CD](./docs/13-standards-qualite-cicd.md) | Tests, sécurité, pipelines |
| [14 — Prochaines étapes](./docs/14-prochaines-etapes-lancement.md) | Checklist de lancement |
| [ADR](./docs/adr/) | 9 décisions d'architecture (FHIR R4, .NET, WinUI 3, Compose, React PWA, PostgreSQL JSONB, MSIX, offline, IA) |

## 🗄️ Base de données

- **[Schéma SQL PostgreSQL (FHIR R4)](./database/hospicore_fhir_core.sql)** — patients, observations, ordonnances, MAR, audit immuable, RLS, magasin FHIR JSONB…
- **[Guide base de données](./database/README.md)**

## 🧩 Skills agents (skills.sh)

- **[Manifeste des skills](./skills/skills-manifest.json)** — catalogue machine-readable
- **[Guide d'installation](./skills/README.md)** — `npx skills add …`
- Découverte : [skills.sh](https://skills.sh/)

## 🎨 Design system

- **[Design tokens partagés](./design/tokens.json)** (Windows / Android / Web)

## 🚀 Démarrage rapide

```bash
git clone https://github.com/Moulex7/HospiCore-.git
cd HospiCore-
# Base de données (PostgreSQL 16)
docker run --name hospicore-pg -e POSTGRES_PASSWORD=dev -p 5432:5432 -d postgres:16
psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -f database/hospicore_fhir_core.sql
```

Voir le [chapitre 14 — Prochaines étapes](./docs/14-prochaines-etapes-lancement.md) pour le lancement complet.

## 🤝 Contribuer

Toute modification de la **Bible** (dossier `docs/`) passe par **Pull Request** relue (CTO/DPO selon le sujet). Voir [13 — Standards Qualité & CI/CD](./docs/13-standards-qualite-cicd.md).

## 📄 Licence

[Apache License 2.0](./LICENSE)
