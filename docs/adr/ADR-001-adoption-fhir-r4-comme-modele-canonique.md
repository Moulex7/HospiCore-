# ADR-001 — Adoption de HL7 FHIR R4 comme modèle canonique

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, architecte logiciel, comité médical

## Contexte

HospiCore doit échanger des données avec le **DSQ (Dossier Santé Québec)**, les laboratoires, les assureurs (RAMQ) et les appareils médicaux (HL7 v2). Un modèle propriétaire fermerait l'écosystème ; un modèle trop générique ralentirait les parcours cliniques.

## Décision

**HL7 FHIR R4 est le modèle canonique et obligatoire** d'HospiCore :

1. Toute ressource clinique est représentée et stockée comme ressource **FHIR R4** (magasin JSONB `fhir.resources`).
2. Les API publiques sont des **API FHIR R4** (HAPI FHIR), avec profils canadiens (CA Core / Infoway).
3. Les tables relationnelles (chapitre 04) servent les parcours métier/performance ; elles publient systématiquement la ressource FHIR (canonical store + outbox).
4. **SMART on FHIR** pour l'autorisation (OAuth 2.0 scopes) et le lancement d'apps.
5. HL7 v2 reste supporté **en périphérie** (appareils legacy) via un service d'ingestion dédié.

## Conséquences

- ✅ Interopérabilité native (DSQ, labos, assureurs, éditeurs tiers).
- ✅ Portail patient standardisé (apps SMART on FHIR compatibles).
- ✅ Réduction du risque réglementaire (standard pancanadien).
- ⚠️ Courbe d'apprentissage FHIR (profils, terminologies) — mitigée par les skills (chapitre 12) et HAPI FHIR.
- ⚠️ Double écriture (relationnel + JSONB) — mitigée par l'outbox transactionnel et les vues de cohérence.

## Alternatives considérées

- **OpenEMR (EHR open source)** : accélère le démarrage, mais modèle propriétaire/legacy, interop limitée — rejeté comme base, envisageable comme accélérateur de prototype.
- **Modèle propriétaire interne** : contrôle total, mais écosystème fermé, non conforme DSQ — rejeté.
- **FHIR R5** : trop récent, écosystème canadien encore R4 — R4 retenu, migration R5 évaluée en Phase 4.
