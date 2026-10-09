# Skills — Intégration Agent Skills (skills.sh)

Ce dossier centralise l'intégration des **skills agents** ([skills.sh](https://skills.sh/) — écosystème ouvert Vercel « Agent Skills ») dans le projet **HospiCore**.

## Fichiers

- **`skills-manifest.json`** — manifeste machine-readable de tous les skills à intégrer (par catégorie : FHIR/clinique, sécurité/conformité, Windows/WinUI, Android/Compose, Web, backend/architecture, DevOps, IA, QA/docs), avec éditeur, URL, justification et commande d'installation.
- **Documentation complète** : [`docs/12-catalogue-skills-sh-integration.md`](../docs/12-catalogue-skills-sh-integration.md)

## Installation rapide

```bash
# Cœur clinique & conformité
npx skills add anthropics/healthcare
npx skills add awslabs/hcls-agent-skills
npx skills add reason-healthcare/health-skills
npx skills add open-medica/open-medical-skills
npx skills add forschungsgruppe-digital-health/agent-skills

# Sécurité & conformité
npx skills add travisjneuman/.claude/compliance-engineering
npx skills add proffesor-for-testing/agentic-qe
npx skills add addyosmani/agent-skills
npx skills add netresearch/security-audit-skill
npx skills add bagelhole/devops-security-agent-skills

# Plateformes clientes
npx skills add microsoft/win-dev-skills
npx skills add openai/skills
npx skills add wshaddix/dotnet-skills
npx skills add managedcode/dotnet-skills
npx skills add novotnyllc/dotnet-artisan
npx skills add wshobson/agents
npx skills add krutikjain/android-agent-skills
npx skills add aldefy/compose-skill
npx skills add hamen/material-3-skill
npx skills add anthropics/skills
npx skills add hieutrtr/ai1-skills
npx skills add supercent-io/skills-template

# Données, architecture, DevOps, IA
npx skills add prisma/skills
npx skills add ccheney/robust-skills
npx skills add full-stack-skills/ddd-skills
npx skills add mattpocock/skills
npx skills add jeffallan/claude-skills
npx skills add sickn33/antigravity-awesome-skills
npx skills add moizibnyousaf/ai-agent-skills
npx skills add skills-101/superpowers

# Tests & documentation
npx skills add fugazi/test-automation-skills-agents
npx skills add testdino-hq/playwright-skill
npx skills add pramoddutta/qaskills
npx skills add anton-abyzov/specweave
npx skills add mcollina/skills

# Utilitaires
npx skills add vercel-labs/agent-browser
npx skills add vercel-labs/skills
```

## Règles de gouvernance

1. Tout skill ajouté doit être ajouté au **manifeste** (PR relue par CTO/CISO).
2. **Revue sécurité** : un skill ne doit pas exiger de permissions excessives ni traiter de PHI.
3. **Skills internes** : créer nos propres skills (`skill-creator`) pour le métier HospiCore (voir `internalSkillsToCreate` dans le manifeste).
4. **Veille** : `find-skills` mensuel.
