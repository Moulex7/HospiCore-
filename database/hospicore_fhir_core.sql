-- ============================================================================
-- HOSPICORE — SCHÉMA PostgreSQL NOYAU (Dossier Médical Électronique)
-- Alignement : HL7 FHIR R4 (modèle canonique) + Loi 25 (QC) + HIPAA + ISO 27001
-- Version : 1.1.0 | Date : 2026-10-09
-- Cible : PostgreSQL 15+ (compatible 16/17)
--
-- PRINCIPES DE CONCEPTION
--   1. Multi-tenant strict : chaque table porte tenant_id + RLS (Row Level Security).
--   2. Privacy by Design : champs sensibles chiffrés (bytea, AES-256-GCM applicatif,
--      clés via HSM/KMS), jamais de PHI en clair dans les logs.
--   3. FHIR R4 : table canonique fhir.resources (JSONB) + tables relationnelles
--      pour les requêtes métier/performance. Mapping documenté dans
--      docs/04-modele-de-donnees-fhir.md.
--   4. Auditabilité : table audit.audit_events immuable, chaînée par hash
--      (FHIR AuditEvent), déclenchée automatiquement (trigger).
--   5. Conformité Loi 25 : consentements explicites tracés, effacement supporté,
--      rétention configurable par tenant.
--
-- NOTE : script d'installation initiale (idempotent). Les évolutions de schéma
--        sont gérées ensuite par migrations versionnées (Flyway/Liquibase/Sqitch).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 0. EXTENSIONS
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;      -- gen_random_uuid(), digest()
CREATE EXTENSION IF NOT EXISTS pg_trgm;       -- recherche floue (noms patients)
CREATE EXTENSION IF NOT EXISTS btree_gin;     -- index GIN sur colonnes scalaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";   -- uuid_generate_v4() (compat)
CREATE EXTENSION IF NOT EXISTS citext;        -- courriel insensible à la casse

-- ----------------------------------------------------------------------------
-- 1. SCHÉMAS (bounded contexts DDD)
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS core;         -- tenants, configuration
CREATE SCHEMA IF NOT EXISTS identity;     -- utilisateurs, rôles, RBAC, organisations
CREATE SCHEMA IF NOT EXISTS clinical;     -- dossier patient (FHIR clinical)
CREATE SCHEMA IF NOT EXISTS scheduling;   -- agenda, rendez-vous (FHIR Appointment/Slot)
CREATE SCHEMA IF NOT EXISTS billing;      -- facturation RAMQ/assureurs (FHIR Claim)
CREATE SCHEMA IF NOT EXISTS inventory;    -- stock médicaments/consommables
CREATE SCHEMA IF NOT EXISTS consent;      -- consentements (FHIR Consent, Loi 25)
CREATE SCHEMA IF NOT EXISTS audit;        -- piste d'audit immuable (FHIR AuditEvent)
CREATE SCHEMA IF NOT EXISTS fhir;         -- magasin canonique de ressources FHIR R4
CREATE SCHEMA IF NOT EXISTS terminology;  -- ICD-10, SNOMED CT, LOINC, RxNorm
CREATE SCHEMA IF NOT EXISTS integration;  -- IoT, appareils médicaux, HL7

-- ----------------------------------------------------------------------------
-- 2. FONCTIONS UTILITAIRES : CONTEXTE APPLICATIF (RLS) & AUDIT
-- ----------------------------------------------------------------------------

-- Contexte de session positionné par le backend à chaque connexion :
--   SELECT set_config('app.current_tenant_id', '<uuid>', false);
--   SELECT set_config('app.current_user_id',   '<uuid>', false);
--   SELECT set_config('app.current_role',      '<role>', false);
--   SELECT set_config('app.current_patient_id','<uuid>', false); -- rôle PATIENT

CREATE OR REPLACE FUNCTION core.current_tenant_id()
RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT NULLIF(current_setting('app.current_tenant_id', true), '')::uuid $$;

CREATE OR REPLACE FUNCTION core.current_user_id()
RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT NULLIF(current_setting('app.current_user_id', true), '')::uuid $$;

CREATE OR REPLACE FUNCTION core.current_role()
RETURNS text LANGUAGE sql STABLE AS
$$ SELECT NULLIF(current_setting('app.current_role', true), '') $$;

CREATE OR REPLACE FUNCTION core.current_patient_id()
RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT NULLIF(current_setting('app.current_patient_id', true), '')::uuid $$;

-- Table d'audit FHIR AuditEvent (immuable, chaînée par hash)
CREATE TABLE IF NOT EXISTS audit.audit_events (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id       uuid,
    event_id        uuid        NOT NULL DEFAULT gen_random_uuid(), -- AuditEvent.id
    recorded_at     timestamptz NOT NULL DEFAULT now(),             -- AuditEvent.recorded
    event_type      text        NOT NULL,   -- ex: 'rest', 'fhir'
    event_subtype   text,                   -- ex: 'create','read','update','delete','execute'
    event_action    char(1),                -- C=create R=read U=update D=delete E=execute
    event_outcome   smallint    NOT NULL DEFAULT 0, -- 0=success 4=minor failure 8=serious 12=major
    agent_user_id   uuid,                   -- qui
    agent_role      text,                   -- rôle au moment du fait
    agent_ip        inet,                   -- d'où (masqué partiellement en prod)
    source_site     text,                   -- système source
    resource_type   text,                   -- ex: Patient, Observation
    resource_id     text,                   -- id FHIR ou UUID interne
    patient_id      uuid,                   -- patient concerné (si applicable)
    description     text,                   -- description lisible (SANS PHI)
    outcome_desc    text,
    prev_hash       text,                   -- chaînage : hash de l'événement précédent
    event_hash      text        NOT NULL,   -- sha256 canonique de l'événement
    meta            jsonb       NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_audit_events_tenant_time
    ON audit.audit_events (tenant_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_patient
    ON audit.audit_events (patient_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_resource
    ON audit.audit_events (resource_type, resource_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_agent
    ON audit.audit_events (agent_user_id, recorded_at DESC);

-- Immutabilité (niveau trigger) : aucun UPDATE/DELETE possible
CREATE OR REPLACE FUNCTION audit.trg_audit_immutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'audit.audit_events est immuable (Loi 25 / HIPAA : conservation 6 ans min.)';
END $$;

DROP TRIGGER IF EXISTS audit_immutable ON audit.audit_events;
CREATE TRIGGER audit_immutable
    BEFORE UPDATE OR DELETE ON audit.audit_events
    FOR EACH ROW EXECUTE FUNCTION audit.trg_audit_immutable();

-- Immutabilité (niveau privilèges) : le public ne peut ni modifier ni supprimer
REVOKE ALL ON audit.audit_events FROM PUBLIC;

-- Chaînage par hash + peuplement automatique
CREATE OR REPLACE FUNCTION audit.fn_chain_and_write()
RETURNS trigger LANGUAGE plpgsql AS
$$
DECLARE
    v_prev    text;
    v_hash    text;
    v_payload text;
BEGIN
    SELECT event_hash INTO v_prev
      FROM audit.audit_events
     WHERE tenant_id IS NOT DISTINCT FROM NEW.tenant_id
     ORDER BY id DESC LIMIT 1;

    v_payload := concat_ws('|',
        COALESCE(NEW.event_id::text,''), COALESCE(NEW.recorded_at::text,''),
        COALESCE(NEW.event_type,''), COALESCE(NEW.event_subtype,''),
        COALESCE(NEW.event_action,''), NEW.event_outcome::text,
        COALESCE(NEW.agent_user_id::text,''), COALESCE(NEW.resource_type,''),
        COALESCE(NEW.resource_id,''), COALESCE(NEW.patient_id::text,''),
        COALESCE(v_prev,''));
    v_hash := encode(digest(v_payload, 'sha256'), 'hex');

    NEW.prev_hash  := v_prev;
    NEW.event_hash := v_hash;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS audit_chain ON audit.audit_events;
CREATE TRIGGER audit_chain
    BEFORE INSERT ON audit.audit_events
    FOR EACH ROW EXECUTE FUNCTION audit.fn_chain_and_write();

-- Trigger générique : écrit un AuditEvent à chaque CUD sur les tables cliniques.
--   TG_ARGV[0] = type de ressource FHIR logique (ex: 'Observation')
--   TG_ARGV[1] = nom de la colonne portant l'id patient (défaut 'patient_id';
--                pour la table patients elle-même : 'id')
-- SECURITY DEFINER : les rôles applicatifs peuvent écrire l'audit sans pouvoir
-- le modifier (les triggers UPDATE/DELETE restent bloqués pour tous).
CREATE OR REPLACE FUNCTION audit.fn_write_audit_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path = audit, core, pg_temp AS
$$
DECLARE
    v_action      char(1);
    v_res_type    text;
    v_res_id      text;
    v_patient     uuid;
    v_patient_col text := COALESCE(TG_ARGV[1], 'patient_id');
    v_row         jsonb;
    v_tenant      uuid;
BEGIN
    v_res_type := TG_ARGV[0];

    IF TG_OP = 'DELETE' THEN
        v_action := 'D';
        v_res_id := OLD.id::text;
        v_row    := to_jsonb(OLD);
    ELSIF TG_OP = 'INSERT' THEN
        v_action := 'C';
        v_res_id := NEW.id::text;
        v_row    := to_jsonb(NEW);
    ELSE
        v_action := 'U';
        v_res_id := NEW.id::text;
        v_row    := to_jsonb(NEW);
    END IF;

    -- Extraction du patient_id si la colonne existe sur la table
    IF v_row ? v_patient_col AND v_row->>v_patient_col IS NOT NULL THEN
        v_patient := (v_row->>v_patient_col)::uuid;
    END IF;

    v_tenant := COALESCE(core.current_tenant_id(), (v_row->>'tenant_id')::uuid);

    INSERT INTO audit.audit_events (
        tenant_id, event_type, event_subtype, event_action, event_outcome,
        agent_user_id, agent_role, resource_type, resource_id, patient_id,
        description, meta
    ) VALUES (
        v_tenant,
        'rest', TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, v_action, 0,
        core.current_user_id(),
        core.current_role(),
        v_res_type, v_res_id, v_patient,
        format('%s %s %s', v_action, v_res_type, v_res_id),
        jsonb_build_object('table', TG_TABLE_NAME, 'schema', TG_TABLE_SCHEMA)
    );
    RETURN COALESCE(NEW, OLD);
END $$;

-- ----------------------------------------------------------------------------
-- 3. CORE : TENANTS (établissements) & PARAMÉTRAGE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS core.tenants (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code            text NOT NULL UNIQUE,          -- ex: CHU-MTL-01
    name            text NOT NULL,                 -- raison sociale
    type            text NOT NULL CHECK (type IN
                       ('CHU','CHSLD','CLINIQUE','GMF','POLYCLINIQUE','AUTRE')),
    address         jsonb,
    settings        jsonb NOT NULL DEFAULT '{}'::jsonb,  -- rétention, features, etc.
    ramq_id         text,                          -- identifiant RAMQ (si applicable)
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- 4. IDENTITY : RBAC, UTILISATEURS, PRATICIENS, ORGANISATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identity.roles (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   uuid REFERENCES core.tenants(id),
    code        text NOT NULL,                    -- MEDECIN, INFIRMIER, ADMIN, PATIENT...
    name        text NOT NULL,
    description text,
    is_system   boolean NOT NULL DEFAULT false,   -- rôles système non supprimables
    UNIQUE (tenant_id, code)
);

CREATE TABLE IF NOT EXISTS identity.permissions (
    id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code    text NOT NULL UNIQUE,                 -- ex: patient:read, med:prescribe
    name    text NOT NULL,
    domain  text NOT NULL                         -- patient, agenda, facturation, admin...
);

CREATE TABLE IF NOT EXISTS identity.role_permissions (
    role_id       uuid REFERENCES identity.roles(id) ON DELETE CASCADE,
    permission_id uuid REFERENCES identity.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- Comptes applicatifs (staff) — mot de passe JAMAIS stocké ici (Keycloak/Auth0 externe)
CREATE TABLE IF NOT EXISTS identity.users (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    external_id     text,                         -- sub du IdP (Keycloak/Auth0)
    email           citext UNIQUE,
    display_name    text NOT NULL,
    practitioner_id uuid,                         -- lien FHIR Practitioner
    active          boolean NOT NULL DEFAULT true,
    mfa_enrolled    boolean NOT NULL DEFAULT false, -- obligatoire avant 1er accès clinique
    last_login_at   timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_users_tenant ON identity.users (tenant_id);

CREATE TABLE IF NOT EXISTS identity.user_roles (
    user_id uuid REFERENCES identity.users(id) ON DELETE CASCADE,
    role_id uuid REFERENCES identity.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- FHIR Practitioner (praticien de santé)
CREATE TABLE IF NOT EXISTS identity.practitioners (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),  -- == Practitioner.id
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    user_id         uuid REFERENCES identity.users(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,  -- Practitioner.identifier (ex: no ordre)
    name            jsonb NOT NULL,                    -- HumanName FHIR
    telecom         jsonb NOT NULL DEFAULT '[]'::jsonb,-- ContactPoint[]
    specialty       jsonb NOT NULL DEFAULT '[]'::jsonb,-- codes (ex: SNOMED)
    organization_id uuid,
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_practitioners_tenant ON identity.practitioners (tenant_id);

-- FHIR Organization / Location (structure, sites)
CREATE TABLE IF NOT EXISTS identity.organizations (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),  -- == Organization.id
    tenant_id  uuid NOT NULL REFERENCES core.tenants(id),
    identifier jsonb NOT NULL DEFAULT '[]'::jsonb,
    name       text NOT NULL,
    type       jsonb NOT NULL DEFAULT '[]'::jsonb,   -- codes FHIR (prov, dept...)
    telecom    jsonb NOT NULL DEFAULT '[]'::jsonb,
    address    jsonb NOT NULL DEFAULT '[]'::jsonb,
    active     boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS identity.locations (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(), -- == Location.id
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    organization_id uuid REFERENCES identity.organizations(id),
    name            text NOT NULL,
    mode            text NOT NULL DEFAULT 'instance' CHECK (mode IN ('instance','kind')),
    type            jsonb NOT NULL DEFAULT '[]'::jsonb,
    telecom         jsonb NOT NULL DEFAULT '[]'::jsonb,
    address         jsonb,
    managing_org    uuid REFERENCES identity.organizations(id),
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_locations_org ON identity.locations (organization_id);

-- Clés étrangères tardives (idempotentes)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_practitioner') THEN
        ALTER TABLE identity.users ADD CONSTRAINT fk_users_practitioner
            FOREIGN KEY (practitioner_id) REFERENCES identity.practitioners(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_pract_org') THEN
        ALTER TABLE identity.practitioners ADD CONSTRAINT fk_pract_org
            FOREIGN KEY (organization_id) REFERENCES identity.organizations(id);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 5. CLINICAL : DOSSIER PATIENT (cœur FHIR R4)
--    Conventions :
--      * id            = UUID interne = <Resource>.id (FHIR)
--      * *_enc         = bytea chiffré AES-256-GCM (applicatif) — PHI au repos
--      * code_*        = jsonb CodeableConcept FHIR sérialisé
--      * patient_id    = FK vers clinical.patients (dénormalisé pour RLS/perf)
-- ----------------------------------------------------------------------------

-- FHIR Patient
CREATE TABLE IF NOT EXISTS clinical.patients (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(), -- Patient.id
    tenant_id           uuid NOT NULL REFERENCES core.tenants(id),
    identifier          jsonb NOT NULL DEFAULT '[]'::jsonb,  -- Patient.identifier[] (NAM, RAMQ, MR)
    active              boolean NOT NULL DEFAULT true,
    name                jsonb NOT NULL DEFAULT '[]'::jsonb,   -- HumanName[] FHIR
    telecom             jsonb NOT NULL DEFAULT '[]'::jsonb,   -- ContactPoint[]
    gender              text CHECK (gender IN ('male','female','other','unknown')),
    birth_date          date,                                 -- Patient.birthDate
    deceased            jsonb,                                -- deceasedBoolean | deceasedDateTime
    address             jsonb NOT NULL DEFAULT '[]'::jsonb,
    marital_status      jsonb,
    photo_uri           text,                                 -- référence S3 chiffré (jamais d'URL publique)
    general_practitioner jsonb NOT NULL DEFAULT '[]'::jsonb,   -- Reference(Practitioner|Organization)[]
    managing_org_id     uuid REFERENCES identity.organizations(id),
    -- Champs sensibles chiffrés au repos (AES-256-GCM, clé HSM/KMS, tenant-scoped)
    given_name_enc      bytea,      -- prénoms (partie de HumanName.given)
    family_name_enc     bytea,      -- nom de famille
    notes_enc           bytea,      -- notes administratives sensibles
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    deleted_at          timestamptz        -- soft delete (Loi 25 -> procédure d'anonymisation)
);
CREATE INDEX IF NOT EXISTS idx_patients_tenant       ON clinical.patients (tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_patients_birthdate    ON clinical.patients (birth_date);
CREATE INDEX IF NOT EXISTS idx_patients_name_trgm    ON clinical.patients USING gin ((name::text) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_patients_identifier   ON clinical.patients USING gin (identifier);

-- Identifiants structurés (recherche rapide : NAM, RAMQ, no dossier interne)
CREATE TABLE IF NOT EXISTS clinical.patient_identifiers (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id  uuid NOT NULL REFERENCES clinical.patients(id) ON DELETE CASCADE,
    tenant_id   uuid NOT NULL,
    system      text NOT NULL,     -- URI du système (ex: http://hl7.org/fhir/sid/ca-qc-ramq)
    value       text NOT NULL,     -- valeur (index de recherche)
    value_enc   bytea,             -- valeur chiffrée si sensible
    type_code   text,              -- usuel | officiel | temporaire (FHIR identifier.type)
    use         text DEFAULT 'usual' CHECK (use IN ('usual','official','temp','secondary','old')),
    period      jsonb,
    active      boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_patient_identifier
    ON clinical.patient_identifiers (tenant_id, system, value) WHERE active;
CREATE INDEX IF NOT EXISTS idx_patient_ids_patient ON clinical.patient_identifiers (patient_id);

-- FHIR AllergyIntolerance
CREATE TABLE IF NOT EXISTS clinical.allergies (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    clinical_status jsonb,
    verification_status jsonb,
    type            text CHECK (type IN ('allergy','intolerance')),
    category        text[],                         -- food | medication | environment | biologic
    criticality     text CHECK (criticality IN ('low','high','unable-to-assess')),
    code            jsonb NOT NULL,                 -- CodeableConcept (RxNorm / SNOMED / aliment)
    recorder_id     uuid REFERENCES identity.practitioners(id),
    onset           jsonb,                          -- onsetDateTime | onsetAge | onsetString
    recorded_date   timestamptz,
    last_occurrence timestamptz,
    reaction        jsonb NOT NULL DEFAULT '[]'::jsonb, -- AllergyIntolerance.reaction[]
    note_enc        bytea,
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_allergies_patient ON clinical.allergies (patient_id) WHERE active;
CREATE INDEX IF NOT EXISTS idx_allergies_code    ON clinical.allergies USING gin (code);

-- FHIR Condition (antécédents, problèmes, diagnostics)
CREATE TABLE IF NOT EXISTS clinical.conditions (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           uuid NOT NULL REFERENCES core.tenants(id),
    patient_id          uuid NOT NULL REFERENCES clinical.patients(id),
    identifier          jsonb NOT NULL DEFAULT '[]'::jsonb,
    clinical_status     jsonb,
    verification_status jsonb,
    category            jsonb NOT NULL DEFAULT '[]'::jsonb,  -- problem-list-item | encounter-diagnosis
    severity            jsonb,
    code                jsonb NOT NULL,                       -- CodeableConcept (ICD-10-CA / SNOMED)
    body_site           jsonb NOT NULL DEFAULT '[]'::jsonb,
    subject_ref         jsonb,                                -- Reference(Patient) — canonique
    encounter_id        uuid,
    onset               jsonb,
    abatement           jsonb,
    recorded_date       timestamptz,
    recorder_id         uuid REFERENCES identity.practitioners(id),
    asserter_id         uuid REFERENCES identity.practitioners(id),
    stage               jsonb NOT NULL DEFAULT '[]'::jsonb,
    evidence            jsonb NOT NULL DEFAULT '[]'::jsonb,
    note_enc            bytea,
    active              boolean NOT NULL DEFAULT true,       -- false = résolu/inactif
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_conditions_patient ON clinical.conditions (patient_id) WHERE active;
CREATE INDEX IF NOT EXISTS idx_conditions_code    ON clinical.conditions USING gin (code);

-- FHIR Observation (signes vitaux, laboratoires, scores cliniques)
CREATE TABLE IF NOT EXISTS clinical.observations (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN
                       ('registered','preliminary','final','amended','corrected','cancelled','entered-in-error','unknown')),
    category        jsonb NOT NULL DEFAULT '[]'::jsonb,
    code            jsonb NOT NULL,                 -- CodeableConcept (LOINC le plus souvent)
    subject_ref     jsonb,
    encounter_id    uuid,
    effective       jsonb,                          -- effectiveDateTime | effectivePeriod
    issued          timestamptz,
    performer       jsonb NOT NULL DEFAULT '[]'::jsonb,-- Reference(Practitioner|...)[]
    value           jsonb,                          -- valueQuantity | valueCodeableConcept | valueString | valueBoolean...
    value_uq        numeric,                        -- valeur numérique dénormalisée (perf)
    value_unit      text,                           -- unité UCUM
    data_absent_reason jsonb,
    interpretation  jsonb NOT NULL DEFAULT '[]'::jsonb,
    note_enc        bytea,
    body_site       jsonb,
    method          jsonb,
    reference_range jsonb NOT NULL DEFAULT '[]'::jsonb,
    has_member      jsonb NOT NULL DEFAULT '[]'::jsonb,  -- Reference(Observation)[] (panels)
    derived_from    jsonb NOT NULL DEFAULT '[]'::jsonb,
    component       jsonb NOT NULL DEFAULT '[]'::jsonb, -- Observation.component[]
    device_id       uuid,                           -- appareil IoT source
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_obs_patient      ON clinical.observations (patient_id, (effective->>'dateTime'));
CREATE INDEX IF NOT EXISTS idx_obs_code         ON clinical.observations USING gin (code);
CREATE INDEX IF NOT EXISTS idx_obs_value        ON clinical.observations (value_uq) WHERE value_uq IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_obs_status       ON clinical.observations (patient_id, status);

-- FHIR Encounter (consultations, visites, hospitalisations)
CREATE TABLE IF NOT EXISTS clinical.encounters (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN
                       ('planned','arrived','triaged','in-progress','onleave','finished','cancelled',
                        'entered-in-error','unknown')),
    class           jsonb NOT NULL,               -- CodeableConcept (AMB, EMER, IMP, VR...)
    type            jsonb NOT NULL DEFAULT '[]'::jsonb,
    service_type    jsonb,
    priority        jsonb,
    subject_ref     jsonb,
    participant     jsonb NOT NULL DEFAULT '[]'::jsonb, -- Encounter.participant[]
    appointment     jsonb NOT NULL DEFAULT '[]'::jsonb, -- Reference(Appointment)[]
    period          jsonb NOT NULL,               -- Encounter.period
    length          jsonb,
    reason_code     jsonb NOT NULL DEFAULT '[]'::jsonb,
    diagnosis       jsonb NOT NULL DEFAULT '[]'::jsonb, -- Encounter.diagnosis[]
    account         jsonb NOT NULL DEFAULT '[]'::jsonb,
    hospitalization jsonb,
    location        jsonb NOT NULL DEFAULT '[]'::jsonb, -- Encounter.location[]
    service_provider uuid REFERENCES identity.organizations(id),
    part_of         jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_encounters_patient ON clinical.encounters (patient_id);
CREATE INDEX IF NOT EXISTS idx_encounters_period  ON clinical.encounters USING gin (period);
CREATE INDEX IF NOT EXISTS idx_encounters_status  ON clinical.encounters (patient_id, status);

-- Clés étrangères vers Encounter (idempotentes)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_cond_encounter') THEN
        ALTER TABLE clinical.conditions ADD CONSTRAINT fk_cond_encounter
            FOREIGN KEY (encounter_id) REFERENCES clinical.encounters(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_obs_encounter') THEN
        ALTER TABLE clinical.observations ADD CONSTRAINT fk_obs_encounter
            FOREIGN KEY (encounter_id) REFERENCES clinical.encounters(id);
    END IF;
END $$;

-- FHIR MedicationRequest (ordonnances)
CREATE TABLE IF NOT EXISTS clinical.medication_requests (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           uuid NOT NULL REFERENCES core.tenants(id),
    patient_id          uuid NOT NULL REFERENCES clinical.patients(id),
    identifier          jsonb NOT NULL DEFAULT '[]'::jsonb,
    status              text NOT NULL CHECK (status IN
                           ('active','on-hold','cancelled','completed','entered-in-error','stopped','draft','unknown')),
    intent              text NOT NULL CHECK (intent IN
                           ('proposal','plan','order','original-order','reflex-order','filler-order','instance-order','option')),
    category            jsonb NOT NULL DEFAULT '[]'::jsonb,
    priority            text CHECK (priority IN ('routine','urgent','asap','stat')),
    do_not_perform      boolean,
    medication          jsonb NOT NULL,               -- CodeableConcept | Reference(Medication) (RxNorm)
    subject_ref         jsonb,
    encounter_id        uuid REFERENCES clinical.encounters(id),
    supporting_info     jsonb NOT NULL DEFAULT '[]'::jsonb,
    authored_on         timestamptz,
    requester_id        uuid REFERENCES identity.practitioners(id),
    performer           jsonb,
    recorder_id         uuid REFERENCES identity.practitioners(id),
    reason_code         jsonb NOT NULL DEFAULT '[]'::jsonb,
    based_on            jsonb NOT NULL DEFAULT '[]'::jsonb,
    group_identifier    jsonb,
    course_of_therapy   jsonb,
    insurance           jsonb NOT NULL DEFAULT '[]'::jsonb,
    note_enc            bytea,
    dosage_instruction  jsonb NOT NULL DEFAULT '[]'::jsonb, -- Dosage[] (posologie, voie, fréquence)
    dispense_request    jsonb,
    substitution        jsonb,
    prior_prescription  jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_medreq_patient ON clinical.medication_requests (patient_id);
CREATE INDEX IF NOT EXISTS idx_medreq_status  ON clinical.medication_requests (patient_id, status);
CREATE INDEX IF NOT EXISTS idx_medreq_med     ON clinical.medication_requests USING gin (medication);

-- MAR : MedicationAdministration (administration réelle — soins infirmiers)
CREATE TABLE IF NOT EXISTS clinical.medication_administrations (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           uuid NOT NULL REFERENCES core.tenants(id),
    patient_id          uuid NOT NULL REFERENCES clinical.patients(id),
    request_id          uuid REFERENCES clinical.medication_requests(id),
    status              text NOT NULL CHECK (status IN
                           ('in-progress','not-done','on-hold','completed','entered-in-error','stopped','unknown')),
    medication          jsonb NOT NULL,
    subject_ref         jsonb,
    context_id          uuid REFERENCES clinical.encounters(id),
    effective           timestamptz NOT NULL,         -- date/heure d'administration
    performer           jsonb NOT NULL DEFAULT '[]'::jsonb,
    reason_code         jsonb NOT NULL DEFAULT '[]'::jsonb,
    dosage              jsonb,
    note_enc            bytea,
    created_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_medadmin_patient ON clinical.medication_administrations (patient_id, effective DESC);
CREATE INDEX IF NOT EXISTS idx_medadmin_request ON clinical.medication_administrations (request_id);

-- FHIR Immunization (vaccination)
CREATE TABLE IF NOT EXISTS clinical.immunizations (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN ('completed','entered-in-error','not-done')),
    status_reason   jsonb,
    vaccine_code    jsonb NOT NULL,                 -- CodeableConcept (CVX)
    patient_ref     jsonb,
    encounter_id    uuid REFERENCES clinical.encounters(id),
    occurrence      jsonb NOT NULL,                 -- occurrenceDateTime | occurrenceString
    recorded        timestamptz,
    primary_source  boolean,
    report_origin   jsonb,
    location        jsonb,
    manufacturer    jsonb,
    lot_number      text,
    expiration_date date,
    site            jsonb,
    route           jsonb,
    dose_quantity   jsonb,
    performer       jsonb NOT NULL DEFAULT '[]'::jsonb,
    note_enc        bytea,
    protocol_applied jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_immun_patient ON clinical.immunizations (patient_id);
CREATE INDEX IF NOT EXISTS idx_immun_vaccine ON clinical.immunizations USING gin (vaccine_code);
CREATE INDEX IF NOT EXISTS idx_immun_lot     ON clinical.immunizations (lot_number);

-- FHIR Procedure (actes, chirurgies, soins)
CREATE TABLE IF NOT EXISTS clinical.procedures (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN
                       ('preparation','in-progress','not-done','on-hold','stopped','completed',
                        'entered-in-error','unknown')),
    status_reason   jsonb,
    category        jsonb,
    code            jsonb NOT NULL,                 -- CodeableConcept (CCI au Canada / SNOMED)
    subject_ref     jsonb,
    encounter_id    uuid REFERENCES clinical.encounters(id),
    performed       jsonb NOT NULL,                 -- performedDateTime | performedPeriod
    recorder_id     uuid REFERENCES identity.practitioners(id),
    asserter_id     uuid REFERENCES identity.practitioners(id),
    performer       jsonb NOT NULL DEFAULT '[]'::jsonb,
    location        jsonb,
    reason_code     jsonb NOT NULL DEFAULT '[]'::jsonb,
    body_site       jsonb NOT NULL DEFAULT '[]'::jsonb,
    outcome         jsonb,
    report          jsonb NOT NULL DEFAULT '[]'::jsonb,
    complication    jsonb NOT NULL DEFAULT '[]'::jsonb,
    follow_up       jsonb NOT NULL DEFAULT '[]'::jsonb,
    note_enc        bytea,
    focal_device    jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_procedures_patient ON clinical.procedures (patient_id);
CREATE INDEX IF NOT EXISTS idx_procedures_code    ON clinical.procedures USING gin (code);

-- FHIR CarePlan (plans de soins infirmiers) + activités
CREATE TABLE IF NOT EXISTS clinical.care_plans (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN
                       ('draft','active','on-hold','revoked','completed','entered-in-error','unknown')),
    intent          text NOT NULL CHECK (intent IN ('proposal','plan','order','option')),
    category        jsonb NOT NULL DEFAULT '[]'::jsonb,
    title           text,
    description_enc bytea,
    subject_ref     jsonb NOT NULL,
    encounter_id    uuid REFERENCES clinical.encounters(id),
    period          jsonb,
    created_at_time timestamptz,
    author_id       uuid REFERENCES identity.practitioners(id),
    contributor     jsonb NOT NULL DEFAULT '[]'::jsonb,
    addresses       jsonb NOT NULL DEFAULT '[]'::jsonb, -- Reference(Condition|...)[]
    goal            jsonb NOT NULL DEFAULT '[]'::jsonb, -- Reference(Goal)[]
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS clinical.care_plan_activities (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL,
    care_plan_id    uuid NOT NULL REFERENCES clinical.care_plans(id) ON DELETE CASCADE,
    status          text NOT NULL CHECK (status IN
                       ('not-started','scheduled','in-progress','on-hold','completed','cancelled','stopped','unknown','entered-in-error')),
    description_enc bytea,
    scheduled       jsonb,
    performer       jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_careplans_patient ON clinical.care_plans (patient_id);
CREATE INDEX IF NOT EXISTS idx_careplan_act_plan ON clinical.care_plan_activities (care_plan_id);

-- FHIR DocumentReference (documents cliniques : PDF, images, comptes rendus)
-- Le binaire est dans S3 privé chiffré ; ici les métadonnées + empreinte.
CREATE TABLE IF NOT EXISTS clinical.documents (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN ('current','superseded','entered-in-error')),
    type            jsonb NOT NULL,                 -- CodeableConcept (LOINC document types)
    category        jsonb NOT NULL DEFAULT '[]'::jsonb,
    subject_ref     jsonb,
    date            timestamptz,
    author          jsonb NOT NULL DEFAULT '[]'::jsonb,
    authenticator   jsonb,
    description     text,
    security_label  jsonb NOT NULL DEFAULT '[]'::jsonb,
    content         jsonb NOT NULL DEFAULT '[]'::jsonb, -- DocumentReference.content[] (attachment)
    context         jsonb,
    s3_bucket       text NOT NULL,                  -- bucket privé (résidence QC/CA)
    s3_key          text NOT NULL,                  -- clé objet
    s3_version_id   text,
    sha256          text NOT NULL,                  -- empreinte d'intégrité
    size_bytes      bigint,
    content_type    text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_documents_patient ON clinical.documents (patient_id);
CREATE INDEX IF NOT EXISTS idx_documents_type    ON clinical.documents USING gin (type);
CREATE INDEX IF NOT EXISTS idx_documents_sha     ON clinical.documents (sha256);

-- ----------------------------------------------------------------------------
-- 6. SCHEDULING : FHIR Slot / Appointment (agenda multi-ressources)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scheduling.slots (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    service_type    jsonb NOT NULL DEFAULT '[]'::jsonb,
    specialty       jsonb NOT NULL DEFAULT '[]'::jsonb,
    practitioner_id uuid REFERENCES identity.practitioners(id),
    location_id     uuid REFERENCES identity.locations(id),
    start           timestamptz NOT NULL,
    "end"           timestamptz NOT NULL,          -- « end » est un mot réservé PostgreSQL -> quoté
    status          text NOT NULL CHECK (status IN ('busy','free','busy-unavailable','busy-tentative','entered-in-error')),
    overbooked      boolean NOT NULL DEFAULT false,
    comment         text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK ("end" > start)
);
CREATE INDEX IF NOT EXISTS idx_slots_tenant_time ON scheduling.slots (tenant_id, start, "end");
CREATE INDEX IF NOT EXISTS idx_slots_pract       ON scheduling.slots (practitioner_id, start);
CREATE INDEX IF NOT EXISTS idx_slots_location    ON scheduling.slots (location_id, start);

CREATE TABLE IF NOT EXISTS scheduling.appointments (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(), -- Appointment.id
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN
                       ('proposed','pending','booked','arrived','fulfilled','cancelled','noshow',
                        'entered-in-error','checked-in','waitlist')),
    service_type    jsonb NOT NULL DEFAULT '[]'::jsonb,
    specialty       jsonb NOT NULL DEFAULT '[]'::jsonb,
    appointment_type jsonb,
    reason_code     jsonb NOT NULL DEFAULT '[]'::jsonb,
    priority        integer,
    description     text,
    start           timestamptz NOT NULL,
    "end"           timestamptz NOT NULL,          -- « end » est un mot réservé PostgreSQL -> quoté
    minutes_duration integer,
    slot            jsonb NOT NULL DEFAULT '[]'::jsonb,  -- Reference(Slot)[]
    created_at_time timestamptz NOT NULL DEFAULT now(),
    comment         text,
    patient_instruction text,
    based_on        jsonb NOT NULL DEFAULT '[]'::jsonb,
    participant     jsonb NOT NULL DEFAULT '[]'::jsonb, -- Appointment.participant[]
    requested_period jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CHECK ("end" > start)
);
CREATE INDEX IF NOT EXISTS idx_appt_tenant_time ON scheduling.appointments (tenant_id, start);
CREATE INDEX IF NOT EXISTS idx_appt_patient     ON scheduling.appointments (patient_id, start DESC);
CREATE INDEX IF NOT EXISTS idx_appt_status      ON scheduling.appointments (tenant_id, status, start);

-- ----------------------------------------------------------------------------
-- 7. BILLING : FHIR Claim / Invoice (RAMQ + assureurs privés)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS billing.insurers (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id  uuid NOT NULL REFERENCES core.tenants(id),
    code       text NOT NULL,              -- RAMQ, SSQ, assureur privé...
    name       text NOT NULL,
    type       text NOT NULL CHECK (type IN ('RAMQ','PRIVATE','OTHER')),
    endpoint   text,                       -- URL soumission claims (sécurisée, mTLS)
    active     boolean NOT NULL DEFAULT true,
    UNIQUE (tenant_id, code)
);

CREATE TABLE IF NOT EXISTS billing.claims (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(), -- Claim.id
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    encounter_id    uuid REFERENCES clinical.encounters(id),
    insurer_id      uuid NOT NULL REFERENCES billing.insurers(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN
                       ('active','cancelled','draft','entered-in-error','balanced','pending','submitted','paid','denied','rejected')),
    type            jsonb NOT NULL,         -- CodeableConcept (institutional|oral|pharmacy...)
    use             text NOT NULL DEFAULT 'claim' CHECK (use IN ('claim','preauthorization','predetermination')),
    patient_ref     jsonb NOT NULL,
    created_at_time timestamptz NOT NULL DEFAULT now(),
    billable_period jsonb,
    provider_id     uuid REFERENCES identity.practitioners(id),
    priority        jsonb,
    insurance       jsonb NOT NULL DEFAULT '[]'::jsonb,
    total           jsonb,                  -- Money
    submitted_at    timestamptz,
    response_code   text,                   -- code réponse RAMQ/assureur
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS billing.claim_items (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL,
    claim_id        uuid NOT NULL REFERENCES billing.claims(id) ON DELETE CASCADE,
    sequence        integer NOT NULL,
    product_code    jsonb NOT NULL,         -- code acte (RAMQ / CCI)
    quantity        jsonb,
    unit_price      jsonb,
    net             jsonb,
    encounter_id    uuid REFERENCES clinical.encounters(id),
    procedure_id    uuid REFERENCES clinical.procedures(id),
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_claims_patient ON billing.claims (patient_id);
CREATE INDEX IF NOT EXISTS idx_claims_status  ON billing.claims (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_claim_items_claim ON billing.claim_items (claim_id);

-- ----------------------------------------------------------------------------
-- 8. INVENTORY : médicaments & consommables (alertes de péremption)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory.products (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    code            text,                       -- DIN (Drug Identification Number) canadien
    name            text NOT NULL,
    form            text,                       -- comprimé, liquide, injectable...
    strength        text,
    manufacturer    text,
    category        text NOT NULL CHECK (category IN ('medication','supply','vaccine','device')),
    atc_code        text,
    rxnorm_code     text,
    controlled      boolean NOT NULL DEFAULT false,  -- stupéfiants (traçabilité stricte)
    active          boolean NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_products_tenant ON inventory.products (tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_din    ON inventory.products (code);

CREATE TABLE IF NOT EXISTS inventory.lots (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL,
    product_id      uuid NOT NULL REFERENCES inventory.products(id),
    lot_number      text NOT NULL,
    expiration_date date NOT NULL,
    received_date   date,
    quantity_on_hand numeric NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    unit            text,
    location_id     uuid REFERENCES identity.locations(id),
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, product_id, lot_number)
);
CREATE INDEX IF NOT EXISTS idx_lots_expiry  ON inventory.lots (expiration_date);
CREATE INDEX IF NOT EXISTS idx_lots_product ON inventory.lots (product_id);

CREATE TABLE IF NOT EXISTS inventory.stock_movements (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id   uuid NOT NULL,
    lot_id      uuid NOT NULL REFERENCES inventory.lots(id),
    patient_id  uuid REFERENCES clinical.patients(id),  -- sortie vers patient
    movement    text NOT NULL CHECK (movement IN ('in','out','adjustment','transfer','waste')),
    quantity    numeric NOT NULL,
    reference   text,                          -- no ordonnance, no commande
    performed_by uuid REFERENCES identity.users(id),
    occurred_at timestamptz NOT NULL DEFAULT now(),
    note        text
);
CREATE INDEX IF NOT EXISTS idx_stock_mov_lot ON inventory.stock_movements (lot_id, occurred_at DESC);

-- ----------------------------------------------------------------------------
-- 9. CONSENT : FHIR Consent (Loi 25 — consentement explicite & révocable)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS consent.consents (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(), -- Consent.id
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid NOT NULL REFERENCES clinical.patients(id),
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,
    status          text NOT NULL CHECK (status IN ('draft','proposed','active','rejected','inactive','entered-in-error')),
    scope           jsonb NOT NULL,                 -- Consent.scope (patient-privacy | research...)
    category        jsonb NOT NULL DEFAULT '[]'::jsonb,
    patient_ref     jsonb NOT NULL,
    date_time       timestamptz,
    performer       jsonb NOT NULL DEFAULT '[]'::jsonb,
    organization    jsonb NOT NULL DEFAULT '[]'::jsonb,
    source_attachment jsonb,
    policy_rule     jsonb,
    provision       jsonb NOT NULL DEFAULT '[]'::jsonb, -- Consent.provision[] (period, purpose, class)
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_consents_patient ON consent.consents (patient_id, status);

-- ----------------------------------------------------------------------------
-- 10. TERMINOLOGY : ICD-10-CA, SNOMED CT, LOINC, RxNorm, CVX (référentiels)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS terminology.code_systems (
    id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    uri     text NOT NULL UNIQUE,       -- ex: http://hl7.org/fhir/sid/icd-10-cm
    name IQUE,       -- ex: http://hl7.org/fhir/sid/icd-10-cm
    name    text NOT NULL,
    version text,
    active  boolean NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS terminology.concepts (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id       uuid NOT NULL REFERENCES terminology.code_systems(id),
    code            text NOT NULL,
    display         text NOT NULL,
    display_fr      text,                   -- traduction française (SNOMED CT FR, ICD-10-CA)
    properties      jsonb NOT NULL DEFAULT '{}'::jsonb,
    active          boolean NOT NULL DEFAULT true,
    UNIQUE (system_id, code)
);
CREATE INDEX IF NOT EXISTS idx_concepts_system_code ON terminology.concepts (system_id, code);
CREATE INDEX IF NOT EXISTS idx_concepts_display_trgm ON terminology.concepts USING gin (display gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- 11. FHIR : MAGASIN CANONIQUE DE RESSOURCES (R4, JSONB)
--     Source de vérité pour l'interopérabilité (DSQ, HAPI FHIR, SMART on FHIR).
--     Les tables relationnelles ci-dessus servent les parcours métier rapides ;
--     toute écriture métier publie la ressource FHIR ici (pattern « canonical store »).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fhir.resources (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id       uuid NOT NULL,
    resource_type   text NOT NULL,                  -- Patient, Observation, Claim...
    resource_id     uuid NOT NULL,                  -- <Resource>.id (UUID)
    version_id      integer NOT NULL DEFAULT 1,     -- Resource.meta.versionId
    is_current      boolean NOT NULL DEFAULT true,
    last_updated    timestamptz NOT NULL DEFAULT now(),  -- Resource.meta.lastUpdated
    resource        jsonb NOT NULL,                 -- ressource FHIR R4 complète
    -- Paramètres de recherche indexés (dénormalisés pour perf)
    patient_id      uuid,                           -- _patient / subject
    status          text,
    code            text,                           -- token code principal (LOINC/RxNorm/ICD)
    date            timestamptz,                    -- _date / effective
    created_at      timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, resource_type, resource_id, version_id)
);
CREATE INDEX IF NOT EXISTS idx_fhir_res_current
    ON fhir.resources (tenant_id, resource_type, resource_id) WHERE is_current;
CREATE INDEX IF NOT EXISTS idx_fhir_res_patient
    ON fhir.resources (tenant_id, resource_type, patient_id) WHERE is_current;
CREATE INDEX IF NOT EXISTS idx_fhir_res_code
    ON fhir.resources (tenant_id, resource_type, code) WHERE is_current;
CREATE INDEX IF NOT EXISTS idx_fhir_res_date
    ON fhir.resources (tenant_id, resource_type, date) WHERE is_current;
CREATE INDEX IF NOT EXISTS idx_fhir_res_json
    ON fhir.resources USING gin (resource jsonb_path_ops);

-- Historique de versions (FHIR _history) : on conserve les versions supersédées
CREATE INDEX IF NOT EXISTS idx_fhir_res_history
    ON fhir.resources (tenant_id, resource_type, resource_id, version_id DESC);

-- Table de correspondance table relationnelle <-> ressource FHIR
CREATE TABLE IF NOT EXISTS fhir.resource_links (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id       uuid NOT NULL,
    resource_type   text NOT NULL,
    resource_id     uuid NOT NULL,                  -- id de la ressource FHIR
    table_schema    text NOT NULL,                  -- ex: 'clinical'
    table_name      text NOT NULL,                  -- ex: 'observations'
    row_id          uuid NOT NULL,                  -- PK de la ligne métier
    synced_at       timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, table_schema, table_name, row_id)
);

-- ----------------------------------------------------------------------------
-- 12. INTEGRATION : IoT / appareils médicaux (HL7 FHIR Observation)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS integration.devices (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       uuid NOT NULL REFERENCES core.tenants(id),
    patient_id      uuid REFERENCES clinical.patients(id),   -- appareil assigné à un patient
    identifier      jsonb NOT NULL DEFAULT '[]'::jsonb,      -- UDI (Unique Device Identifier)
    type            jsonb NOT NULL,                         -- CodeableConcept (tensiomètre, pompe...)
    manufacturer    text,
    model           text,
    serial_number   text,
    status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','entered-in-error','unknown')),
    location_id     uuid REFERENCES identity.locations(id),
    hl7_endpoint    text,                                 -- endpoint HL7 v2 / FHIR du fabricant
    last_seen_at    timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_devices_patient ON integration.devices (patient_id);
CREATE INDEX IF NOT EXISTS idx_devices_serial  ON integration.devices (serial_number);

-- ----------------------------------------------------------------------------
-- 13. ROW LEVEL SECURITY (RLS) — isolement tenant + rôle PATIENT
--     Le backend positionne app.current_tenant_id / app.current_role à la connexion.
--     Logique par table (politiques permissives, une seule par table) :
--       * rôle PATIENT        -> uniquement SON dossier (patient_id = app.current_patient_id)
--       * autres rôles staff  -> leur tenant (SUPERADMIN/AUDITOR voient tous les tenants)
--     Les fonctions de politique appartiennent au propriétaire des tables (pas de
--     contournement de privilèges).
-- ----------------------------------------------------------------------------
ALTER TABLE core.tenants               ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.users             ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.practitioners     ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.organizations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE identity.locations         ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.patients          ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.allergies         ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.conditions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.observations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.encounters        ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.medication_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.medication_administrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.immunizations     ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.procedures        ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.care_plans        ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical.documents         ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduling.slots           ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduling.appointments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing.claims             ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent.consents           ENABLE ROW LEVEL SECURITY;
ALTER TABLE fhir.resources             ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration.devices        ENABLE ROW LEVEL SECURITY;

-- Même tenant (staff uniquement ; SUPERADMIN/AUDITOR : tous tenants)
CREATE OR REPLACE FUNCTION core.rls_same_tenant(tenant_col uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT tenant_col = core.current_tenant_id()
        OR core.current_role() IN ('SUPERADMIN','AUDITOR');
$$;

-- Le rôle PATIENT ne voit que son propre dossier
CREATE OR REPLACE FUNCTION core.rls_is_self(patient_col uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
    SELECT patient_col IS NOT NULL
       AND patient_col = core.current_patient_id();
$$;

-- Politiques : tables cliniques avec patient_id
DROP POLICY IF EXISTS tenant_isolation ON clinical.patients;
CREATE POLICY tenant_isolation ON clinical.patients
    USING ( core.rls_is_self(id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.allergies;
CREATE POLICY tenant_isolation ON clinical.allergies
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.conditions;
CREATE POLICY tenant_isolation ON clinical.conditions
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.observations;
CREATE POLICY tenant_isolation ON clinical.observations
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.encounters;
CREATE POLICY tenant_isolation ON clinical.encounters
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.medication_requests;
CREATE POLICY tenant_isolation ON clinical.medication_requests
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.medication_administrations;
CREATE POLICY tenant_isolation ON clinical.medication_administrations
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.immunizations;
CREATE POLICY tenant_isolation ON clinical.immunizations
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.procedures;
CREATE POLICY tenant_isolation ON clinical.procedures
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.care_plans;
CREATE POLICY tenant_isolation ON clinical.care_plans
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON clinical.documents;
CREATE POLICY tenant_isolation ON clinical.documents
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON scheduling.appointments;
CREATE POLICY tenant_isolation ON scheduling.appointments
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON billing.claims;
CREATE POLICY tenant_isolation ON billing.claims
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON consent.consents;
CREATE POLICY tenant_isolation ON consent.consents
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

DROP POLICY IF EXISTS tenant_isolation ON fhir.resources;
CREATE POLICY tenant_isolation ON fhir.resources
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

-- Politiques : tables sans patient_id (staff uniquement, hors rôle PATIENT)
DROP POLICY IF EXISTS tenant_isolation ON identity.users;
CREATE POLICY tenant_isolation ON identity.users
    USING (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id));

DROP POLICY IF EXISTS tenant_isolation ON identity.practitioners;
CREATE POLICY tenant_isolation ON identity.practitioners
    USING (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id));

DROP POLICY IF EXISTS tenant_isolation ON identity.organizations;
CREATE POLICY tenant_isolation ON identity.organizations
    USING (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id));

DROP POLICY IF EXISTS tenant_isolation ON identity.locations;
CREATE POLICY tenant_isolation ON identity.locations
    USING (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id));

DROP POLICY IF EXISTS tenant_isolation ON scheduling.slots;
CREATE POLICY tenant_isolation ON scheduling.slots
    USING (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id));

DROP POLICY IF EXISTS tenant_isolation ON integration.devices;
CREATE POLICY tenant_isolation ON integration.devices
    USING ( core.rls_is_self(patient_id)
         OR (core.current_role() IS DISTINCT FROM 'PATIENT' AND core.rls_same_tenant(tenant_id)) );

-- ----------------------------------------------------------------------------
-- 14. TRIGGERS D'AUDIT AUTOMATIQUE (FHIR AuditEvent) SUR TABLES CLINIQUES
--     Le 2e argument = nom de la colonne patient (pour patients : 'id').
-- ----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_patients ON clinical.patients;
CREATE TRIGGER trg_audit_patients AFTER INSERT OR UPDATE OR DELETE ON clinical.patients
    FOR EACH ROW EXECUTE FUNCTION audit.fn_write_audit_event('Patient', 'id');

DROP TRIGGER IF EXISTS trg_audit_observations ON clinical.observations;
CREATE TRIGGER trg_audit_observations AFTER INSERT OR UPDATE OR DELETE ON clinical.observations
    FOR EACH ROW EXECUTE FUNCTION audit.fn_write_audit_event('Observation');

DROP TRIGGER IF EXISTS trg_audit_conditions ON clinical.conditions;
CREATE TRIGGER trg_audit_conditions AFTER INSERT OR UPDATE OR DELETE ON clinical.conditions
    FOR EACH ROW EXECUTE FUNCTION audit.fn_write_audit_event('Condition');

DROP TRIGGER IF EXISTS trg_audit_medreq ON clinical.medication_requests;
CREATE TRIGGER trg_audit_medreq AFTER INSERT OR UPDATE OR DELETE ON clinical.medication_requests
    FOR EACH ROW EXECUTE FUNCTION audit.fn_write_audit_event('MedicationRequest');

DROP TRIGGER IF EXISTS trg_audit_encounters ON clinical.encounters;
CREATE TRIGGER trg_audit_encounters AFTER INSERT OR UPDATE OR DELETE ON clinical.encounters
    FOR EACH ROW EXECUTE FUNCTION audit.fn_write_audit_event('Encounter');

DROP TRIGGER IF EXISTS trg_audit_documents ON clinical.documents;
CREATE TRIGGER trg_audit_documents AFTER INSERT OR UPDATE OR DELETE ON clinical.documents
    FOR EACH ROW EXECUTE FUNCTION audit.fn_write_audit_event('DocumentReference');

DROP TRIGGER IF EXISTS trg_audit_consents ON consent.consents;
CREATE TRIGGER trg_audit_consents AFTER INSERT OR UPDATE OR DELETE ON consent.consents
    FOR EACH ROW EXECUTE FUNCTION audit.fn_write_audit_event('Consent');

-- ----------------------------------------------------------------------------
-- 15. VUES MÉTIER UTILES (exemples)
-- ----------------------------------------------------------------------------

-- Résumé patient (FHIR Patient + infos clés) — sans PHI chiffré
CREATE OR REPLACE VIEW clinical.v_patient_summary AS
SELECT p.id, p.tenant_id, p.identifier, p.name, p.gender, p.birth_date,
       p.active, p.created_at,
       (SELECT count(*) FROM clinical.allergies a
         WHERE a.patient_id = p.id AND a.active) AS allergy_count,
       (SELECT count(*) FROM clinical.conditions c
         WHERE c.patient_id = p.id AND c.active) AS active_condition_count,
       (SELECT max(o.effective->>'dateTime')
          FROM clinical.observations o WHERE o.patient_id = p.id) AS last_observation_at
  FROM clinical.patients p
 WHERE p.deleted_at IS NULL;

-- Alertes de péremption (90 jours) pour le module logistique
CREATE OR REPLACE VIEW inventory.v_expiring_lots AS
SELECT l.id, l.tenant_id, l.product_id, p.name AS product_name, p.code AS din,
       l.lot_number, l.expiration_date, l.quantity_on_hand,
       (l.expiration_date - CURRENT_DATE) AS days_to_expiry
  FROM inventory.lots l
  JOIN inventory.products p ON p.id = l.product_id
 WHERE l.expiration_date <= CURRENT_DATE + INTERVAL '90 days'
   AND l.quantity_on_hand > 0
 ORDER BY l.expiration_date;

-- ----------------------------------------------------------------------------
-- 16. DONNÉES DE RÉFÉRENCE : rôles système & permissions de base (RBAC)
-- ----------------------------------------------------------------------------
INSERT INTO identity.permissions (code, name, domain) VALUES
    ('patient:read',        'Lire le dossier patient',                 'clinical'),
    ('patient:write',       'Modifier le dossier patient',             'clinical'),
    ('patient:create',      'Créer un dossier patient',                'clinical'),
    ('observation:write',   'Saisir des observations (signes vitaux)', 'clinical'),
    ('medication:prescribe','Prescrire (ordonnances)',                 'clinical'),
    ('medication:administer','Administrer des médicaments (MAR)',      'clinical'),
    ('appointment:manage',  'Gérer l''agenda et les rendez-vous',      'scheduling'),
    ('billing:submit',      'Soumettre des réclamations RAMQ/assureurs','billing'),
    ('inventory:manage',    'Gérer les stocks et lots',                'inventory'),
    ('telehealth:host',     'Animer une consultation vidéo',           'telehealth'),
    ('admin:users',         'Gérer les utilisateurs et rôles',         'admin'),
    ('audit:read',          'Consulter la piste d''audit',             'admin')
ON CONFLICT (code) DO NOTHING;

INSERT INTO identity.roles (tenant_id, code, name, description, is_system) VALUES
    (NULL, 'MEDECIN',        'Médecin',                      'Prescription, notes, ordonnances', true),
    (NULL, 'INFIRMIER',      'Infirmier(ère)',               'Soins, MAR, plans de soins, observations', true),
    (NULL, 'RECEPTIONNISTE', 'Réceptionniste',               'Agenda, accueil, prise de RDV', true),
    (NULL, 'PHARMACIEN',     'Pharmacien(ne)',               'Validation pharmaceutique, inventaire', true),
    (NULL, 'ADMIN_ETAB',     'Administrateur établissement', 'Gestion utilisateurs, configuration', true),
    (NULL, 'PATIENT',        'Patient (portail)',            'Consultation de son propre dossier', true),
    (NULL, 'AUDITOR',        'Auditeur',                     'Lecture seule, piste d''audit', true)
ON CONFLICT (tenant_id, code) DO NOTHING;

COMMIT;

-- ============================================================================
-- NOTES D'EXPLOITATION
--   * Appliquer : psql -v ON_ERROR_STOP=1 -f hospicore_fhir_core.sql
--   * Rôles applicatifs (créés par l'infrastructure, hors script) :
--       CREATE ROLE hospicore_app LOGIN;        -- backend (INSERT/SELECT/UPDATE)
--       CREATE ROLE hospicore_readonly LOGIN;   -- reporting (SELECT, hors PHI chiffrée)
--   * Migrations ultérieures : Flyway / Liquibase / Sqitch (versionnées).
--   * Chiffrement au repos : chiffrement applicatif AES-256-GCM (colonnes *_enc)
--     + chiffrement disque (TDE) + clés HSM/KMS. Jamais de clés en BDD.
--   * Rétention Loi 25 : 6 ans minimum pour la piste d'audit (HIPAA), configurable
--     par tenant dans core.tenants.settings->>'retention'.
--   * Effacement (droit à l'oubli) : procédure stockée d'anonymisation par patient
--     (à écrire en Phase 1) — pseudonymisation irréversible + purge S3 + audit.
--   * Partitionnement (Phase 2, à l'échelle CHU) : fhir.resources et
--     audit.audit_events partitionnés par RANGE sur la date (mensuel).
-- ============================================================================
