# 11 — Budget & Équipe

> Ordres de grandeur pour un **DME de niveau enterprise** (CHU/CHSLD/cliniques), en dollars canadiens (CAD), sur 24 mois.

---

## 11.1 Équipe cible (15–20 personnes à maturité)

| Équipe | Postes | Effectif |
|---|---|---|
| **Direction** | CTO, DPO (privacy), CISO (sécurité) | 3 |
| **Produit & clinique** | Chef de produit, comité médical (médecins/infirmiers référents, temps partiel), UX lead, designer UI (Windows/Android/Web), UX researcher | 5 |
| **Backend** | Architecte logiciel, devs .NET senior ×4, dev Python (IA) ×2, devOps/SRE ×2 | 9 |
| **Clients** | Dev WinUI 3 (Windows) ×2, dev Android (Kotlin/Compose) ×2, dev Web (React) ×2 | 6 |
| **Qualité & conformité** | QA lead, testeurs auto (Playwright/xUnit/Compose UI) ×2, analyste conformité | 4 |
| **Support & opérations** | Support N2 (santé), succès client (pilote CHU/CHSLD) | 2 (croissance) |

**Total : ~15–20 personnes** (croissance par phase : 5 → 10 → 15 → 20).

## 11.2 Budget annuel (CAD, ordre de grandeur)

| Poste | Année 1 (MVP robuste) | Année 2 (scale) |
|---|---|---|
| **Équipe (15–20 pers.)** — salaires chargés (~130–180 k/pers.) | 2,0 M$ – 4,0 M$ | 2,6 M$ – 4,0 M$ |
| **Infrastructure & sécurité** (cloud QC/CA, K8s, WAF, monitoring, HSM/KMS, licences) | 200 k$ – 500 k$ | 400 k$ – 800 k$ |
| **Certifications & juridique** (ISO 27001, SOC 2, HIPAA, pen-tests, DPO/juridique, EFVP) | 100 k$ – 300 k$ (initial) | 150 k$ – 250 k$ |
| **Outils & licences** (Keycloak (self-hosté), CI/CD, design, MDM, IdP) | 50 k$ – 100 k$ | 75 k$ – 150 k$ |
| **Recherche & clinique** (comité médical, tests utilisateurs, Synthea, terminologies SNOMED/LOINC/RxNorm licences) | 50 k$ – 100 k$ | 75 k$ – 150 k$ |
| ** imprévus (15 %)** | ~400 k$ | ~500 k$ |
| **TOTAL** | **≈ 2,8 M$ – 5,4 M$** | **≈ 3,4 M$ – 5,9 M$** |

> **Total première année avant première vente significative : comptez 3 M$ – 5 M$ CAD.**

## 11.3 Postes clés à recruter en priorité (avant le code)

1. **CTO** — architecte enterprise, expérience santé/finance réglementé.
2. **DPO** — conformité Loi 25 (obligatoire), EFVP, registre incidents.
3. **CISO** — sécurité, ISO 27001, réponse incidents.
4. **Chef de produit santé** — pont métier/clinique.
5. **Médecin/infirmier référent** — comité médical (temps partiel, crédibilité clinique).

## 11.4 Financement & modèle économique

| Levier | Détail |
|---|---|
| **Partenaire pilote** | Clinique/CHSLD en bêta contre réduction de prix + crédits de cas (preuve sociale) |
| **Revenus** | SaaS par établissement (par lit/par praticien/mois), facturation RAMQ en % (si applicable), télésanté à l'acte |
| **Subventions** | Programme Innovaton (Québec), SR&ED (crédits R&D), fonds santé numérique (fédéral/provincial), MITACS (recherche) |
| **Investisseurs** | Anges/santé ( fonds sectoriels) après preuve pilote (M2) |

## 11.5 Coûts récurrents vs investissement

- **CAPEX (investissement)** : fondation (Phase 1), certifications initiales, design system.
- **OPEX (récurrent)** : salaires, cloud, support, conformité continue, R&D IA.

*Voir aussi : [10 — Roadmap](./10-roadmap-phases-developpement.md), [14 — Prochaines étapes](./14-prochaines-etapes-lancement.md)*
