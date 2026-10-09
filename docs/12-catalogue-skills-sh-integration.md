# 12 — Catalogue des Skills (skills.sh) : Intégration DME & IA

> Ce chapitre localise, via **[skills.sh](https://skills.sh/)** (l'écosystème ouvert « Agent Skills » de Vercel), **tous les skills à intégrer** dans l'architecture DME d'HospiCore et dans la chaîne de développement IA. Les skills sont des « capacités réutilisables » (fichiers `SKILL.md`) que les agents de codage (Claude Code, Cursor, Codex, Copilot, etc.) installent en une commande.
>
> **Installation générale** : `npx skills add <owner/repo>` (voir https://skills.sh/). Le manifeste machine-readable est dans [`skills/skills-manifest.json`](../skills/skills-manifest.json).

---

## 12.1 Cœur clinique & interopérabilité (FHIR / HL7 / terminologies)

| Skill | Éditeur / Dépôt | Ce qu'il apporte à HospiCore | Installation |
|---|---|---|---|
| **fhir-developer-skill** (+ `fhir`) | `anthropics/healthcare` | Création d'endpoints FHIR R4 (Patient, Observation, Encounter, Condition, MedicationRequest), validation ressources, codes HTTP, **SMART on FHIR** (OAuth scopes), Bundles/transactions, OperationOutcome, codifications (LOINC, SNOMED, RxNorm, ICD-10) | `npx skills add anthropics/healthcare` |
| **clinical-note-extract-skill** | `anthropics/healthcare` | Extraction d'entités cliniques (diagnostics, médicaments, procédures) depuis notes non structurées → base du scribe IA | id. |
| **icd10-cm-skill** | `anthropics/healthcare` | Codage ICD-10(-CA) des diagnostics (table `clinical.conditions`) | id. |
| **procedure-coding** | `anthropics/healthcare` | Codage des procédures (CCI) pour facturation | id. |
| **prior-auth-review-skill** | `anthropics/healthcare` | Revue des autorisations préalables (assureurs) | id. |
| **fraud-detection** | `anthropics/healthcare` | Détection de fraude à la facturation (claims) | id. |
| **doc-extract** / **contracts** | `anthropics/healthcare` | Extraction documentaire (comptes rendus), revue de contrats (DPA fournisseurs) | id. |
| **clinical-trial-protocol-skill** | `anthropics/healthcare` | (Phase 4) protocoles de recherche clinique | id. |
| **clinical-data-standards** | `awslabs/hcls-agent-skills` (41 skills HCLS) | Hiérarchie MedDRA, structure ICD-10, SNOMED CT, LOINC, **mapping de terminologies** | `npx skills add awslabs/hcls-agent-skills` |
| **ehr-data-parsing** | `awslabs/hcls-agent-skills` | **Parsing HL7v2**, extraction FHIR R4, conversion de formats, qualité des données (IoT legacy) | id. |
| **claims-billing-rules** / **claims-analytics** | `awslabs/hcls-agent-skills` | Règles de facturation, parsing X12 837/835, détection doublons (module RAMQ/assureurs) | id. |
| **risk-adjustment**, **risk-adjustment-strategy** | `awslabs/hcls-agent-skills` | Indices de risque (HCC), stratégie de codage (analytique populationnelle, Phase 4) | id. |
| **pa-clinical-policy**, **pa-decision-automation** | `awslabs/hcls-agent-skills` | Autorisations préalables (X12 278 / FHIR PAS) | id. |
| **hedis-measure-specification**, **quality-measures** | `awslabs/hcls-agent-skills` | Mesures qualité (soins, écarts de soins) — tableaux de bord | id. |
| **risk-stratification-indices**, **provider-denial-workup**, **coordination-of-benefits** | `awslabs/hcls-agent-skills` | Stratification (LACE, Charlson), gestion des refus, coordination des avantages | id. |
| **health-fhir-api-design**, **health-fhir-modeling** | `reason-healthcare/health-skills` (19 skills) | **Design d'API FHIR** et **modélisation FHIR** (profils, ressources, mapping vers notre schéma SQL) | `npx skills add reason-healthcare/health-skills` |
| **health-human-factors** | `reason-healthcare/health-skills` | Facteurs humains cliniques (sécurité patient, ergonomie — comité médical) | id. |
| **health-compliance-review**, **health-hipaa-review**, **health-hipaa-secure-delivery** | `reason-healthcare/health-skills` | Revue de conformité et **livraison sécurisée HIPAA** | id. |
| **health-docs**, **health-init**, **health-refactor**, **health-product-discovery**, **health-project-context** | `reason-healthcare/health-skills` | Documentation, initialisation, refactoring, découverte produit | id. |
| **openspec-*** (propose/explore/verify/apply/continue/archive/new-change/sync-specs) | `reason-healthcare/health-skills` | Gestion des changements (spécifications → code) pour un DME réglementé | id. |
| **hipaa-compliance-checker** | `open-medica/open-medical-skills` (49 skills) | Vérification conformité HIPAA du code (chiffrement, logs, accès) | `npx skills add open-medica/open-medical-skills` |
| **lab-result-interpreter** | `open-medica/open-medical-skills` | Interprétation des résultats (intervalles de référence, tendances, alertes critiques) | id. |
| **icd10-code-lookup**, **cpt-coding-assistant** | `open-medica/open-medical-skills` | Lookup terminologies, codage | id. |
| **clinical-differential-diagnosis**, **evidence-synthesis-ai** | `open-medica/open-medical-skills` | (Phase 4) aide à la décision clinique | id. |
| **dicom-metadata-extractor**, **patient-assessment-tool**, **phq9-depression-screening**, **pubmed-literature-search**, **outbreak-investigation** (+ 40 autres) | `open-medica/open-medical-skills` | Imagerie (DICOM), échelles cliniques (PHQ-9), littérature, surveillance | id. |
| **fhir-ig-analysis**, **fhir-ig-translation**, **mii-ig-migration** | `forschungsgruppe-digital-health/agent-skills` | Analyse/migration des **Guides d'implémentation FHIR** (profils nationaux/DSQ) | `npx skills add forschungsgruppe-digital-health/agent-skills` |
| **ehr-fhir-integration**, **fhir-development** | `FreedomIntelligence/OpenClaw-Medical-Skills` (OpenClaw) | Intégration EHR-FHIR, dev API FHIR, SMART on FHIR | dépôt GitHub (voir manifeste) |
| **clinical-note-summarization**, **clinical-nlp-extractor** | `FreedomIntelligence/OpenClaw-Medical-Skills` | Résumé de notes en SOAP, extraction NLP clinique (scribe IA) | id. |
| **drug-interaction-checker** | `FreedomIntelligence/OpenClaw-Medical-Skills` | **Vérification interactions médicamenteuses** (sécurité patient, Phase 2) | id. |
| **lab-results** | `FreedomIntelligence/OpenClaw-Medical-Skills` | Interprétation résultats, alertes valeurs critiques | id. |
| **wearable-analysis-agent**, **digital-twin-clinical-agent**, **trial-eligibility-agent**, **care-coordination**, **claims-appeals**, **prior-auth-coworker**, **regulatory-drafter/drafting**, **biomedical-data-analysis**, **multimodal-medical-imaging** | `FreedomIntelligence/OpenClaw-Medical-Skills` | IoT/wearables, jumeau numérique, coordination soins, analytique (Phases 3–4) | id. |

## 12.2 Conformité, sécurité & audit (Loi 25 / HIPAA / ISO 27001)

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **compliance-engineering** | `travisjneuman/.claude/compliance-engineering` | Implémentation **SOC2, HIPAA, GDPR, PCI-DSS, FedRAMP** en code : audit logging immuable, chiffrement, contrôles d'accès, privacy by design, mapping réglementaire | `npx skills add travisjneuman/.claude/compliance-engineering` (ou via agent-skills.md) |
| **compliance-testing** | `proffesor-for-testing/agentic-qe/compliance-testing` | **Tests de conformité réglementaire** (GDPR, CCPA, HIPAA, SOC2) : droits des personnes, chiffrement, logs, rapports prêts pour audit | `npx skills add proffesor-for-testing/agentic-qe` |
| **security-and-hardening** | `addyosmani/agent-skills` | Threat modeling (STRIDE), frontières de confiance, checklist sécurité complète (auth, autorisation, input, données, infra, supply chain, **AI/LLM**) | `npx skills add addyosmani/agent-skills` |
| **api-security-best-practices** | `sickn33/antigravity-awesome-skills` | Sécurisation des API (auth, autorisation objet, validation, rate limiting) | `npx skills add sickn33/antigravity-awesome-skills` |
| **security-audit** | `netresearch/security-audit-skill` | **Audit sécurité** (OWASP Top 10, CWE Top 25, ASVS v4.0), SAST, supply chain (SLSA), hooks CI | `npx skills add netresearch/security-audit-skill` |
| **HIPAA Compliance Guardrails** | (Claude Code, via mcpmarket) | Garde-fous HIPAA : 18 identifiants, AES-256, logs 6 ans, **jamais de PHI vers un LLM** | dépôt référencé (voir manifeste) |
| **devops-security-agent-skills** (163 skills) | `bagelhole/devops-security-agent-skills` | `windows-hardening`, `container-hardening`, `kubernetes-hardening`, `audit-logging`, `gdpr-compliance`, `penetration-testing`, `incident-response`, `disaster-recovery`, `cis-benchmarks`, `policy-as-code`, `sast-scanning`, `waf-setup`, `ssl-tls-management`, `vulnerability-scanning`, `database-backups`, `github-actions`, `terraform-aws/gcp/azure`, `kubernetes-ops`, `backup-recovery`… | `npx skills add bagelhole/devops-security-agent-skills` |
| **mobile-security**, **offline-first**, **mobile-security-review**, **encryption** | `ahmed3elshaer/everything-claude-code-mobile`, `tinh2/skills-hub-registry` | Sécurité mobile (Keystore, chiffrement local), revue sécurité mobile, chiffrement, offline-first | `npx skills add ahmed3elshaer/everything-claude-code-mobile`, `npx skills add tinh2/skills-hub-registry` |

## 12.3 Windows — WinUI 3 / Windows App SDK (Fluent, Windows 10 2004+/11, MSIX)

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **winui-design**, **winui-dev-workflow**, **winui-code-review**, **winui-ui-testing**, **winui-setup**, **winui-packaging**, **pr-review**, **winui-wpf-migration**, **winui-session-report** | `microsoft/win-dev-skills` (**officiel Microsoft**, 9 skills) | Design WinUI 3, workflow dev, revue de code, tests UI, setup machine, **packaging (MSIX)**, revue PR | `npx skills add microsoft/win-dev-skills` |
| **winui-app** | `openai/skills` | Bootstrap nouvelle app WinUI 3 (Windows App SDK), décisions UX modernes Windows, patterns d'implémentation, guidance officielle Microsoft + WinUI Gallery + CommunityToolkit | `npx skills add openai/skills` |
| **winui3-full-skill** | `sudocode76/winui3-skills` | Skill complet WinUI 3 (38 références) | `npx skills add sudocode76/winui3-skills` |
| **dotnet-winui**, **dotnet-msix**, **dotnet-cryptography**, **dotnet-secrets-management**, **asp-net-core-identity-patterns**, **rate-limiting**, **dotnet-structured-logging**, **dotnet-efcore-architecture**, **dotnet-minimal-apis**, **dotnet-maui-development** (+ 150 autres) | `wshaddix/dotnet-skills` (167 skills) | Écosystème .NET complet pour Windows + backend | `npx skills add wshaddix/dotnet-skills` |
| **aspnet-core**, **entity-framework-core**, **minimal-apis**, **signalr**, **web-api**, **dotnet-testing**, **archunitnet**, **quality-ci** (+ 280 autres) | `managedcode/dotnet-skills` | Backend ASP.NET Core, EF Core, tests, qualité, CI | `npx skills add managedcode/dotnet-skills` |
| **dotnet-winui**, **dotnet-accessibility**, **dotnet-localization**, **dotnet-observability**, **dotnet-msix**, **dotnet-structured-logging**, **dotnet-secrets-management**, **dotnet-efcore-architecture**, **dotnet-api**, **dotnet-csharp** (+ 125 autres) | `novotnyllc/dotnet-artisan` (135 skills) | .NET artisan : UI, API, accessibilité, localisation (fr/en), packaging | `npx skills add novotnyllc/dotnet-artisan` |

## 12.4 Android — Jetpack Compose / Material You (Android 17 cible)

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **mobile-android-design** | `wshobson/agents` | **Material Design 3 (Material You) + Jetpack Compose** : composants, theming dynamique, navigation, adaptatif (phones/tablettes/pliables), accessibilité | `npx skills add wshobson/agents` |
| **android-agent-skills** (34 skills) | `krutikjain/android-agent-skills` | `android-material3-design-system`, `android-compose-foundations`, `android-compose-accessibility`, `android-security-best-practices`, `android-room-database`, `android-local-persistence-datastore`, `android-serialization-offline-sync`, `android-workmanager-notifications`, `android-ci-cd-release-playstore`, `android-architecture-clean`, `android-networking-retrofit-okhttp`, `android-testing-unit/ui`, `android-emulator-automation`, `android-performance-observability`… | `npx skills add krutikjain/android-agent-skills` |
| **jetpack-compose**, **compose-expert** | `aldefy/compose-skill` | Expertise Compose (patterns, architecture) | `npx skills add aldefy/compose-skill` |
| **material-3**, **jetpack-compose-audit**, **compose-agent** | `hamen/material-3-skill`, `hamen/compose_skill` | Material 3, audit Compose | `npx skills add hamen/material-3-skill`, `npx skills add hamen/compose_skill` |
| **android-studio**, **android-sdk**, **jetpack-compose**, **materialui** | `g1joshi/agent-skills` (356 skills) | Outils Android Studio/SDK, Compose, Material UI | `npx skills add g1joshi/agent-skills` |

## 12.5 Web — React / PWA / Accessibilité

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **frontend-design** | `anthropics/skills` (officiel Anthropic) | Design frontend **distinctif et mémorable** (évite le « look IA générique ») | `npx skills add anthropics/skills` |
| **react-frontend-expert** | `hieutrtr/ai1-skills` | React 19/TS strict, hooks, TanStack Query, formulaires, **WCAG 2.1 AA intégré** | `npx skills add hieutrtr/ai1-skills` |
| **frontend-developer** | `sickn33/antigravity-awesome-skills` | React/Next.js, perf, accessibilité, state, data fetching | `npx skills add sickn33/antigravity-awesome-skills` |
| **web-accessibility** | `supercent-io/skills-template` | **WCAG 2.1** : HTML sémantique, clavier, ARIA, contraste, tests axe-core/Lighthouse | `npx skills add supercent-io/skills-template` |
| **accessibility-compliance** | `wshobson/agents` | **WCAG 2.2** A/AA/AAA, ratios de contraste, cibles tactiles 44×44, patterns accessibles (boutons, modales, formulaires, live regions) | `npx skills add wshobson/agents` |

## 12.6 Backend, données & architecture

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **dotnet-backend**, **dotnet-architect**, **dotnet-backend-patterns** | `sickn33/antigravity-awesome-skills` | **ASP.NET Core 8/9 enterprise**, EF Core, auth, workers, patterns prod | `npx skills add sickn33/antigravity-awesome-skills` |
| **aspnet-core**, **aspnet-minimal-api-openapi**, **containerize-aspnetcore**, **csharp-xunit**, **csharp-async**, **dotnet-best-practices** | `midudev/autoskills` | ASP.NET Core, OpenAPI, conteneurisation, tests | `npx skills add midudev/autoskills` |
| **prisma-database-setup**, **prisma-client-api**, **prisma-cli**, **prisma-postgres** (+ Prisma Postgres serverless) | `prisma/skills` (9) + `prisma/cursor-plugin` (40) | ORM Prisma/PostgreSQL (si couche Node d'admin/outils) | `npx skills add prisma/skills`, `npx skills add prisma/cursor-plugin` |
| **architecture-patterns** | `wshobson/agents` | **Clean Architecture, Hexagonal, DDD** (bounded contexts, agrégats, value objects, événements de domaine) | `npx skills add wshobson/agents` |
| **clean-ddd-hexagonal** | `ccheney/robust-skills` | DDD + Clean + Hexagonal (règles de dépendance, anti-patterns) | `npx skills add ccheney/robust-skills` |
| **ddd-skills** (21 skills) | `full-stack-skills/ddd-skills` | `ddd-domain-designer`, `ddd-event-storming`, `ddd-architecture-clean/hexagonal/onion/cqrs`, `ddd-api-designer`, `ddd-testing-strategist`… | `npx skills add full-stack-skills/ddd-skills` |
| **domain-modeling**, **improve-codebase-architecture** | `mattpocock/skills` | Modélisation de domaine, architecture de codebase | `npx skills add mattpocock/skills` |
| **spring-boot-event-driven-patterns** | `giuseppe-trisciuoglio/developer-kit` | EDA (Kafka, outbox transactionnel, événements de domaine) — si option Java | `npx skills add giuseppe-trisciuoglio/developer-kit` |
| **java-architect** | `jeffallan/claude-skills` | Spring Boot 3 / Java 21 enterprise (alternative backend) | `npx skills add jeffallan/claude-skills` |

## 12.7 DevOps, CI/CD & Déploiement

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **devops-engineer** | `jeffallan/claude-skills` | CI/CD, IaC, conteneurisation, Kubernetes, GitOps, Terraform, GitHub Actions, runbooks incident | `npx skills add jeffallan/claude-skills` |
| **deployment-engineer**, **docker-expert** | `sickn33/antigravity-awesome-skills` | Pipelines CI/CD, GitOps, stratégies de déploiement, Docker (multi-stage, hardening) | `npx skills add sickn33/antigravity-awesome-skills` |
| **github-actions**, **terraform-aws**, **kubernetes-ops**, **kubernetes-hardening**, `container-hardening`… | `bagelhole/devops-security-agent-skills` (voir §12.2) | CI GitHub Actions, IaC, K8s ops/hardening | id. |
| **agent-browser** | `vercel-labs/agent-browser` | Automatisation navigateur (tests E2E agent) | `npx skills add vercel-labs/agent-browser` |

## 12.8 Intelligence Artificielle (scribe, RAG, agents — hors flux critique)

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **prompt-engineering-patterns** | `wshobson/agents` | Few-shot, chaîne de pensée, sorties structurées (JSON/Pydantic), RAG, caching de prompts, monitoring | `npx skills add wshobson/agents` |
| **rag-engineer**, **rag-implementation**, **prompt-engineer**, **prompt-engineering**, **prompt-engineering-patterns** | `sickn33/antigravity-awesome-skills` | RAG (indexation, retrieval, évaluation), ingénierie de prompts | `npx skills add sickn33/antigravity-awesome-skills` |
| **agent-orchestration-multi-agent-optimize**, **multi-agent-brainstorming**, **agentflow**, **llm-prompt-optimizer** | `sickn33/antigravity-awesome-skills` | Orchestration multi-agents (scribe, revue, conformité) | id. |
| **audio-transcriber** | `sickn33/antigravity-awesome-skills` | **Transcription audio (dictée vocale — scribe IA)** | id. |
| **llm-application-dev** | `moizibnyousaf/ai-agent-skills` | Développement d'applications LLM (prompt engineering, patterns RAG, intégration) | `npx skills add moizibnyousaf/ai-agent-skills` |
| **ai-rag-pipeline**, **llm-models**, **prompt-engineering** | `skills-101/superpowers` (86 skills) | Pipelines RAG, modèles LLM, prompting | `npx skills add skills-101/superpowers` |
| **skill-creator** | `openai/skills` | **Créer nos propres skills HospiCore** (SKILL.md) : règles métier, profils FHIR, protocoles de soins | `npx skills add openai/skills` |
| **find-skills** | `vercel-labs/skills` | Découverte de skills supplémentaires à jour | `npx skills add vercel-labs/skills` |

## 12.9 Qualité, tests & documentation

| Skill | Éditeur / Dépôt | Apport | Installation |
|---|---|---|---|
| **tdd** | `mattpocock/skills` | Test-Driven Development | `npx skills add mattpocock/skills` |
| **playwright-e2e-testing** | `fugazi/test-automation-skills-agents` | **E2E Playwright (TypeScript)** : POM, fixtures, mock API, responsive, visual regression | `npx skills add fugazi/test-automation-skills-agents` |
| **playwright-skill** | `testdino-hq/playwright-skill` | 50+ guides Playwright (E2E, API, visuel, a11y, sécurité, CI/CD) | `npx skills add testdino-hq/playwright-skill` |
| **qaskills** (59 skills) | `pramoddutta/qaskills` | `jest-unit`, `playwright-e2e`, `playwright-api`, **`gdpr compliance testing`**, **`axe-core accessibility testing`**, **`WCAG Accessibility Testing`**, `k6 performance testing`, `api contract validator`, `Accessibility Auditor`, `e2e-testing-claude-code`, `espresso android testing`… | `npx skills add pramoddutta/qaskills` |
| **specweave** | `anton-abyzov/specweave` | `tdd-expert`, `tdd-workflow`, `unit-testing-expert`, `e2e-playwright`, `qa-lead`, `device-testing`, `performance` | `npx skills add anton-abyzov/specweave` |
| **documentation** | `mcollina/skills` | Documentation technique selon le framework **Diátaxis** (tutoriels, how-to, référence, explication) — standard de cette Bible | `npx skills add mcollina/skills` |

## 12.10 Installation rapide (HospiCore — profil « full stack DME »)

```bash
# 1) Cœur clinique & conformité
npx skills add anthropics/healthcare                 # FHIR, ICD-10, extraction clinique
npx skills add awslabs/hcls-agent-skills             # 41 skills HCLS (HL7v2, claims, qualité)
npx skills add reason-healthcare/health-skills       # design/modeling FHIR, human factors, HIPAA review
npx skills add open-medica/open-medical-skills       # 49 skills (HIPAA checker, lab, PHQ-9, DICOM…)
npx skills add forschungsgruppe-digital-health/agent-skills  # FHIR IG

# 2) Sécurité & conformité
npx skills add travisjneuman/.claude/compliance-engineering
npx skills add proffesor-for-testing/agentic-qe      # compliance-testing
npx skills add addyosmani/agent-skills               # security-and-hardening
npx skills add sickn33/antigravity-awesome-skills    # api-security, dotnet, devops, rag, audio…
npx skills add netresearch/security-audit-skill       # audit OWASP
npx skills add bagelhole/devops-security-agent-skills # 163 skills (hardening, WAF, K8s, pen-test…)

# 3) Plateformes clientes
npx skills add microsoft/win-dev-skills              # WinUI 3 officiel (design, packaging MSIX…)
npx skills add openai/skills                         # winui-app, skill-creator
npx skills add wshaddix/dotnet-skills                # 167 skills .NET
npx skills add managedcode/dotnet-skills             # 290 skills .NET (ASP.NET, EF Core…)
npx skills add novotnyllc/dotnet-artisan             # 135 skills .NET (winui, a11y, localization…)
npx skills add wshobson/agents                       # Material You/Compose, a11y WCAG 2.2, architecture, prompts
npx skills add krutikjain/android-agent-skills       # 34 skills Android (M3, sécurité, Room, offline…)
npx skills add aldefy/compose-skill                  # Compose expert
npx skills add hamen/material-3-skill                # Material 3
npx skills add anthropics/skills                     # frontend-design
npx skills add hieutrtr/ai1-skills                   # React expert (WCAG)
npx skills add supercent-io/skills-template          # web-accessibility (WCAG 2.1)

# 4) Données, architecture, DevOps
npx skills add prisma/skills                         # Prisma/PostgreSQL
npx skills add ccheney/robust-skills                 # clean-ddd-hexagonal
npx skills add full-stack-skills/ddd-skills          # 21 skills DDD
npx skills add mattpocock/skills                     # tdd, domain-modeling, architecture
npx skills add jeffallan/claude-skills               # devops-engineer, java-architect
npx skills add moizibnyousaf/ai-agent-skills         # LLM application dev
npx skills add skills-101/superpowers                # RAG, LLM, prompting

# 5) Tests & documentation
npx skills add fugazi/test-automation-skills-agents  # Playwright E2E
npx skills add testdino-hq/playwright-skill          # Playwright (50+ guides)
npx skills add pramoddutta/qaskills                  # 59 skills QA (gdpr, WCAG, axe-core, k6…)
npx skills add anton-abyzov/specweave                # TDD, QA lead, e2e
npx skills add mcollina/skills                       # documentation (Diátaxis)

# 6) Utilitaires
npx skills add vercel-labs/agent-browser             # navigateur agent (E2E)
npx skills add vercel-labs/skills                    # find-skills (découverte)
```

## 12.11 Gouvernance des skills chez HospiCore

1. **Manifeste versionné** : [`skills/skills-manifest.json`](../skills/skills-manifest.json) — liste, version, justification, commande d'installation.
2. **Revue** : tout skill ajouté est revu (sécurité, licence, pertinence) par le CISO/CTO avant usage.
3. **Skills internes** : créer nos propres skills (via `skill-creator`) pour : règles métier clinique, profils FHIR HospiCore, protocoles de soins, checklist conformité Loi 25.
4. **Pas de PHI dans les skills** : aucun skill ne doit traiter de données patients réelles (règle HIPAA guardrails).
5. **Veille** : `find-skills` mensuel pour découvrir les nouveautés (skills.sh évolue vite).

*Voir aussi : [03 — Architecture](./03-architecture-technique-complete.md), [13 — Standards qualité & CI/CD](./13-standards-qualite-cicd.md), [skills/skills-manifest.json](../skills/skills-manifest.json)*
