# Database — Schéma PostgreSQL HospiCore (FHIR R4)

## Fichiers

- **`hospicore_fhir_core.sql`** — DDL complet du noyau de données (PostgreSQL 15+/16/17) : schémas, tables FHIR-aligned (Patient, Observation, Condition, AllergyIntolerance, MedicationRequest, MedicationAdministration, Immunization, Procedure, CarePlan, DocumentReference, Encounter, Appointment, Slot, Claim, Consent, AuditEvent, Device…), RLS (Row Level Security), triggers d'audit immuables chaînés (SHA-256), index, vues, rôles/permissions de base.

## Documentation

- **Modèle de données complet** : [`docs/04-modele-de-donnees-fhir.md`](../docs/04-modele-de-donnees-fhir.md)
- **Architecture** : [`docs/03-architecture-technique-complete.md`](../docs/03-architecture-technique-complete.md)

## Application (dev)

```bash
# 1. Créer la base
docker run --name hospicore-pg -e POSTGRES_PASSWORD=dev -p 5432:5432 -d postgres:16

# 2. Appliquer le schéma
psql -h localhost -U postgres -d postgres -v ON_ERROR_STOP=1 -f database/hospicore_fhir_core.sql

# 3. (Optionnel) Charger des données synthétiques (FHIR Synthea)
#    et les terminologies (LOINC, ICD-10-CA, SNOMED CT, RxNorm, CVX)
```

## Conventions clés

| Convention | Détail |
|---|---|
| Multi-tenant | `tenant_id` partout + **RLS** (contexte de session `app.current_tenant_id`) |
| PHI | colonnes `*_enc` chiffrées AES-256-GCM (applicatif, clés KMS/HSM) |
| FHIR | `fhir.resources` = magasin canonique JSONB ; UUID interne = `<Resource>.id` |
| Audit | `audit.audit_events` immuable, chaîné SHA-256, ≥ 6 ans (FHIR AuditEvent) |
| Consentement | `consent.consents` (FHIR Consent) — **Loi 25** |
| Migrations | Flyway / Liquibase / Sqitch (versionnées, jamais d'EDIT in place) |

## Sécurité

- Ne jamais exécuter de `UPDATE`/`DELETE` sur `audit.audit_events` (trigger d'immutabilité).
- Positionner le contexte de session à chaque connexion (backend) :
  `SELECT set_config('app.current_tenant_id', '<uuid>', false);`
- Données de test : **synthétiques uniquement** (Synthea) — jamais de PHI de production hors `prod`.
