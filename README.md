# 🤖 Soul Machine Roblox (Brotato / Mecha Swarm)

> Transcription complète en Luau / Roblox du jeu Steam **Soul Machine** (TheSwarm).

---

## ⚡ Synchronisation Roblox Studio (Rojo)

Le projet est entièrement configuré avec **Rojo 7.7.1**.

### Option 1 : Synchronisation Live dans Roblox Studio
1. Lance la commande suivante dans ce dossier :
   ```bash
   rojo serve
   ```
2. Dans **Roblox Studio** (avec la place `BrotatoRoblox.rbxl` ouverte) :
   - Ouvre le plugin **Rojo**.
   - Indique le port **`34874`** dans le champ de port (pour éviter tout conflit avec tes autres fenêtres Studio qui utilisent les ports 34872 et 34873).
   - Clique sur **Connect**.
3. Tous les scripts se synchronisent automatiquement en temps réel !
4. Appuie sur **Play** (F5) pour jouer immédiatement.

### Option 2 : Compiler un fichier `.rbxl` autonome
```bash
rojo build default.project.json --output SoulMachineGame.rbxl
```

---

## 🎮 Fonctionnalités et Systèmes Transcrits

### 1. 🔫 Arsenal Complet (10 Armes)
- **Canon Impulsion (`StarterGun`)** : Arme cinétique de base, tirs rapides.
- **Fusil Gauss Lourd (`Rifle`)** : Cadence vive, haute pénétration et portée.
- **Canon Dispersion (`Pompe`)** : Salve en cône de plomb thermique à courte distance.
- **Lames Plasma (`Eventail`)** : Vagues énergétiques perçantes découpant les hordes.
- **Lance-Missiles Titan (`Rocket`)** : Roquette explosive créant une détonation AOE.
- **Tempête Noire (`DarkStorm`)** : Orbes tachyoniques tournoyant à 360° autour du Mécha.
- **Missile Pyros (`FireMissile`)** : Roquette guidée thermique appliquant l'effet Brûlure (DoT).
- **Micro-Essaim (`MissileMultiShot`)** : Salve de micro-missiles autoguidés ciblant plusieurs ennemis.
- **Déchargeur Tesla (`Taser`)** : Arcs électriques instantanés à haute fréquence.
- **Surcharge Nucléaire (`OverdriveWeapon`)** : Salve omnidirectionnelle déclenchée pendant l'Overdrive.

### 2. ⚡ Système d'Overdrive (Surcharge)
- Jauge d'Overdrive se chargeant en infligeant des dégâts et en subissant des chocs.
- Déclenchement via la touche **[ESPACE]** ou **[F]** (ou clic sur le bouton HUD).
- Déclenche une aura d'éclairs et libère une cadence de tir frénétique à 360°.

### 3. 🛡️ Statistiques et Formule d'Armure Fidèle
- **Max HP, Vitesse, Dégâts, Cadence, Armure, Coups Critiques, Rayon d'aspiration, Vol de Vie, Dégâts de Brûlure, Portée**.
- Formule d'armure : `Dégâts_Finaux = Dégâts_Bruts * (100 / (100 + Armure))`.
- Vol de vie dynamique et calcul de coups critiques (x2 dégâts).

### 4. 🎴 Évolution et Choix de Récompenses (Level-Up)
- Courbe d'XP avec surplus conservé et multiplicateur par niveau.
- Modal holographique à 3 cartes à chaque niveau :
  - **Amélioration d'arme** (Rangs 1 à 5).
  - **Cartes de stats**.
  - **Modules passifs réactifs** (système à accumulation d'événements).

### 5. 👾 Game Director (Directeur de Vagues)
- Économie basée sur des crédits / seconde avec accélération progressive.
- Vagues dynamiques : **ASSAUT (40s)** ➔ **NETTOYAGE** ➔ **PAUSE (5s)**.
- Vagues de Boss (Vague 5, 10...) avec le redoutable **Goliath Suprême (Boss)**.
- Apparition périodique du **Drone Porteur d'Orbe Doré** lâchant des méta-gemmes.

---

## 📁 Architecture du Code

- `src/Shared/`
  - `StatTypes.luau` : Énumérations et helpers mathématiques.
  - `WeaponsData.luau` : Définition des 10 armes et de leurs 5 rangs.
  - `PassivesData.luau` : Déclencheurs réactifs et générateurs procéduraux.
  - `EnemiesData.luau` : Bestiaire (Scout, Assault, Sniper, Juggernaut, Kamikaze, Boss).
  - `GameEvents.luau` : Bus d'événements découplé.
  - `Remotes.luau` : Gestionnaire de RemoteEvents.
  - `Signal.luau` : Implémentation Signal Luau native.
- `src/Server/`
  - `PlayerStatsManager.luau` : Stats, santé, blindage, Overdrive.
  - `WeaponService.luau` : Cadence, ciblage, visée automatique, patterns de tir.
  - `ProjectileService.luau` : Balistique cinématique, piercing, tirs guidés, explosions.
  - `EnemyService.luau` : IA par zones, dégâts de contact, DoT brûlure.
  - `EnemyDirector.luau` : Directeur économique des vagues et boss.
  - `XPService.luau` : Gemmes physiques, attraction magnétique, courbe de niveau.
  - `PassiveService.luau` : Moteur d'accumulation et déclenchement des passifs.
  - `RewardService.luau` : Tirage au sort des cartes de montée de niveau.
  - `ArenaBuilder.luau` : Génération de l'arène Cyberpunk (sol, lasers, néons).
  - `ServerInit.server.luau` : Point d'entrée serveur.
- `src/Client/`
  - `TopDownCamera.client.luau` : Caméra vue du dessus et visée mecha.
  - `ClientHUD.client.luau` : Interface complète (Vie, XP, Vague, Overdrive, Cartes).
  - `FloatingCombatText.client.luau` : Textes flottants de dégâts et critiques.
  - `ClientVFX.client.luau` : Effets visuels (explosions, aura Overdrive, morts).
