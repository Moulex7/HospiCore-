# 14 — Prochaines Étapes : Lancer HospiCore

## 14.1 Marche à suivre immédiate

1. **Valider le besoin** — Avez-vous un partenaire « Pilote » (une clinique ou un CHSLD prêt à tester le produit en bêta contre réduction de prix) ?
2. **Recruter un CTO & un DPO** — Ne commencez pas le code sans un responsable technique senior et un responsable légal.
3. **Prototype de conformité** — Avant de coder le dossier patient, faites valider votre architecture de sécurité par un expert en **Loi 25** (EFVP).
4. **Choix du standard** — Décidez si vous vous basez sur **OpenEMR** (open source) pour accélérer, ou si vous partez de zéro (plus cher, contrôle total).
   > **Recommandation HospiCore** : partir d'une **base FHIR open-source** (HAPI FHIR + profils CA) pour gagner du temps sur l'interopérabilité, tout en gardant notre modèle canonique (chapitre 04).

## 14.2 Checklist de démarrage (30 premiers jours)

- [ ] Partenaire pilote signé (LOI : lettre d'intention, bêta rémunérée ou crédit)
- [ ] CTO recruté (ou architecte senior mandaté)
- [ ] DPO nommé (responsable protection des RP — Loi 25)
- [ ] CISO nommé (ou consultant sécurité mandaté)
- [ ] Comité médical formé (2 médecins + 2 infirmiers référents)
- [ ] EFVP (évaluation des facteurs relatifs à la vie privée) rédigée pour le MVP
- [ ] Architecture de sécurité validée par expert Loi 25 externe
- [ ] Décision standard : HAPI FHIR (recommandé) vs OpenEMR vs from scratch
- [ ] Hébergeur souverain QC/CA sélectionné (contrat résidence des données)
- [ ] Budget année 1 sécurisé (3–5 M$ CAD) + plan de financement
- [ ] Dépôt GitHub configuré (branchement CI/CD, protections de branches)
- [ ] Skills agents installés ([chapitre 12](./12-catalogue-skills-sh-integration.md) + [skills/skills-manifest.json](../skills/skills-manifest.json))
- [ ] Design system & tokens initialisés (`design/tokens.json`)
- [ ] Schéma SQL appliqué en environnement `dev` (`database/hospicore_fhir_core.sql`)

## 14.3 Stack de démarrage rapide (dev local)

```bash
# Prérequis : Docker Desktop, .NET 9 SDK, Node 22, Android Studio, Visual Studio 2022 (WinUI)
git clone https://github.com/Moulex7/HospiCore-.git
cd HospiCore-

# 1. Base de données (PostgreSQL 16 + Synthea pour données synthétiques)
docker compose -f infrastructure/dev/docker-compose.yml up -d
psql -f database/hospicore_fhir_core.sql

# 2. Backend (microservices .NET 9)
cd backend/src/PatientCore && dotnet run

# 3. Clients
cd clients/windows   # WinUI 3 (Visual Studio / dotnet build)
cd clients/android   # ./gradlew installDebug
cd clients/web       # npm install && npm run dev   (PWA)
```

## 14.4 Ressources externes clés

- **skills.sh** — https://skills.sh/ (découverte/installation des skills agents)
- **HL7 FHIR R4** — https://hl7.org/fhir/R4/
- **HAPI FHIR** — https://hapifhir.io/
- **Profils canadiens (CA Core / DSQ)** — https://www.infoway-inforoute.ca/ (Infoway Canada)
- **Loi 25 (Québec)** — https://www.quebec.ca/ (CAI : https://www.cai.gouv.qc.ca/)
- **Fluent Design** — https://fluent2.microsoft.design/ · **WinUI 3/Windows App SDK** — https://learn.microsoft.com/windows/apps/windows-app-sdk/
- **Material You (M3)** — https://m3.material.io/ · **Jetpack Compose** — https://developer.android.com/compose
- **WCAG 2.2** — https://www.w3.org/TR/WCAG22/

## 14.5 Contact & gouvernance du projet

- **Bible** : ce dossier `docs/` est la référence absolue — toute modification passe par PR relue (DPO/CTO selon sujet).
- **Demandes de changement** : ADR (dossier `docs/adr/`) pour toute décision d'architecture.
- **Conformité** : EFVP + threat model obligatoires avant toute nouvelle fonctionnalité clinique.

---

> *« HospiCore ne se résume pas à du code ; c'est un projet d'ingénierie, de conformité légale et de confiance. »*
