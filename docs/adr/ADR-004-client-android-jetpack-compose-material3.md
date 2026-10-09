# ADR-004 — Client Android : Kotlin / Jetpack Compose / Material 3 (Material You)

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, lead Android, UX lead, comité médical

## Contexte

HospiCore sert les **soignants mobiles** (tablettes de soins en CHSLD : MAR, signes vitaux) et les **patients** (portail mobile). L'UX doit être **moderne (Material You)**, **adaptative** (téléphones/tablettes/pliables) et distribuable via **Play Store + canaux internes (MDM des hôpitaux)**.

## Décision

Le client Android est en **Kotlin 2.x + Jetpack Compose + Material 3 (Material You)** :

- **Cible Android 17 (API 37)**, `minSdk 29`, dynamic color (Monet) sur Android 12+.
- **Material You** : couleurs dynamiques, thème clair/sombre, composants adaptatifs (`WindowSizeClass`).
- **Sécurité** : Android Keystore, BiometricPrompt, chiffrement local (Jetpack Security + SQLCipher), certificate pinning, `FLAG_SECURE` sur écrans sensibles.
- **Offline-first** : Room (chiffré) + WorkManager (ADR-008).
- **Distribution** : **AAB** (Play Store) + APK/AAB signé pour MDM interne (Intune, Knox, Workspace ONE).
- **Partage** : logique métier pure en **Kotlin Multiplatform (KMP)** avec le backend JVM (Phase 4).

## Conséquences

- ✅ UX Android moderne de premier plan, accessible (TalkBack), performante.
- ✅ Distribution flexible (public + interne CHU/CHSLD).
- ✅ Base Kotlin partageable (KMP) avec d'autres plateformes.
- ⚠️ Fragmentation (constructeurs, MDM) — mitigée par tests sur parc de référence (Samsung/S Lenovo tablettes soins) et skills `krutikjain/android-agent-skills`.

## Alternatives considérées

- **.NET MAUI** : partage C# avec Windows, mais rendu moins Material You natif et écosystème capteurs santé inférieur — rejeté pour Android.
- **Flutter** : bon compromis multiplateforme, mais écosystème santé/sécurité mobile et Material You moins matures — rejeté.
- **React Native** : proche du web, mais perf listes cliniques et intégration biométrie/keystore inférieures — rejeté.
