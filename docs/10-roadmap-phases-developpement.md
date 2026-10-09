# 10 — Roadmap : Plan de Développement par Phases

> **Ne construisez pas tout en même temps.** Une approche par phases réduit les risques. Durée totale : **18–24 mois** jusqu'au déploiement massif.

---

## Phase 1 — Fondation & Conformité (Mois 1–6)

**Objectif** : un dossier patient **sécurisé et légal**.

| Livrable | Détail | Responsable |
|---|---|---|
| Architecture cloud sécurisée | K8s multi-AZ (région QC/CA), IaC (Terraform), GitOps | CTO/DevOps |
| Module authentification forte | Keycloak : MFA, RBAC/ABAC, SSO, fédération | Identity |
| Dossier patient de base | Créer/Lire/Mettre à jour (FHIR Patient), identifiants NAM/RAMQ | PatientCore |
| Modèle de données FHIR | Schéma PostgreSQL (`database/hospicore_fhir_core.sql`), magasin FHIR R4 | Data |
| Consentements (Loi 25) | FHIR Consent, révocation, preuves | PatientCore + DPO |
| Piste d'audit | AuditEvent immuable, chaîné, ≥ 6 ans | PatientCore |
| Client Windows (MVP) | WinUI 3 : login MFA, recherche patient, fiche patient | Windows |
| **Audit de sécurité initial (pen-test)** | Externe, bloquant avant pilote | CISO |
| Politiques de confidentialité (Loi 25) | Rédaction, EFVP, registre | DPO + juridique |

**Go/No-Go Phase 1** : pen-test sans critique ouvert, EFVP validée, DPO nommé, 100 % MFA.

## Phase 2 — Flux Clinique & Administratif (Mois 7–12)

**Objectif** : rendre la clinique **opérationnelle**.

| Livrable | Détail |
|---|---|
| Agenda & prise de RDV | FHIR Slot/Appointment, gestion des conflits, rappels SMS/courriel |
| Notes cliniques | Notes SOAP structurées (FHIR Composition/DocumentReference) |
| Observations & résultats | Signes vitaux, labos (LOINC), tendances, alertes valeurs critiques |
| Ordonnances & MAR | MedicationRequest (RxNorm), alertes allergies/interactions, MedicationAdministration (double validation) |
| Facturation | Intégration **RAMQ** + assureurs privés (FHIR Claim), soumission électronique |
| Portail patient (web PWA) | RDV, résultats, messagerie sécurisée, consentements |
| Client Android (MVP) | Compose : dossier, MAR (tablette soins), signes vitaux |
| Journalisation complète | « Qui a vu quoi ? » — audit interrogeable, export DPO |
| Alertes de péremption | Module logistique (lots, dates, FEFO) |

**Go/No-Go Phase 2** : clinique pilote (partenaire) opère 100 % sur HospiCore pendant 1 mois, 0 incident sécurité.

## Phase 3 — Avancé & Intégrations (Mois 13–18)

**Objectif** : **optimisation et connectivité**.

| Livrable | Détail |
|---|---|
| Module Télésanté | WebRTC chiffré (Windows/Android/Web), salle d'attente virtuelle, consentement d'enregistrement |
| Gestion de stock avancée | Inventaire, commandes auto, traçabilité lots, stupéfiants (conformité fédérale) |
| Intégration HL7 appareils | HL7 v2 (tensiomètres, pompes, glucomètres) + FHIR Device/Observation |
| **Connexion au DSQ** | Dossier Santé Québec (FHIR, profils CA, consentements) |
| Plans de soins infirmiers | FHIR CarePlan, protocoles CHSLD |
| Vaccination | FHIR Immunization (CVX), lots, rappels, registre vaccinal |
| Recherche clinique | OpenSearch (index dé-identifié/tokenisé), recherche notes/documents |
| Console admin web | Utilisateurs, rôles, audit, incidents |

**Go/No-Go Phase 3** : interop DSQ testée, télésanté validée par le comité médical, 2+ établissements pilotes.

## Phase 4 — Intelligence & Scale (Mois 19+)

**Objectif** : **innovation responsable**.

| Livrable | Détail |
|---|---|
| **Scribe IA** | Dictée vocale sécurisée (modèle on-prem QC), génération note SOAP structurée (FHIR), **révision humaine obligatoire** |
| Aide à la décision | Suggestions (interactions, dosages) — **hors flux critique** (ADR-009), explicabilité |
| Analytique prédictive | Santé populationnelle (dénominateurs agrégés, dé-identifiés), tableaux de bord |
| Certification complète | ISO 27001, SOC 2 Type II, HIPAA (si US), conformité Loi 25 attestée |
| Déploiement massif | CHU/CHSLD multi-sites, support 24/7, SLA 99,95 % |
| KMP / partage code | Factorisation logique métier (Kotlin Multiplatform) Android ↔ backend |

## 10.1 Jalons & critères de sortie (résumé)

| Jalon | Mois | Critère de sortie |
|---|---|---|
| M0 — Lancement | 0 | Équipe cœur (CTO, DPO, CISO), partenaire pilote signé, financement |
| M1 — Fondation sécurisée | 6 | Pen-test OK, dossier patient légal, 100 % MFA |
| M2 — Clinique opérationnelle | 12 | Pilote 1 mois en production, portail patient live |
| M3 — Connecté | 18 | DSQ, télésanté, IoT, 2+ établissements |
| M4 — Intelligent & certifié | 24 | Scribe IA, ISO 27001, déploiement massif |

## 10.2 Principes de livraison

- **Livraison continue** : déploiement plusieurs fois par semaine (feature flags pour les modules sensibles).
- **Beta avec partenaire pilote** : réduction de prix en échange de retours (crédits de cas).
- **Conformité avant fonctionnalité** : aucune fonctionnalité clinique sans EFVP/threat model à jour.
- **Comité médical** : revue à chaque jalon (ergonomie, alertes, sécurité patient).

*Voir aussi : [11 — Budget & équipe](./11-budget-equipe-recrutement.md), [14 — Prochaines étapes](./14-prochaines-etapes-lancement.md)*
