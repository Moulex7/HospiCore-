# 13 — Standards de Qualité & CI/CD

## 13.1 Conventions de code

| Langage/Plateforme | Standard |
|---|---|
| **C# (.NET 9)** | .NET Coding Conventions, `Nullable` activé, `TreatWarningsAsErrors` en CI, `editorconfig` strict, analyseurs (StyleCop/Roslynator), `dotnet format` en CI |
| **Kotlin (Android)** | Kotlin Coding Conventions, `detekt` + `ktlint`, Compose guidelines officielles |
| **TypeScript (Web)** | `strict: true`, `noUncheckedIndexedAccess`, ESLint + Prettier, `tsc --noEmit` en CI |
| **SQL** | snake_case, commentaires en-tête par table, migrations versionnées (Flyway/Liquibase/Sqitch) |
| **Nommage** | Français pour la documentation métier, Anglais pour le code (noms de tables, colonnes, API) — cohérence FHIR |

## 13.2 Tests (pyramide)

| Niveau | Cible | Outils |
|---|---|---|
| **Unitaires** | ≥ 85 % cœur clinique | xUnit (C#), JUnit (si Java), pytest (Python IA), Jest/Vitest (TS), Kotlin test |
| **Intégration** | Contrats API FHIR, base de données (Testcontainers) | Testcontainers, HAPI FHIR validator |
| **Contrats** | Pact entre services et clients | Pact |
| **E2E** | Parcours critiques (login MFA, ouverture dossier, ordonnance, MAR, RDV, portail) | Playwright (web), WinAppDriver/Appium (Windows), Compose UI Test (Android) |
| **Conformité** | Tests Loi 25/HIPAA automatisés (chiffrement, audit, consentement, droits) | Suite dédiée (skill `compliance-testing`, `gdpr compliance testing`) |
| **Accessibilité** | axe-core (web), tests Narrator/TalkBack manuels, contraste | axe-core, Lighthouse CI |
| **Performance** | Budgets (chapitres 06/07/08), k6 (charge API) | k6, Lighthouse CI |
| **Sécurité** | SAST, scan dépendances, scan secrets | Semgrep/CodeQL, Trivy, Snyk, gitleaks |

**Règle** : aucun merge sans tests verts + revue de 2 pairs (1 sécurité pour les parcours cliniques).

## 13.3 CI/CD (GitHub Actions)

```text
PR → Build → Tests unitaires → Tests intégration → SAST/Secrets/Dependances
   → Tests conformité (Loi 25/HIPAA) → Tests a11y (axe-core) → Review requise → Merge
main → Build images (scan Trivy) → Déploiement staging (GitOps ArgoCD) → Tests E2E staging
     → Approbation manuelle → Déploiement prod (canary 10 % → 100 %) → Smoke tests
```

| Gate | Bloquant si échec |
|---|---|
| Build + tests unitaires/intégration | ✅ |
| SAST (critique/haute) | ✅ |
| Scan secrets (gitleaks) | ✅ |
| Scan dépendances (critique) | ✅ |
| Tests conformité (chiffrement, audit, consentement) | ✅ |
| axe-core (violations sérieuses) | ✅ |
| Revue 2 pairs | ✅ |
| Déploiement prod | Approbation manuelle + fenêtre de changement |

## 13.4 Gestion des branches & releases

- `main` : production (protégée, merge via PR uniquement).
- `develop` : intégration continue.
- `feature/*`, `fix/*`, `chore/*` : branches courtes (< 3 jours).
- **SemVer** : `MAJOR.MINOR.PATCH` ; tags de release ; changelog automatique (conventional commits).
- **Feature flags** : modules sensibles (télésanté, IA) activés par flag par tenant.

## 13.5 Définition de « Fait » (DoD)

Une histoire est « faite » quand : code + tests (≥ 85 % sur le module) + doc (API/doc utilisateur) + conformité (EFVP/threat model à jour si applicable) + a11y + revue sécurité + déploiement staging OK.

## 13.6 Observabilité en production

- **Métriques** : Prometheus (latence, erreurs, saturation), SLO (disponibilité 99,95 %, p95 lecture < 300 ms).
- **Logs** : Loki (structurés, **sans PHI**), rétention 90 j chaud / 1 an archivé.
- **Traces** : Tempo (traces distribuées bout en bout).
- **Alertes** : Alertmanager → on-call (PagerDuty), seuils SLO, erreurs 5xx, échecs de synchro, alertes sécurité (IDS).
- **Tableaux de bord** : Grafana (opérationnel, clinique, conformité DPO).

## 13.7 Gestion des secrets

- **Jamais** de secret en code/git (gitleaks en CI + pre-commit).
- Vault (prod) / variables d'environnement (dev) ; rotation 90 j (clés chiffrement via KMS/HSM).
- Mots de passe, clés API, certificats : Vault uniquement.

## 13.8 Relectures obligatoires

| Type de changement | Relecteurs requis |
|---|---|
| Cœur clinique (dossier, ordonnances, MAR) | 2 devs + 1 référent clinique + 1 sécurité |
| Sécurité/authentification | 2 devs sécurité + CISO |
| Conformité (consentement, audit, EFVP) | DPO |
| IA (scribe, NLP) | 2 devs IA + comité médical + conformité (données dé-identifiées) |
| Infrastructure (IaC, K8s) | 2 DevOps + CISO |

*Voir aussi : [09 — Gouvernance & sécurité](./09-gouvernance-securite-risques.md), [12 — Skills](./12-catalogue-skills-sh-integration.md)*
