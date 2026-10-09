# 04 — Modèle de Données du Dossier Patient (FHIR R4)

> **Référence absolue** pour la couche persistance d'HospiCore. Toute équipe (backend, mobile, web, IA) doit se conformer à ce modèle.
> Le schéma SQL complet est dans [`database/hospicore_fhir_core.sql`](../database/hospicore_fhir_core.sql).

---

## 1. Philosophie : « FHIR d'abord, SQL ensuite »

HospiCore adopte une architecture **hybride canonique** :

| Couche | Rôle | Technologie |
|---|---|---|
| **Canonique FHIR R4** | Source de vérité interopérable (DSQ, HAPI FHIR, SMART on FHIR, échange inter-établissements) | `fhir.resources` (PostgreSQL **JSONB**) |
| **Relationnel métier** | Parcours cliniques rapides, RLS, contraintes d'intégrité, agrégats | Tables SQL dédiées par domaine |
| **Documentaire** | PDF, images, DICOM | S3 privé chiffré (résidence QC/CA) + métadonnées `clinical.documents` |
| **Cache** | Performance lecture | Redis (clés éphémères, jamais de PHI persistant) |

**Règle d'or** : toute écriture métier met à jour la table relationnelle **et** publie/met à jour la ressource FHIR dans `fhir.resources` (pattern *canonical store* + *outbox transactionnel* vers le bus d'événements).

---

## 2. Conventions générales

| Convention | Détail |
|---|---|
| **Identifiants** | UUID v4 (`gen_random_uuid()`). L'UUID interne **=** `<Resource>.id` FHIR. Jamais d'identifiant séquentiel exposé. |
| **Multi-tenant** | Colonne `tenant_id` sur **chaque** table + **RLS** (Row Level Security) PostgreSQL. |
| **PHI chiffré** | Colonnes `*_enc` = `bytea`, chiffrées **AES-256-GCM** au niveau applicatif (clé par tenant, HSM/KMS). + TDE disque. |
| **CodeableConcept** | Sérialisé en JSONB tel quel (FHIR) : `{"coding":[{"system":"...","code":"...","display":"..."}],"text":"..."}`. |
| **Références FHIR** | Stockées en JSONB `Reference` (`{"reference":"Patient/<uuid>","display":"..."}`) + colonne dénormalisée `*_id` quand utile pour les jointures/RLS. |
| **Dates** | `timestamptz` (UTC) ; FHIR `dateTime`/`instant` ; `date` pour `birthDate`. |
| **Soft delete** | `deleted_at` (patients) ; effacement réel via procédure d'anonymisation (Loi 25). |
| **Audit** | Trigger automatique → `audit.audit_events` (FHIR **AuditEvent**, chaîné par hash SHA-256, immuable). |
| **Versions** | `fhir.resources.version_id` incrémenté à chaque mise à jour ; anciennes versions conservées (FHIR `_history`). |

---

## 3. Dictionnaire des ressources FHIR R4 supportées (Phase 1–3)

| Ressource FHIR R4 | Table(s) SQL | Priorité | Cas d'usage HospiCore |
|---|---|---|---|
| **Patient** | `clinical.patients`, `clinical.patient_identifiers` | P0 | Dossier patient unifié, NAM, RAMQ |
| **Practitioner** | `identity.practitioners` | P0 | Médecins, infirmiers, pharmaciens |
| **PractitionerRole** | `identity.practitioners` + `identity.user_roles` | P1 | Rôles dans l'établissement |
| **Organization** | `identity.organizations` | P0 | CHU, cliniques, départements |
| **Location** | `identity.locations` | P1 | Salles, unités de soins, sites |
| **Encounter** | `clinical.encounters` | P0 | Consultations, visites, hospitalisations |
| **Condition** | `clinical.conditions` | P0 | Antécédents, problèmes, diagnostics (ICD-10-CA, SNOMED CT) |
| **AllergyIntolerance** | `clinical.allergies` | P0 | Allergies (critique pour la sécurité médicamenteuse) |
| **Observation** | `clinical.observations` | P0 | Signes vitaux, labos, scores (LOINC), IoT |
| **MedicationRequest** | `clinical.medication_requests` | P0 | Ordonnances (RxNorm) |
| **MedicationAdministration** | `clinical.medication_administrations` | P0 | MAR — administration infirmière |
| **Immunization** | `clinical.immunizations` | P1 | Vaccination (CVX), lots, péremption |
| **Procedure** | `clinical.procedures` | P1 | Actes (CCI), chirurgies |
| **CarePlan** | `clinical.care_plans`, `clinical.care_plan_activities` | P1 | Plans de soins infirmiers |
| **DocumentReference** | `clinical.documents` (+ S3) | P0 | Comptes rendus, résultats, consentements signés |
| **Appointment** | `scheduling.appointments` | P0 | RDV patient |
| **Slot** | `scheduling.slots` | P0 | Disponibilités ressources |
| **Claim** / **ClaimResponse** | `billing.claims`, `billing.claim_items` | P1 | Facturation RAMQ / assureurs |
| **Coverage** | (JSONB dans `billing.claims.insurance`) | P2 | Admissibilité RAMQ/assurance |
| **Consent** | `consent.consents` | P0 | **Loi 25** : consentement explicite, révocable, horodaté |
| **AuditEvent** | `audit.audit_events` | P0 | Piste d'audit immuable (qui a vu quoi, quand) |
| **Device** | `integration.devices` | P2 | Appareils IoT (tensiomètres, pompes) |
| **Medication** | `inventory.products` (mapping) | P2 | Formulaire médicamenteux |
| **Questionnaire / QuestionnaireResponse** | (Phase 3, JSONB) | P3 | Formulaires cliniques, scores (PHQ-9, GAD-7) |
| **Communication** | (Phase 3) | P3 | Messagerie sécurisée portail |
| **DiagnosticReport** | (vue agrégée sur `observations`) | P2 | Rapports de labo structurés |

---

## 4. Détail par ressource (champs obligatoires HospiCore)

### 4.1 Patient (`clinical.patients`)

| Élément FHIR | Colonne | Contrainte |
|---|---|---|
| `id` | `id` (PK) | UUID = id FHIR |
| `identifier[]` | `identifier` JSONB + `clinical.patient_identifiers` | **Obligatoire** : au moins NAM (Québec) ou RAMQ |
| `name[]` | `name` JSONB | Nom officiel ; `family_name_enc`/`given_name_enc` chiffrés |
| `telecom[]` | `telecom` JSONB | Téléphone/courriel (masqués côté portail) |
| `gender` | `gender` | `male\|female\|other\|unknown` |
| `birthDate` | `birth_date` | Obligatoire |
| `address[]` | `address` JSONB | Adresse postale (résidence) |
| `generalPractitioner[]` | `general_practitioner` JSONB | Médecin de famille |
| `managingOrganization` | `managing_org_id` | Établissement responsable |

**Recherche** : `identifier` (NAM/RAMQ), `name` (trigramme), `birthdate`, `family`, `given`.

### 4.2 Observation (`clinical.observations`)

| Élément FHIR | Colonne | Notes |
|---|---|---|
| `status` | `status` | `final` pour labos validés |
| `category` | `category` JSONB | `vital-signs`, `laboratory`, `imaging`, `survey`, `activity`, `therapy`, `social-history` |
| `code` | `code` JSONB | **LOINC** obligatoire (ex: `8867-4` FC, `8480-6` PAS, `8462-4` PAD, `2339-0` glycémie) |
| `effective[x]` | `effective` JSONB + `date` dénormalisé | Date de prélèvement/mesure |
| `value[x]` | `value` JSONB | Quantity/String/CodeableConcept/Boolean selon le type |
| `valueQuantity` | `value_uq` (numeric) + `value_unit` (UCUM) | Dénormalisé pour tendances/graphiques |
| `referenceRange[]` | `reference_range` JSONB | Bornes normales + interprétation |
| `interpretation[]` | `interpretation` JSONB | `N`, `L`, `H`, `HH`, `LL`, `A` (alerte) |
| `component[]` | `component` JSONB | Panels (ex: bilan lipidique) |
| `device` | `device_id` | Appareil IoT source (`integration.devices`) |

### 4.3 Condition (`clinical.conditions`)

| Élément FHIR | Colonne | Notes |
|---|---|---|
| `clinicalStatus` | `clinical_status` | `active\|recurrence\|relapse\|inactive\|remission\|resolved` |
| `code` | `code` JSONB | **ICD-10-CA** (diagnostic) ou **SNOMED CT** (problème) |
| `category[]` | `category` JSONB | `problem-list-item` (antécédent) ou `encounter-diagnosis` |
| `onset[x]` / `abatement[x]` | `onset` / `abatement` JSONB | Chronologie |
| `recordedDate` | `recorded_date` | |

### 4.4 AllergyIntolerance (`clinical.allergies`)

| Élément FHIR | Colonne | Notes |
|---|---|---|
| `criticality` | `criticality` | `high` = alerte bloquante dans la pres prescripion |
| `code` | `code` JSONB | RxNorm (médicament), SNOMED CT (substance/aliment) |
| `reaction[]` | `reaction` JSONB | `manifestation[]` (SNOMED), `severity`, `onset` |
| `category[]` | `category` | `food\|medication\|environment\|biologic` |

### 4.5 MedicationRequest (`clinical.medication_requests`)

| Élément FHIR | Colonne | Notes |
|---|---|---|
| `status` / `intent` | `status` / `intent` | `active` + `order` = ordonnance en vigueur |
| `medication[x]` | `medication` JSONB | RxNorm (DIN canadien via `inventory.products`) |
| `dosageInstruction[]` | `dosage_instruction` JSONB | Posologie, voie (SNOMED), fréquence (UCUM/`Timing`), durée |
| `requester` | `requester_id` | **Prescripteur** (audit + responsabilité légale) |
| `authoredOn` | `authored_on` | |
| `reasonCode[]` | `reason_code` JSONB | Lien diagnostic (Condition) |

**Sécurité médicamenteuse** : à la création, le système vérifie allergies actives + interactions (moteur de règles Phase 2, ML Phase 4).

### 4.6 MedicationAdministration (MAR)

| Élément | Colonne | Notes |
|---|---|---|
| `effectiveDateTime` | `effective` | Horodatage administration |
| `medication[x]` | `medication` | |
| `dosage` | `dosage` | Dose réellement administrée |
| `status` | `status` | `completed`, `not-done` (+ `statusReason`) |
| `performer[]` | `performer` | Infirmier(ère) — **preuve légale** |

### 4.7 Encounter (`clinical.encounters`)

| Élément | Colonne | Notes |
|---|---|---|
| `class` | `class` JSONB | `AMB` (ambulatoire), `EMER`, `IMP` (hospitalisation), `VR` (télésanté) |
| `type[]` | `type` | Type de visite (consultation, suivi, urgence) |
| `period` | `period` JSONB | Début/fin |
| `participant[]` | `participant` | Praticiens présents |
| `reasonCode[]` | `reason_code` | Motif de consultation |
| `diagnosis[]` | `diagnosis` | Lien Condition |

### 4.8 Appointment / Slot (`scheduling.*`)

| Ressource | Table | Spécificité |
|---|---|---|
| `Slot` | `scheduling.slots` | Disponibilité ressource (praticien/lieu), `start`/`end`, statut `free/busy` |
| `Appointment` | `scheduling.appointments` | RDV booké, `participant[]` (patient + praticien), rappels SMS/courriel |

**Contrainte** : un `Slot` `free` ne peut être booké que par transaction `SELECT ... FOR UPDATE` (pas de double booking).

### 4.9 Claim (`billing.claims`)

| Élément | Colonne | Notes |
|---|---|---|
| `insurer` | `insurer_id` → `billing.insurers` | RAMQ (code `RAMQ`) ou assureur privé |
| `type` | `type` | `institutional`, `oral`, `pharmacy`, `professional` |
| `item[]` | `billing.claim_items` | Actes (codes RAMQ/CCI), quantité, prix unitaire, net |
| `total` | `total` JSONB (Money) | |
| `insurance[]` | `insurance` JSONB | `Coverage` (no RAMQ, no police) |

### 4.10 Consent (`consent.consents`) — **Loi 25**

| Élément | Colonne | Notes |
|---|---|---|
| `status` | `status` | `active` / `rejected` / `inactive` (révoqué) |
| `scope` | `scope` | `patient-privacy` (traitement), `research`, `telehealth` |
| `category[]` | `category` | Type de consentement |
| `provision[]` | `provision` | Période de validité, finalités (`purpose`), classes de données (`data.class`) |
| `dateTime` | `date_time` | Horodatage du consentement |

**Règle** : aucun traitement de données de santé sans `Consent.status = 'active'` pour la finalité concernée. Révocation = `status → 'inactive'` + AuditEvent + arrêt des traitements associés.

### 4.11 AuditEvent (`audit.audit_events`) — piste immuable

| Élément FHIR | Colonne | Notes |
|---|---|---|
| `recorded` | `recorded_at` | |
| `type` / `subtype[]` | `event_type` / `event_subtype` | `rest` + opération FHIR |
| `action` | `event_action` | `C/R/U/D/E` |
| `outcome` | `event_outcome` | `0/4/8/12` |
| `agent[]` | `agent_user_id`, `agent_role`, `agent_ip` | **Qui** |
| `entity[]` | `resource_type`, `resource_id`, `patient_id` | **Quoi** |
| — (extension HospiCore) | `prev_hash`, `event_hash` | Chaînage SHA-256 (preuve d'intégrité) |

**Immuabilité** : trigger `BEFORE UPDATE OR DELETE → RAISE EXCEPTION`. Conservation ≥ 6 ans (HIPAA) / selon politique Loi 25 du tenant.

### 4.12 Device (`integration.devices`) — IoT

| Élément | Colonne | Notes |
|---|---|---|
| `identifier[]` (UDI) | `identifier` JSONB | Identifiant unique appareil |
| `type` | `type` JSONB | Tensiomètre, pompe à insuline, CGM... |
| `patient` | `patient_id` | Appareil assigné (ex: tensiomètre à domicile) |
| `udiCarrier` | `serial_number` | |

Les mesures reçues (HL7 v2 OBX ou FHIR Observation via API fabricant) créent des lignes `clinical.observations` avec `device_id` + `status='preliminary'` jusqu'à validation.

---

## 5. Terminologies canadiennes obligatoires

| Système | URI FHIR | Usage |
|---|---|---|
| **ICD-10-CA** | `http://hl7.org/fhir/sid/icd-10-cm` (adaptation CA) | Diagnostics, CIM-10 canadien |
| **CCI** | (CIHI) | Classification canadienne des actes (procédures) |
| **SNOMED CT** | `http://snomed.info/sct` (+ édition canadienne) | Problèmes cliniques, allergies, procédures |
| **LOINC** | `http://loinc.org` | Laboratoires, signes vitaux, documents |
| **RxNorm** | `http://www.nlm.nih.gov/research/umls/rxnorm` | Médicaments (ordonnances) |
| **CVX** | `http://hl7.org/fhir/sid/cvx` | Vaccins |
| **UCUM** | `http://unitsofmeasure.org` | Unités de mesure |
| **NAM / RAMQ** | `http://hl7.org/fhir/sid/ca-qc-nam`, `.../ca-qc-ramq` | Identifiants patients québécois |

Toutes les terminologies sont chargées dans `terminology.code_systems` / `terminology.concepts` (avec `display_fr` pour l'affichage français).

---

## 6. Flux d'écriture type (ex: saisie d'un signe vital)

```text
1. App (WinUI/Android/Web) → POST /fhir/Observation (JSON FHIR R4)
2. API Gateway → Service Dossier Patient (validation FHIR R4, profils CA)
3. Transaction PostgreSQL :
   a. INSERT INTO clinical.observations (...)
   b. INSERT INTO fhir.resources (resource_type='Observation', resource=...)  [canonique]
   c. Trigger audit → INSERT INTO audit.audit_events (hash chaîné)
   d. Outbox : événement Observation.created → bus (Redis Streams / Kafka)
4. Consommateurs : indexation recherche, alertes (valeur critique), FHIR push (DSQ si consenti)
5. Réponse 201 Created + OperationOutcome + Location: /fhir/Observation/<id>
```

---

## 7. Performance & indexation (grands volumes CHU)

| Mesure | Implémentation |
|---|---|
| Partitionnement | `fhir.resources` et `audit.audit_events` partitionnés par `RANGE (date)` (mensuel) |
| Index recherche | GIN `jsonb_path_ops` sur `resource`, index scalaires sur `patient_id`, `code`, `date`, `status` |
| Lecture rapide | Vues matérialisées pour tableaux de bord (signes vitaux récents, alertes) |
| Cache | Redis : Patient summary, LOINC fréquents, sessions — TTL court, invalidation par événement |
| Archivage | Données > rétention → schéma `archive` (chiffré, lecture seule) + purge S3 |
| Connexion | Pool PgBouncer (transaction), max 200 connexions par nœud API |

---

## 8. Conformité du modèle

| Exigence | Où |
|---|---|
| Loi 25 — consentement | `consent.consents` + `Consent.status='active'` requis avant traitement |
| Loi 25 — minimisation | Champs `*_enc` chiffrés ; pas de PHI dans `audit.audit_events.description` |
| Loi 25 — droit d'accès/effacement | Procédure d'export patient (Bundle FHIR) + procédure d'anonymisation |
| HIPAA — audit | `audit.audit_events` immuable, chaîné, ≥ 6 ans |
| HIPAA — accès unique | `identity.users.external_id` (IdP), MFA obligatoire (`mfa_enrolled`) |
| FHIR R4 | `fhir.resources` canonique + profils canadiens (CA Core) |
| DSQ | Connecteur FHIR dédié (Phase 3) : push/pull Consent, Observation, MedicationRequest |

---

*Voir aussi : [03 — Architecture technique](./03-architecture-technique-complete.md), [09 — Gouvernance & sécurité](./09-gouvernance-securite-risques.md), [12 — Skills FHIR](./12-catalogue-skills-sh-integration.md)*
