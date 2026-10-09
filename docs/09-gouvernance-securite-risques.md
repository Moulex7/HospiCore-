# 09 — Gouvernance & Sécurité (Le « Garde-Fou »)

> Pour qu'HospiCore soit accepté par des CHU ou de grandes cliniques, la **gouvernance est aussi importante que le code**.

---

## 9.1 Équipe de conformité (obligatoire avant le premier code)

| Rôle | Responsabilité | Profil |
|---|---|---|
| **DPO** (Data Protection Officer / responsable protection des RP) | Conformité **Loi 25** : EFVP, registre des incidents, lien avec la CAI, consentements, droits des personnes | Juriste/privacy officer, certifié (CIPP/C, CIPM) |
| **CISO** (Chief Information Security Officer) | Cybersécurité, ISO 27001, tests d'intrusion, réponse aux incidents | Ingénieur sécurité senior (CISSP/CEH) |
| **Comité médical** | Valide que le logiciel **ne met pas les patients en danger** (ergonomie, alertes médicamenteuses, parcours cliniques) | Médecins + infirmiers référents (2–4), nommés par établissement pilote |
| **CTO** | Architecture, dette technique, livraison | Ingénieur logiciel senior, expérience santé/entreprise |
| **Juridique externe** | Revue annuelle, DPA fournisseurs, veille législative | Cabinet spécialisé droit de la santé (QC) |

## 9.2 Gestion des risques majeurs

| # | Risque | Impact | Solution HospiCore | Résiduel |
|---|---|---|---|---|
| R1 | **Fuite de données** (PHI) | Critique — amendes Loi 25 (jusqu'à 10 M$ ou 2 % du CA mondial), perte de confiance | Chiffrement de bout en bout (AES-256 + TLS 1.3), segmentation réseau, RLS, détection d'intrusion (IDS), **aucune PHI vers l'extérieur** (IA on-prem QC), politique de minimisation, pen-test annuel | Faible (surveillance continue) |
| R2 | **Panne de service (downtime)** | Critique — soins interrompus | Architecture redondante (multi-AZ), réplication synchrone, **mode dégradé hors-ligne** (clients Windows/Android continuent en local), RTO < 15 min / RPO < 5 min, PRA testé annuellement | Faible |
| R3 | **Erreur médicale due au logiciel** | Critique — sécurité patient | Tests utilisateurs intensifs (comité médical), **alertes de sécurité médicamenteuse** (allergies + interactions), double vérification MAR, l'IA **hors flux critique** (ADR-009), responsabilité clinique humaine préservée | Moyen (veillé) |
| R4 | **Non-conformité légale** | Majeur — sanctions, interdiction | **Audit juridique annuel**, mise à jour continue des protocoles (docs/), tests de conformité en CI, veille CAI/Infoway | Faible |
| R5 | **Usurpation d'identité / compte compromis** | Majeur | MFA obligatoire, mots de passe chez l'IdP (jamais en base), détection d'anomalies (connexion), verrouillage, révocation de session à distance | Faible |
| R6 | **Dépendance fournisseur (cloud, IA externe)** | Majeur | Résidence QC/CA contractuelle, DPA, réversibilité, pas d'IA externe sur PHI, multi-cloud possible | Moyen |
| R7 | **Perte de données (suppression, corruption)** | Majeur | Sauvegardes chiffrées continues, immuabilité (Object Lock) documents légaux, soft delete + anonymisation, tests de restauration trimestriels | Faible |
| R8 | **Erreur de facturation (RAMQ/assureur)** | Moyen | Double validation, pistes d'audit, rapprochement, réclamation automatisée | Faible |

## 9.3 Processus de sécurité (cycle de vie)

1. **Threat modeling** (STRIDE) à chaque nouvelle fonctionnalité (Phase 1 : EFVP + threat model obligatoires).
2. **Revue de code sécurisée** (2 pairs, checklist OWASP ASVS) — bloquante.
3. **Tests de sécurité automatisés** (CI) : SAST (Semgrep/CodeQL), scan dépendances (Trivy/Snyk), scan secrets (gitleaks), tests conformité (HIPAA/Loi 25).
4. **Pen-test** : initial (Phase 1) puis **annuel** + à chaque changement majeur (par firme externe certifiée).
5. **Gestion des vulnérabilités** : SLA — critique < 24 h, majeure < 7 j, moyenne < 30 j.
6. **Réponse aux incidents** : procédure 24/7, déclaration CAI < 72 h (Loi 25), registre, post-mortem.
7. **Revue de conformité annuelle** : juridique + DPO + CISO → mise à jour de la Bible.

## 9.4 Politique de rétention & effacement (Loi 25)

| Donnée | Rétention | Fin de vie |
|---|---|---|
| Dossier clinique | Selon loi (dossier médical : 10 ans+ après dernier soin, configurable par tenant) | Anonymisation irréversible (procédure dédiée) |
| Piste d'audit | ≥ 6 ans (HIPAA), configurable | Purge chiffrée (clés détruites) |
| Consentements | Tant que traitement + 6 ans (preuve) | Archivage légal |
| Journaux applicatifs | 90 jours (chaud) → 1 an (archivé) | Purge |
| Documents S3 | = dossier clinique | Purge + suppression clé de chiffrement (crypto-shredding) |

**Droit à l'effacement** : procédure « anonymiser le patient » (remplacement des `*_enc` par valeurs aléatoires, pseudonymisation des identifiants, conservation des statistiques agrégées) + AuditEvent + délai de traitement 30 jours.

## 9.5 Gestion des consentements (Loi 25 — cœur du système)

- Consentement **granulaire** (par finalité : soins, télésanté, recherche, partage DSQ).
- **Horodaté, révocable à tout moment** (portail patient, un clic).
- **Preuve** : ressource FHIR `Consent` + AuditEvent.
- **Vérification en amont** : chaque traitement vérifie le consentement actif (ABAC policy).

## 9.6 Fournisseurs & sous-traitance

- **DPA** (Data Processing Agreement) obligatoire avec tout fournisseur (hébergeur, IdP, outil CI).
- **Résidence des données** : clause contractuelle QC/CA (Loi 25).
- **Audit fournisseurs** : SOC 2 / ISO 27001 exigés (hébergeur), revue annuelle.
- **Réversibilité** : export complet (FHIR + documents) testé annuellement.

## 9.7 Indicateurs de gouvernance (tableau de bord DPO/CISO)

| Indicateur | Cible |
|---|---|
| Incidents de confidentialité | 0 majeur ; déclaration < 72 h |
| Vulnérabilités critiques ouvertes | 0 (SLA 24 h) |
| Couverture MFA (comptes cliniques) | 100 % |
| Taux de consentements actifs traçés | 100 % des traitements couverts |
| Tests de restauration réussis | 4/4 par an |
| Pen-tests réalisés | 1 initial + 1/an |
| Délai moyen de correction (vulnérabilité) | < SLA par sévérité |

*Voir aussi : [02 — Bible de conformité](./02-bible-de-conformite.md), [13 — Standards qualité & CI/CD](./13-standards-qualite-cicd.md)*
