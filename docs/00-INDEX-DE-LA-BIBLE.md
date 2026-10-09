# 📖 LA BIBLE HOSPICORE

> **Référence absolue** pour toutes les équipes (développement, juridique, médicale, produit).
> HospiCore est un **Dossier Médical Électronique (DME/EMR)** de niveau entreprise destiné aux **CHU, CHSLD et cliniques multidisciplinaires** du Québec/Canada. Ce n'est pas « juste du code » : c'est un projet d'**ingénierie, de conformité légale et de confiance**.

**Version** : 1.0.0 · **Date** : 2026-10-09 · **Licence** : Apache 2.0

---

## Table des matières

### Partie I — Vision & Conformité
| # | Document | Contenu |
|---|---|---|
| 01 | [Vision, Mission & Principes fondamentaux](./01-vision-mission-principes.md) | Privacy by Design, souveraineté des données (QC/CA), principes directeurs |
| 02 | [Bible de Conformité (Bouclier juridique)](./02-bible-de-conformite.md) | Loi 25 (QC), HIPAA, ISO 27001, DSQ/Interop, normes médicales — matrice complète |

### Partie II — Architecture & Données
| # | Document | Contenu |
|---|---|---|
| 03 | [Architecture technique complète](./03-architecture-technique-complete.md) | Microservices, schéma C4, stack, sécurité, infrastructure souveraine |
| 04 | [Modèle de données FHIR R4](./04-modele-de-donnees-fhir.md) | **Structure de la base de données du dossier patient selon FHIR** + mapping SQL |
| — | [Schéma SQL PostgreSQL](../database/hospicore_fhir_core.sql) | DDL complet : patients, observations, ordonnances, audit, RLS, FHIR JSONB |

### Partie III — Clients multi-plateformes (Windows · Android · Web)
| # | Document | Contenu |
|---|---|---|
| 05 | [Clients Windows / Android / Web — stratégie « tout en un »](./05-clients-windows-android-web.md) | Cibles OS, stack par plateforme, partage de code, packaging, offline |
| 06 | [Direction UI/UX — Windows 11 (Fluent Design)](./06-direction-ui-ux-windows-11-fluent.md) | Fenêtrage, interface, interactions, boutons, icônes, accessibilité, MSIX |
| 07 | [Direction UI/UX — Android moderne (Material You)](./07-direction-ui-ux-android-material-you.md) | Material 3, Jetpack Compose, adaptatif, accessibilité |
| 08 | [Portail patient Web (PWA)](./08-portail-patient-web-pwa.md) | React/TypeScript, responsive, WCAG 2.2 AA |

### Partie IV — Gouvernance, Qualité & Processus
| # | Document | Contenu |
|---|---|---|
| 09 | [Gouvernance & Sécurité (Garde-fou)](./09-gouvernance-securite-risques.md) | DPO, comité médical, CISO, gestion des risques majeurs |
| 10 | [Roadmap — Plan de développement par phases](./10-roadmap-phases-developpement.md) | Phases 1–4 (18–24 mois) |
| 11 | [Budget & Équipe](./11-budget-equipe-recrutement.md) | Équipe 15–20 personnes, coûts, recrutement CTO/DPO |
| 12 | [Catalogue des Skills (skills.sh) — Intégration DME & IA](./12-catalogue-skills-sh-integration.md) | **Tous les skills à intégrer** dans l'architecture DME et IA, avec commandes d'installation |
| 13 | [Standards de qualité & CI/CD](./13-standards-qualite-cicd.md) | Conventions de code, tests, sécurité, pipelines |
| 14 | [Prochaines étapes — Lancement](./14-prochaines-etapes-lancement.md) | Checklist de démarrage, partenaire pilote, prototype conformité |

### Partie V — Décisions d'architecture (ADR)
| # | Document |
|---|---|
| ADR-001 | [Adoption de FHIR R4 comme modèle canonique](./adr/ADR-001-adoption-fhir-r4-comme-modele-canonique.md) |
| ADR-002 | [Backend .NET / ASP.NET Core](./adr/ADR-002-backend-dotnet-aspnet-core.md) |
| ADR-003 | [Client Windows — WinUI 3 / Windows App SDK](./adr/ADR-003-client-windows-winui3-windows-app-sdk.md) |
| ADR-004 | [Client Android — Jetpack Compose / Material 3](./adr/ADR-004-client-android-jetpack-compose-material3.md) |
| ADR-005 | [Web — React PWA portail patient](./adr/ADR-005-web-react-pwa-portail.md) |
| ADR-006 | [PostgreSQL + JSONB comme stockage FHIR](./adr/ADR-006-postgresql-jsonb-comme-stockage-fhir.md) |
| ADR-007 | [Packaging Windows — MSIX](./adr/ADR-007-packaging-msix-windows.md) |
| ADR-008 | [Mode hors-ligne & synchronisation](./adr/ADR-008-mode-hors-ligne-et-synchronisation.md) |
| ADR-009 | [IA hors du flux critique](./adr/ADR-009-ia-hors-flux-critique.md) |

### Annexes
| # | Document |
|---|---|
| — | [Manifeste des skills (machine-readable)](../skills/skills-manifest.json) |
| — | [Guide d'installation des skills](../skills/README.md) |
| — | [README du schéma SQL](../database/README.md) |

---

## Cibles de plateformes (contrat)

| Plateforme | Version cible | Framework | Design system | Packaging |
|---|---|---|---|---|
| **Windows** | Windows 10 (2004 / 19041) **et plus récent**, Windows 11 | WinUI 3 / Windows App SDK (.NET 9) | **Fluent Design (Windows 11)** | **MSIX** (+ MSIX Core rétro-compat) |
| **Android** | Android moderne (Android 17 / API 37 cible ; minSdk 29) | Kotlin + Jetpack Compose | **Material You (Material 3)** | AAB (Play Store) + distribution interne (CHU/CHSLD) |
| **Web** | Navigateurs modernes (Evergreen) | React 19 + TypeScript (PWA) | Design system interne aligné Fluent/Material | PWA installable, portail patient |

## Modules fonctionnels obligatoires (rappel)

1. **Cœur clinique** : dossier patient unifié, notes SOAP, antécédents, allergies
2. **Flux administratif** : agenda multi-ressources, facturation (RAMQ + assurances), claims électroniques
3. **Soins & suivi** : plans de soins (infirmier), médication (MAR), vaccination
4. **Télésanté** : vidéo sécurisée, salle d'attente virtuelle, consentement numérique
5. **Logistique** : stock (médicaments, consommables), alertes de péremption
6. **Portail patient** : prise de RDV, résultats, messagerie sécurisée
7. **Intégration IoT** : tensiomètres, pompes, etc. via HL7/FHIR

---

> *« La confidentialité n'est pas une option, elle est intégrée à chaque ligne de code. »*
