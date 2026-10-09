# ADR-009 — IA hors du flux critique (sécurité patient & conformité)

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, comité médical, DPO, CISO

## Contexte

HospiCore intègre de l'IA (scribe vocal, extraction NLP, aide à la décision, analytique prédictive). En santé, une erreur de l'IA peut causer un **préjudice au patient** (risque R3) et engager la responsabilité légale. La Loi 25 impose de plus l'EFVP et la protection des RP (aucun PHI vers des services externes).

## Décision

**L'IA est strictement hors du flux critique** :

1. **Scribe IA** : la dictée génère une **proposition de note SOAP** (FHIR) que le clinicien **révise, valide et signe** — jamais de validation automatique.
2. **Aide à la décision** (interactions, dosages, alertes) : suggestions **explicables**, le clinicien décide ; l'humain reste responsable.
3. **Exécution locale** : modèles IA exécutés **sur place** (cloud privé QC / on-prem) sur données **dé-identifiées** ; **aucune PHI vers un LLM externe** (règle HIPAA guardrails + Loi 25 souveraineté).
4. **Journalisation** : toute sortie IA est tracée (qui, quand, quoi, version du modèle) et auditable.
5. **Comité médical** : valide les modules IA (ergonomie, pertinence clinique, biais) avant mise en production.
6. **EFVP** obligatoire pour chaque module IA (Loi 25).

## Conséquences

- ✅ Sécurité patient préservée (l'humain décide toujours).
- ✅ Conformité Loi 25/HIPAA (souveraineté, minimisation, EFVP).
- ✅ Confiance des cliniciens (l'IA assiste, ne remplace pas).
- ⚠️ Latence/qualité des modèles locaux à optimiser (GPU on-prem QC en Phase 4).

## Alternatives considérées

- **IA décisionnelle autonome** : efficacité maximale, risque patient/légal inacceptable — **rejetée**.
- **LLM cloud externe (API)** : qualité modèle, mais PHI hors Canada et dépendance fournisseur — **rejetée** pour le clinique (envisageable uniquement sur données dé-identifiées, avec DPO).
