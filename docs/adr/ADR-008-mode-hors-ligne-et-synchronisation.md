# ADR-008 — Mode hors-ligne & synchronisation (offline-first)

- **Date** : 2026-10-09
- **Statut** : Accepté
- **Décideurs** : CTO, architecte logiciel, CISO, comité médical

## Contexte

Un DME indisponible met des **vies en danger** (chapitre 09, risque R2). Les réseaux hospitaliers/CHSLD peuvent être instables (sous-sols, régions éloignées, pannes). Les soignants doivent pouvoir **continuer à travailler** (lire le dossier, saisir notes/MAR/signes vitaux) hors connexion, puis synchroniser.

## Décision

HospiCore adopte une stratégie **offline-first** sur les clients lourds (Windows/Android) :

- **Cache lecture local chiffré** : dossiers récemment consultés (SQLCipher — Windows ; Room chiffré — Android), TTL 8 h, effacement à la déconnexion si la politique du tenant l'exige.
- **File d'écriture locale chiffrée** : brouillons de notes, saisies MAR, signes vitaux en attente (ordre chronologique, horodatage client signé).
- **Synchronisation** : à la reconnexion — envoi des écritures (API FHIR), revalidation serveur (conflits « dernier auteur averti », notification à l'utilisateur, **jamais d'écrasement silencieux**), rafraîchissement du cache.
- **Indicateurs UI** : bannière « Mode hors-ligne — X éléments en attente » (InfoBar Windows / Snackbar-Banner Android).
- **Web (PWA)** : lecture seule en cache chiffré (IndexedDB + WebCrypto AES-GCM) ; pas d'écriture offline (le portail reste Secondaire hors-ligne).
- **Sécurité** : clés locales protégées (DPAPI/Windows Hello — Windows ; Android Keystore — Android) ; aucune clé en clair ; effacement à distance (wipe) via MDM.

## Conséquences

- ✅ Continuité des soins en cas de panne réseau/indisponibilité (résilience R2, RTO client = immédiat en lecture).
- ✅ Expérience soignant fluide (pas d'« app qui bloque »).
- ⚠️ Complexité de la résolution de conflits — mitigée par des règles claires + information utilisateur.
- ⚠️ Données en cache local = surface d'attaque — mitigée par le chiffrement local + TTL + FLAG_SECURE + wipe MDM.

## Alternatives considérées

- **Aucune capacité offline** : simple, mais inacceptable pour la continuité des soins — rejeté.
- **Offline complet (lecture/écriture totale)** : trop risqué (conflits massifs, cohérence clinique) — limité au périmètre « dossier du jour ».
