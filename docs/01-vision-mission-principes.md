# 01 — Vision, Mission & Principes Fondamentaux

## 1.1 Vision

> **HospiCore** centralise les soins, sécurise les données et optimise les flux cliniques pour les grandes structures de santé du Québec : **CHU, CHSLD, cliniques multidisciplinaires**.

Un seul dossier patient, une seule vérité clinique, accessible sur **Windows (10/11), Android et Web**, conforme dès le premier jour.

## 1.2 Mission

1. **Centraliser** le dossier médical électronique (DME) dans un noyau clinique unifié, interopérable (HL7 FHIR R4).
2. **Sécuriser** les renseignements personnels de santé comme un actif critique national (Loi 25, HIPAA, ISO 27001).
3. **Optimiser** les flux cliniques et administratifs (agenda, facturation RAMQ/assureurs, logistique, télésanté).
4. **Outiller** les soignants (notes SOAP, MAR, plans de soins) et **autonomiser** les patients (portail, RDV, résultats).
5. **Intégrer** l'IA de façon **responsable** (scribe, aide à la décision) — **jamais sur le flux critique**.

## 1.3 Principes fondamentaux (non négociables)

| # | Principe | Signification concrète |
|---|---|---|
| P1 | **Privacy by Design** | La confidentialité est intégrée à chaque ligne de code, chaque schéma, chaque écran. Pas de « rustine » a posteriori. |
| P2 | **Souveraineté des données** | Toutes les données sensibles résident **physiquement au Québec/Canada** (Loi 25). Aucun traitement IA externe de PHI non dé-identifiée. |
| P3 | **Sécurité par défaut** | Chiffrement AES-256 au repos, TLS 1.3 en transit, MFA obligatoire, moindre privilège (RBAC), audit de tout accès. |
| P4 | **Interopérabilité ouverte** | HL7 **FHIR R4** obligatoire comme modèle canonique ; HL7 v2 pour les appareils legacy ; connexion DSQ (Dossier Santé Québec). |
| P5 | **Précision clinique** | Validation par un **comité médical** ; alertes de sécurité médicamenteuse ; l'humain reste responsable de la décision clinique. |
| P6 | **Résilience** | Multi-AZ, mode dégradé/hors-ligne, RTO < 15 min, RPO < 5 min. Un DME indisponible met des vies en danger. |
| P7 | **Accessibilité** | WCAG 2.2 AA sur toutes les plateformes (soignants et patients en situation de handicap). |
| P8 | **Traçabilité totale** | Qui a vu quoi, quand, pourquoi — piste d'audit immuable (FHIR AuditEvent), conservée ≥ 6 ans. |
| P9 | **Un produit, trois plateformes** | Windows 11 (Fluent), Android (Material You), Web (PWA) — même noyau, même données, UX native par plateforme. |
| P10 | **Conformité continue** | Audit juridique annuel, tests de conformité automatisés en CI, veille réglementaire (Loi 25, PHIPA, PIPEDA). |

## 1.4 Portée du produit (in / out)

**Dans la portée (v1–v3)** : cœur clinique, agenda, facturation RAMQ/assureurs, soins & médication (MAR), télésanté, logistique, portail patient, IoT, IA (scribe/analytique) hors flux critique.

**Hors portée (v1)** : dossier dentaire complet, pharmacie interne de fabrication, PACS d'imagerie enterprise (intégration via FHIR/DICOM seulement), recherche clinique.

## 1.5 Public cible & personas

| Persona | Besoin clé | Plateforme principale |
|---|---|---|
| Médecin (CHU/clinique) | Dossier complet, prescription sûre, notes rapides | Windows 11 (WinUI 3) |
| Infirmier(ère) (CHSLD) | MAR, plans de soins, signes vitaux, alertes | Windows 11 + Android (tablette) |
| Réceptionniste | Agenda, RDV, accueil | Windows 11 |
| Pharmacien | Validation ordonnances, inventaire | Windows 11 |
| Administrateur établissement | Utilisateurs, rôles, configuration, audit | Windows 11 + Web |
| **Patient** | RDV, résultats, messagerie, consentements | **Web (PWA) + Android** |
| DPO / CISO / Auditeur | Gouvernance, audit, conformité | Web (console) |

## 1.6 Engagements mesurables (SLO)

| Engagement | Cible |
|---|---|
| Disponibilité noyau clinique | ≥ 99,95 % (hors maintenance planifiée) |
| Latence lecture dossier (p95) | < 300 ms |
| Latence écriture observation (p95) | < 500 ms |
| RTO (reprise après sinistre) | < 15 min |
| RPO (perte de données max) | < 5 min |
| Couverture tests cœur clinique | ≥ 85 % |
| Findings sécurité critiques en prod | 0 (bloquant CI) |
| Accessibilité | WCAG 2.2 niveau AA |
