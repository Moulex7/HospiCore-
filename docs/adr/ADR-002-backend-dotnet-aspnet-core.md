# ADR-002 — Backend .NET 9 / ASP.NET Core (C#)

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, architecte logiciel

## Contexte

Le backend d'HospiCore doit être **robuste (enterprise)**, performant, sécurisé (audit, chiffrement, conformité) et maintenable sur 10+ ans, tout en s'intégrant à l'écosystème Windows (client WinUI 3) et en supportant des modules IA (Python).

## Décision

Le backend principal est en **.NET 9 / ASP.NET Core (C# 13)** :

- **Microservices par bounded context** (identité, dossier patient, agenda, facturation, télésanté, stock) en Minimal APIs / controllers.
- **EF Core** pour l'accès PostgreSQL (RLS, migrations).
- **HAPI FHIR** (JVM) en conteneur pour le serveur FHIR canonique (interop) — pont .NET ↔ HAPI via API FHIR standard.
- **Modules IA en Python (FastAPI)** (scribe, NLP) — communication par API/events, **hors flux critique** (ADR-009).
- **SignalR** pour le temps réel (alertes, télésanté, sync clients).

## Conséquences

- ✅ Performance, typage fort, tooling enterprise (Visual Studio, Rider), excellent support long terme (LTS).
- ✅ Cohérence stack Windows (WinUI 3 / .NET) : partage de modèles FHIR générés (C#).
- ✅ Écosystème sécurité/conformité mature (Identity, cryptographie, logging, audit).
- ⚠️ HAPI FHIR en JVM ajoute un runtime — justifié par l'interop (standard mondial).
- ⚠️ Coût licences Visual Studio Enterprise — mitigé par Rider/licences open source (VS Community pour OSS).

## Alternatives considérées

- **Java 21 / Spring Boot** : très robuste, HAPI FHIR natif — retenu comme alternative si l'équipe Java est plus forte ; skills `java-architect` disponibles.
- **Node/TypeScript (NestJS)** : rapide à démarrer, mais moins adapté au cœur clinique enterprise réglementé — réservé aux outils internes.
- **Python (FastAPI/Django) pour tout** : excellent pour l'IA, insuffisant seul pour le cœur clinique transactionnel — rôle : services IA uniquement.
