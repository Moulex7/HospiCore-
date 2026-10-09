# ADR-007 — Packaging Windows : MSIX

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, lead Windows, CISO

## Contexte

L'application Windows doit se déployer proprement dans des **parcs hospitaliers gérés** (milliers de postes, mises à jour contrôlées, désinstallation propre, sécurité). Windows 10 (2004+) et Windows 11 sont ciblés.

## Décision

Le client Windows est packagé en **MSIX** (`.msix`/`.msixbundle`), runtime **Windows App SDK auto-contenu**, signé **Authenticode** (EV recommandé) :

- **Cible** : `TargetDeviceFamily` Windows.Universal, **min 10.0.19041.0 (Windows 10 2004)** et ultérieur.
- **Identité de package** : `HospiCore`, Publisher (CN organisation), version sémantique 4-parties.
- **Capacités** : `internetClient`, `privateNetworkClientServer` (télésanté locale) ; principe du moindre privilège (pas de `runFullTrust` non justifié).
- **Mise à jour** : auto-update MSIX via App Installer ; déploiement **Intune/MDM** (CHU) ; Store (option grand public).
- **Désinstallation** : propre (pas de résidu), requis par les DSI hospitalières.
- **Taille** : objectif < 150 Mo (runtime auto-contenu).

## Conséquences

- ✅ Déploiement/désinstallation propres, mises à jour différentielles, isolation (AppContainer).
- ✅ Confiance : signature Authenticode + identité de package (anti-usurpation).
- ✅ Compatible gestion d'entreprise (Intune, SCCM, Store for Business).
- ⚠️ MSIX Core (pour très vieux Windows 10) en fallback de déploiement legacy.
- ⚠️ Certaines API legacy limitées en AppContainer — contournements documentés (broker processes si besoin, avec revue sécurité).

## Alternatives considérées

- **MSI (WiX)** : souple mais déploiement moins propre (résidus, conflits), pas d'auto-update moderne — rejeté.
- **ClickOnce** : simple mais déprécié pour les apps modernes, moins sécurisé — rejeté.
- **Microsoft Store seul** : excellent mais exclut le sideloading entreprise requis par les CHU — MSIX + canaux multiples retenu.
