# 02 — Bible de Conformité (Le « Bouclier Juridique »)

> Ce chapitre est la **matrice de conformité** de référence. Chaque exigence est tracée jusqu'à son implémentation technique. Toute fonctionnalité livrée doit citer la ou les exigences qu'elle sert.

---

## 2.1 Matrice de conformité globale

| Norme / Loi | Portée | Exigence HospiCore | Implémentation technique | Preuve / Audit |
|---|---|---|---|---|
| **Loi 25 (QC)** — *Loi modernisant des dispositions législatives en matière de protection des renseignements personnels* | Renseignements personnels de santé (Québec) | Protection des RP, consentement explicite, DPO nommé, registre des incidents, droit d'accès/effacement/portabilité | Chiffrement AES-256, `consent.consents` (FHIR Consent), procédure d'anonymisation, export Bundle FHIR patient, registre des incidents | Rapport DPO annuel, registre des consentements, tests de conformité CI |
| **HIPAA (US)** — *Health Insurance Portability and Accountability Act* | Données de santé (PHI) si clientèle/entité assujettie US | Sécurité des PHI, confidentialité, intégrité, disponibilité | Audit logs immuables (`audit.audit_events`), contrôle d'accès strict (RBAC + RLS), MFA, chiffrement TLS 1.3/AES-256 | Tests HIPAA automatisés, pen-test annuel |
| **ISO 27001** | Sécurité de l'information (organisation) | SMSI, gestion des risques, sécurité physique & logique | Politiques sécurité, gestion des actifs, contrôle d'accès, cryptographie, journalisation, gestion des incidents | Certification ISO 27001 (Phase 4) |
| **DSQ / Interopérabilité (Québec)** | Échange de données de santé | Échange sécurisé avec le Dossier Santé Québec | Standards **HL7 FHIR R4** obligatoires, profils canadiens (CA Core), connecteur DSQ dédié (Phase 3) | Tests d'interop HAPI FHIR, conformité profils |
| **Normes médicales** | Sécurité des patients | Précision clinique, ergonomie, alertes | Validation par **comité médical**, alertes interactions/allergies, double vérification MAR | Procès-verbaux comité médical, tests utilisateurs |
| **PIPEDA (fédéral CA)** | Données personnelles (fédéral) | Consentement, limitation de collecte, recours | Minimisation des données, politique de confidentialité publique | Politique de confidentialité, registre |
| **PHIPA (Ontario)** — si expansion | Données de santé (Ontario) | Agent de santé, consentement | Même socle que Loi 25 (durcissement) | Analyse d'écart PHIPA (expansion) |
| **WCAG 2.2 AA** | Accessibilité | Interfaces utilisables par tous | Revue accessibilité par plateforme (Narrator, TalkBack, axe-core) | Rapports axe-core/Lighthouse, tests clavier |
| **SOC 2 Type II** | Confiance client (CHU) | Sécurité, disponibilité, confidentialité | Contrôles ISO 27001 + preuves continues (monitoring) | Rapport SOC 2 (Phase 4) |

## 2.2 Loi 25 (Québec) — exigences détaillées

La Loi 25 (sanctionnée en 2021, en vigueur par étapes jusqu'en 2024) impose notamment :

| Article / thème | Obligation | Implémentation HospiCore |
|---|---|---|
| Gouvernance | Nommer un **responsable de la protection des renseignements personnels (DPO)** | Poste dédié, répondant au CA ; nom publié dans la politique de confidentialité |
| Privacy by Design | Protection intégrée par défaut | P1 de la vision ; chiffrement, minimisation, RLS par défaut |
| Consentement | Consentement **libre, éclairé, spécifique**, révocable | `consent.consents` (FHIR Consent) horodaté, granulaire, révocable en un clic (portail) |
| Évaluation des facteurs relatifs à la vie privée (EFVP) | EFVP avant tout projet à risque élevé | EFVP obligatoire pour : IA, télésanté, IoT, nouveaux traitements |
| Registre des incidents | Déclaration des incidents de confidentialité à la CAI | Procédure incident < 72 h, registre, notification aux personnes concernées |
| Droits des personnes | Accès, rectification, portabilité, effacement | Export Bundle FHIR (portail), procédure d'anonymisation, délai 30 jours |
| Minimisation & rétention | Ne collecter que le nécessaire, durée limitée | Champs `*_enc` chiffrés, rétention configurable par tenant, archivage puis purge |
| Sécurité | Mesures de sécurité raisonnables | AES-256, TLS 1.3, MFA, IDS, segmentation, pen-tests |
| Sous-traitance | Encadrement des fournisseurs | DPA (Data Processing Agreement) avec hébergeur, clauses résidence QC/CA |
| Registre des communications | Tracer les divulgations | `audit.audit_events` (qui a communiqué quoi à qui) |

## 2.3 HIPAA — safeguards techniques (si applicable)

| Safeguard | Mesure |
|---|---|
| Contrôle d'accès (§164.312(a)) | ID unique par utilisateur (`identity.users.external_id`), MFA, déconnexion auto (15 min inactivité) |
| Audit (§164.312(b)) | `audit.audit_events` — tout accès PHI, immuable, ≥ 6 ans |
| Intégrité (§164.312(c)) | Hash SHA-256 chaînés, empreintes documents (`sha256`), signatures FHIR |
| Transmission (§164.312(e)) | TLS 1.3, certificate pinning (mobile), mTLS inter-services |
| Chiffrement au repos | AES-256 (TDE + applicatif `*_enc`), clés HSM/KMS |

## 2.4 Traçabilité exigence → code → test

Chaque exigence de conformité possède :
1. une **règle** dans ce document,
2. une **implémentation** (table, service, contrôle UI),
3. un **test automatisé** (CI) prouvant la conformité,
4. une **preuve d'audit** (rapport, registre, capture).

Exemple : *Loi 25 — consentement requis avant affichage résultats de labo*
→ `consent.consents` (scope=patient-privacy, purpose=care) → `GET /fhir/Observation?category=laboratory` vérifie le consentement actif → test `compliance-consent-lab-results.spec.ts` → preuve : capture registre des consentements.

## 2.5 Politique de résidence des données

- **Hébergement** : centre de données certifié au Québec (ex : OVHcloud Canada, AWS Canada Central avec garanties contractuelles de résidence, ou cloud souverain québécois).
- **Aucune PHI** ne quitte le Canada : pas d'appel à une API LLM externe avec des données identifiantes ; modèles IA exécutés **sur place** (on-prem / cloud privé QC) sur données dé-identifiées.
- **S3** : buckets privés, région `ca-central-1` (Montréal) ou équivalent QC, chiffrement KMS, Object Lock (immutabilité) pour documents médico-légaux.
- **Sauvegardes** : chiffrées, stockées au Québec, test de restauration trimestriel.

## 2.6 Rôles de conformité (voir aussi chapitre 09)

| Rôle | Responsabilité légale |
|---|---|
| **DPO** (Data Protection Officer) | Responsable Loi 25, EFVP, registre incidents, lien CAI |
| **CISO** | Sécurité de l'information, ISO 27001, incidents sécurité |
| **Comité médical** | Validation clinique (ergonomie, alertes, sécurité patient) |
| **Juridique externe** | Revue annuelle, DPA fournisseurs, évolutions législatives |

## 2.7 Veille réglementaire

- Revue juridique **annuelle** (Loi 25, PIPEDA, PHIPA, HIPAA, règlements RAMQ).
- Suivi des avis de la **CAI (Commission d'accès à l'information du Québec)**.
- Suivi **Infoway Canada** (DSQ, standards pancanadiens FHIR).
- Mise à jour continue des protocoles internes dans ce dépôt (`docs/`).
