# ADR-003 — Client Windows : WinUI 3 / Windows App SDK

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, lead Windows, UX lead

## Contexte

L'application de travail clinique tourne sur des **postes Windows des CHU/CHSLD** : Windows 10 (2004+) et Windows 11. Elle doit être **native, performante, accessible (Narrator), packagée proprement (MSIX)** et offrir le **fenêtrage moderne Windows 11** (Snap Layouts, onglets de dossiers).

## Décision

Le client Windows est une application **WinUI 3 / Windows App SDK 1.6+ (.NET 9, C#)** :

- **Fluent Design (Windows 11)** : Mica/Acrylic, coins arrondis, animations implicites, Fluent System Icons.
- **Fenêtrage moderne** : `AppWindow`, barre de titre personnalisée, **TabView** (onglets = dossiers patients), Snap Layouts, restauration de session, multi-fenêtres (bi-écran).
- **Cibles** : Windows 10 version 2004 (build 19041) et ultérieur ; Windows 11 optimisé.
- **Packaging** : **MSIX** (auto-contenu Windows App SDK), signature Authenticode, distribution Store/sideload/**Intune** (ADR-007).
- **Sécurité** : Windows Hello (biométrie), DPAPI + AES-256 local, AppContainer, cache offline chiffré (SQLCipher).

## Conséquences

- ✅ UX native Windows 11 de premier plan (différenciateur vs DME vieillissants/WPF/électron).
- ✅ Performance et intégration OS (notifications, partage, biométrie, Snap Layouts).
- ✅ Packaging/déploiement entreprise (MSIX + MDM) professionnel.
- ⚠️ Courbe WinUI 3/XAML — mitigée par les skills `microsoft/win-dev-skills`, `openai/skills/winui-app`, `wshaddix/dotnet-skills` (chapitre 12).
- ⚠️ Support de Windows 10 2004+ à maintenir (fin de support Windows 10 : octobre 2025 — planifier la montée Windows 11 des parcs hospitaliers).

## Alternatives considérées

- **WPF** : mature mais vieillissante (pas de Fluent 2/Windows 11 natif) — rejetée (migration WPF→WinUI 3 étudiée pour du legacy).
- **.NET MAUI** : multiplateforme, mais rendu moins « natif Windows 11 » et perf inférieure pour poste clinique lourd — rejeté pour le client lourd Windows.
- **Electron/React** : cohérence web, mais consommation mémoire/énergie et intégration OS inférieures — rejeté pour l'app clinique (retenu pour le web/PWA).
- **UWP** : morte — rejetée.
