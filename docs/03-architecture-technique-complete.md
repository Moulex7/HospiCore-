# 03 — Architecture Technique Complète (La Stack)

> Pour une grande clinique ou un CHU, l'architecture doit être **micro-services**, **évolutive** et **résiliente** — et servir **trois plateformes clientes** (Windows 10/11, Android, Web) au-dessus d'un **noyau unique**.

---

## 3.1 Vue d'ensemble (schéma logique)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                         UTILISATEURS                                         │
│        Médecins / Infirmiers / Admin          Patients (portail)             │
└───────────┬──────────────────────────────┬──────────────────────────────────┘
            │                              │
   ┌────────▼─────────┐          ┌────────▼─────────┐    ┌──────────────────┐
   │  CLIENT WINDOWS  │          │  CLIENT ANDROID  │    │   CLIENT WEB     │
   │  WinUI 3 / WAS   │          │ Kotlin / Compose │    │  React 19 + TS   │
   │  (Win10 2004+ /  │          │ Material You     │    │  PWA portail     │
   │   Windows 11)    │          │ (Android 17/API37│    │  + console admin │
   │  Packagé MSIX    │          │  cible, minSdk29)│    │                  │
   └────────┬─────────┘          └────────┬─────────┘    └────────┬─────────┘
            │                              │                       │
            └──────────────────────────────┴───────────────────────┘
                                   │  HTTPS / TLS 1.3 (mTLS interne)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    COUCHE DE SÉCURITÉ PÉRIMÉTRIQUE                          │
│        WAF (ex: Cloudflare/AWS WAF) · Protection DDoS · MFA (IdP)          │
│              Conformité : en-têtes sécurité, rate limiting global          │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          API GATEWAY (Kong / Azure APIM)                    │
│     Point d'entrée unique · Rate limiting · Routage · Versioning /v1 /v2   │
│     Validation schéma (OpenAPI) · Journalisation requêtes (sans PHI)         │
└───────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬───┘
        │          │          │          │          │          │          │
        ▼          ▼          ▼          ▼          ▼          ▼          ▼
┌────────────┐ ┌────────────┐ ┌──────────┐ ┌────────┐ ┌─────────┐ ┌────────┐ ┌─────────────┐
│  SERVICE   │ │  SERVICE   │ │ SERVICE  │ │SERVICE │ │SERVICE  │ │SERVICE │ │  SERVICE    │
│ IDENTITÉ   │ │  DOSSIER   │ │ AGENDA & │ │FACTURA-│ │TÉLÉSANTÉ│ │ STOCK  │ │  IA &       │
│ Keycloak / │ │  PATIENT   │ │   RDV    │ │ TION   │ │WebRTC   │ │        │ │  SCRIBE     │
│  Auth0     │ │ (Core EMR) │ │          │ │        │ │chiffré  │ │        │ │ (NLP, hors  │
│  RBAC/ABAC │ │ HL7 FHIR   │ │Conflits,│ │RAMQ/   │ │         │ │        │ │  flux       │
│  MFA, SSO  │ │  HAPI FHIR │ │Rappels  │ │Assureurs│ │        │ │        │ │  critique)  │
└─────┬──────┘ └─────┬──────┘ └────┬─────┘ └────┬───┘ └────┬────┘ └───┬────┘ └──────┬──────┘
      │              │             │            │          │          │             │
      └──────────────┴─────────────┴────────────┴──────────┴──────────┴─────────────┘
                                   │  Bus d'événements (Redis Streams / Kafka)
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BASE DE DONNÉES & STOCKAGE                               │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────┐  ┌─────────────────────┐  │
│  │  PostgreSQL  │  │   MongoDB    │  │  Redis  │  │   S3 PRIVÉ (QC/CA)  │  │
│  │  (données    │  │  (notes non  │  │ (cache, │  │  Documents, images  │  │
│  │   structurées│  │   structurées│  │ sessions│  │  chiffré au repos   │  │
│  │   FHIR JSONB)│  │   cliniques, │  │  files  │  │  Object Lock légal  │  │
│  │   + RLS      │  │   logs)      │  │  jobs)  │  │                     │  │
│  └──────────────┘  └──────────────┘  └─────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│              INFRASTRUCTURE — CLOUD SOUVERAIN QC/CA                         │
│   Kubernetes (K8s) multi-AZ · IaC (Terraform) · GitOps (ArgoCD/Flux)        │
│   Observabilité : Prometheus + Grafana + Loki + Tempo (traces)              │
│   Secrets : Vault / Sealed-Secrets · KMS/HSM pour clés de chiffrement       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 3.2 Principes d'architecture

1. **Microservices par bounded context** (DDD) : identité, dossier patient, agenda, facturation, télésanté, stock, IA.
2. **API-first** : chaque service expose une API FHIR R4 (métier) + OpenAPI (admin). Contrat testé (Pact).
3. **Event-driven** : communication asynchrone par événements de domaine (ex: `PatientCreated`, `ObservationFinal`, `ClaimSubmitted`).
4. **Base de données par service** (pas de base partagée) + **canonical store FHIR** pour l'interop.
5. **Sécurité en profondeur** : WAF → Gateway → mTLS inter-services → RBAC/ABAC → RLS en base.
6. **Résilience** : circuit breakers, retries exponentiels, timeouts, bulkheads, mode dégradé.
7. **Observabilité** : logs structurés (sans PHI), métriques, traces distribuées, alertes SLO.

## 3.3 Choix technologiques recommandés

| Couche | Choix | Justification |
|---|---|---|
| **Backend** | **.NET 9 / ASP.NET Core** (C#) | Robustesse enterprise, perf, écosystème Windows (WinUI), EF Core, excellente conformité/audit. Alternative : Java 21 (Spring Boot) ou Python (FastAPI) pour les modules IA. |
| **Interopérabilité** | **HAPI FHIR** (serveur FHIR R4) | Standard mondial de l'échange de données santé ; profils CA; validation ressources |
| **Identité** | **Keycloak** (self-hosted QC) ou Auth0 (avec résidence CA) | RBAC/ABAC, MFA, SSO, fédération (DSQ, Microsoft Entra) |
| **Frontend Windows** | **WinUI 3 / Windows App SDK** (.NET 9) | UI native Windows 11 (Fluent), perf, MSIX, support long terme |
| **Frontend Android** | **Kotlin + Jetpack Compose** | Material You, moderne, perf, partage possible (KMP) avec logique métier |
| **Frontend Web** | **React 19 + TypeScript (strict)** en PWA | Portail patient, console admin, écosystème riche |
| **Base de données** | **PostgreSQL 16** (+ JSONB pour FHIR) | Fiable, RLS, partitionnement, écosystème, résidence QC |
| **NoSQL** | MongoDB (notes non structurées, logs applicatifs) | Flexibilité schémas cliniques |
| **Cache / files** | **Redis** (cache, sessions courtes, files jobs, streams) | Perf + événements légers (Kafka en Phase 4 si besoin) |
| **Stockage objets** | **S3 privé** (région Canada) | Documents, images — chiffré au repos (KMS), Object Lock |
| **Conteneurs / orchestration** | **Docker + Kubernetes** (managed QC/CA) | Évolutivité, multi-AZ, isolation |
| **IaC / GitOps** | **Terraform + ArgoCD/Flux** | Infrastructure reproductible, déploiements déclaratifs |
| **Télésanté** | **WebRTC chiffré** (serveur SFU type LiveKit/Mediasoup, hébergé QC) | E2E chiffré, salle d'attente virtuelle, enregistrement consenti |
| **IA** | **Python (FastAPI)** + modèles on-prem QC (LLM local) | Scribe, NLP clinique — **hors flux critique**, données dé-identifiées |
| **Recherche** | **OpenSearch/Elasticsearch** (Phase 2) | Recherche clinique (notes, documents) — index sans PHI brute (tokens) |
| **Observabilité** | **Prometheus, Grafana, Loki, Tempo, Alertmanager** | Métriques, logs, traces, alertes |
| **Sécurité** | **Vault (secrets), Trivy/Grype (scan), OPA (policy-as-code), Falco (runtime)** | DevSecOps |
| **CI/CD** | **GitHub Actions** | Build, test, scan sécurité, déploiement GitOps |
| **Hébergement** | **Cloud privé/souverain QC** (OVHcloud Canada, AWS ca-central-1 avec garanties, ou cloud QC) | Résidence des données (Loi 25) |

## 3.4 Sécurité technique (détails)

| Couche | Mesures |
|---|---|
| **Repos** | AES-256 (TDE PostgreSQL + chiffrement applicatif colonnes `*_enc`), clés **HSM/KMS** (rotation 90 jours), séparation des rôles clés |
| **Transit** | TLS 1.3 obligatoire (1.2 min legacy), HSTS, certificate pinning (Android/Windows), mTLS service-à-service |
| **Authentification** | MFA (TOTP/WebAuthn), mots de passe gérés par IdP (jamais en base HospiCore), sessions courtes (15 min inactivité clinique) |
| **Autorisation** | RBAC (rôles) + ABAC (contexte : patient assigné, consentement actif, quart de travail) + **RLS PostgreSQL** (défense en profondeur) |
| **Audit** | FHIR AuditEvent immuable, chaîné SHA-256, rétention ≥ 6 ans, export SIEM |
| **Réseau** | Segmentation (VPC, sous-réseaux privés), security groups stricts, WAF, IDS/IPS, DDoS |
| **Posture** | Scan vulnérabilités CI (Trivy, Snyk), dépendances (Dependabot), SAST (CodeQL/Semgrep), secrets (gitleaks) |

## 3.5 Disponibilité & continuité

- **Multi-AZ** (≥ 2 zones dans la région Canada), réplication synchrone PostgreSQL (Patroni), bascule auto < 60 s.
- **RTO < 15 min / RPO < 5 min** : sauvegardes chiffrées continues (WAL), test de restauration **trimestriel**.
- **Mode dégradé** : clients Windows/Android continuent en **hors-ligne** (SQLite/WatermelonDB chiffré local) + file de synchronisation (ADR-008).
- **Plan de reprise d'activité (PRA)** documenté et testé annuellement.

## 3.6 Environnements

| Environnement | Usage | Données |
|---|---|---|
| `dev` | Développement local (Docker Compose) | Synthétiques (générateur FHIR Synthea) |
| `test` | Tests d'intégration, QE | Synthétiques uniquement |
| `staging` | Recette, démo partenaire pilote | Synthétiques/anonymisées |
| `prod` | Production CHU/CHSLD | PHI réelles (résidence QC) |

**Règle absolue** : jamais de PHI de production hors `prod` (amendes Loi 25).

## 3.7 Dépôt & organisation du code (monorepo)

```text
HospiCore-/
├── docs/                     # ← CETTE BIBLE (référence absolue)
├── database/                 # Schéma PostgreSQL FHIR (hospicore_fhir_core.sql)
├── skills/                   # Manifeste des skills agents (skills.sh)
├── backend/                  # Microservices .NET 9 (par bounded context)
│   ├── src/
│   │   ├── Identity/         # Keycloak config, RBAC
│   │   ├── PatientCore/      # DME (FHIR), HAPI FHIR
│   │   ├── Scheduling/
│   │   ├── Billing/
│   │   ├── Telehealth/
│   │   ├── Inventory/
│   │   └── AiServices/       # Python FastAPI (scribe, NLP)
│   └── tests/
├── clients/
│   ├── windows/              # WinUI 3 (Windows 10 2004+ / 11)
│   ├── android/              # Kotlin / Jetpack Compose (Material You)
│   └── web/                  # React PWA (portail + admin)
├── infrastructure/           # Terraform, K8s, Helm, GitOps
├── .github/workflows/        # CI/CD
└── README.md
```

## 3.8 Flux de données critique (exemple : ouverture dossier patient)

```text
1. WinUI 3 (médecin) → GET /fhir/Patient/<id>?_summary=true   [TLS 1.3, jeton MFA]
2. API Gateway → rate limit, validation jeton (JWKS Keycloak)
3. Service PatientCore → vérification RBAC (peut-lire ce patient ?) + consentement actif
4. PostgreSQL (RLS) → lecture + déchiffrement applicatif des champs *_enc (KMS)
5. AuditEvent (read, Patient/<id>) → chaîné, immuable
6. Réponse 200 (FHIR Patient) — champs sensibles masqués selon rôle (field-level security)
7. Cache Redis (résumé patient, TTL 5 min, clé sans PHI brute)
```

## 3.9 Conformité de l'architecture

| Exigence | Réalisation |
|---|---|
| Résidence QC/CA | Région cloud Canada, S3 ca-central-1, IA on-prem QC |
| Loi 25 | DPO, consentements FHIR, EFVP, registre incidents |
| HIPAA | Audit, MFA, chiffrement, BAAs avec fournisseurs |
| ISO 27001 | SMSI, gestion risques, contrôles documentés (chapitre 09) |
| FHIR/DSQ | HAPI FHIR, profils CA, connecteur DSQ Phase 3 |

*Voir aussi : [04 — Modèle de données FHIR](./04-modele-de-donnees-fhir.md), [05 — Clients multi-plateformes](./05-clients-windows-android-web.md), [09 — Gouvernance & sécurité](./09-gouvernance-securite-risques.md)*
