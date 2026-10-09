# ADR-006 — PostgreSQL + JSONB comme stockage FHIR

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, architecte données

## Contexte

Le modèle de données (chapitre 04) combine : (a) un **magasin canonique FHIR R4 (JSON)**, (b) des **tables relationnelles métier** (parcours cliniques, RLS, intégrité), (c) des documents binaires (S3). Il faut une technologie unique, opérable au Québec, conforme (résidence, chiffrement, audit).

## Décision

**PostgreSQL 16+** est la base de données principale :

- **`fhir.resources` (JSONB)** : magasin canonique FHIR R4, indexé (GIN `jsonb_path_ops` + index scalaires sur `patient_id`, `code`, `date`, `status`), partitionné par date (mensuel), versionné (`version_id`, `_history`).
- **Tables relationnelles** par domaine (clinical, scheduling, billing, inventory, consent, audit, identity, terminology, integration) — voir `database/hospicore_fhir_core.sql`.
- **RLS (Row Level Security)** : isolement tenant + rôle (défense en profondeur avec le RBAC applicatif).
- **Audit** : `audit.audit_events` immuable (trigger), chaîné SHA-256, partitionné.
- **Chiffrement** : TDE + chiffrement applicatif AES-256-GCM (colonnes `*_enc`), clés KMS/HSM.
- **Documents** : métadonnées + empreinte SHA-256 en PostgreSQL ; binaires en **S3 privé chiffré (région Canada, Object Lock)**.
- **MongoDB** en complément pour les notes cliniques non structurées et logs applicatifs.
- **Redis** : cache, sessions courtes, files de jobs, streams d'événements.

## Conséquences

- ✅ Un seul SGBD pour le transactionnel + le canonique FHIR (simplicité opérationnelle).
- ✅ RLS = sécurité en profondeur, conforme Loi 25/HIPAA.
- ✅ JSONB assez performant pour FHIR R4 à l'échelle CHU (avec indexation et partitionnement).
- ⚠️ Double écriture (relationnel + JSONB) — gérée par l'outbox transactionnel + contrôles de cohérence.
- ⚠️ Compétence PostgreSQL avancée requise (partitionnement, RLS, perf JSONB) — plan de formation équipe.

## Alternatives considérées

- **MongoDB seul pour FHIR** : flexible, mais transactions multi-documents, RLS et conformité enterprise inférieures — rejeté comme canonique.
- **SQL Server** : viable (écosystème Microsoft), mais coût de licences et résidence/portabilité QC moins favorables — rejeté.
- **CockroachDB / Yugabyte** : distribué natif, mais complexité opérationnelle pour v1 — réévalué en Phase 4 (scale multi-région).
