# 🏦 sBanking - Système Bancaire Avancé pour FiveM (ESX)

Bienvenue sur le dépôt de **sBanking**, un système bancaire complet, immersif et moderne pour serveurs FiveM sous le framework ESX. Ce script repousse les limites des banques traditionnelles en intégrant de vraies mécaniques de compte partagé, de cartes physiques volables et une interface utilisateur (UI) hautement personnalisable.

---

## ✨ Fonctionnalités Principales

### 💳 Cartes Bancaires Physiques (RP Illégal & Légal)
* **Objet en Jeu** : Votre compte est lié à un objet "Carte Bancaire" dans votre inventaire (`ox_inventory`).
* **Risque de Vol** : Si un joueur vous dérobe votre carte, il peut l'utiliser à n'importe quel distributeur (ATM) pour vider votre compte (même si vous êtes déconnecté !).
* **Système d'Opposition** : En cas de vol, rendez-vous à la banque centrale pour "renouveler" votre carte. L'ancienne sera instantanément bloquée et rendue inutilisable par le voleur.

### 👥 Comptes Partagés (Gangs, Entreprises, Familles)
* **Création Facile** : Créez des comptes communs en un clic.
* **Gestion des Membres** : Ajoutez ou retirez des membres via leur ID joueur. Seul le propriétaire peut gérer les accès.
* **Historique Transparent** : Fini les vols en interne ! Chaque dépôt, retrait ou virement sur le compte partagé est consigné dans un historique détaillé (Qui, Quand, Combien).

### 📱 Interface Utilisateur (NUI) Moderne
* **Design Épuré** : Animations fluides, icônes modernes et notifications intégrées.
* **Personnalisation** : Les joueurs peuvent choisir parmi plusieurs thèmes (Dark, Light, Océan, Émeraude, Sunset, Purple) sauvegardés individuellement.
* **Virements Rapides** : Transférez de l'argent aux joueurs en ligne directement via l'interface.

---

## 🛠️ Dépendances Requises

Pour que ce script fonctionne correctement, vous devez impérativement avoir installé et configuré les ressources suivantes :

* `es_extended` (Framework de base ESX)
* `ox_inventory` (Pour la gestion physique des cartes bancaires)
* `ox_target` (Pour l'interaction avec les distributeurs/ATMs)
* `ox_lib` (Pour les menus d'interaction contextuels)
* `oxmysql` (Pour la base de données)

---

## 📦 Installation

1. **Téléchargez** l'archive du script.
2. **Extrayez** le dossier `sBanking` dans le dossier `resources` de votre serveur.
3. **Importez les fichiers SQL** fournis (si présents) ou assurez-vous que le script crée les tables automatiquement au démarrage.
4. **Ajoutez l'item** de la carte bancaire dans la configuration de votre `ox_inventory` (généralement dans `data/items.lua`).
   ```lua
   ['bank_card'] = {
       label = 'Carte Bancaire',
       weight = 10,
       stack = false,
       close = true,
       description = 'Une carte bancaire personnelle.'
   }
   ```
5. **Ajoutez** `ensure sBanking` dans votre fichier `server.cfg`.
6. **Redémarrez** votre serveur.

---

## 📚 Configuration (`config.lua` / `config.js`)

N'hésitez pas à explorer les fichiers de configuration pour adapter le script à votre serveur :
* Modèles d'ATMs utilisables.
* Activer/désactiver l'utilisation des cartes volées quand le propriétaire est hors-ligne.
* Raccourcis de touches, etc.

---

## 💬 Support & Contact

Vous rencontrez un problème lors de l'installation ? Vous avez une idée d'amélioration ou vous avez trouvé un bug ?

N'hésitez pas à rejoindre notre serveur Discord pour obtenir de l'aide de la communauté ou directement du développeur.

🔗 **[Rejoindre le Discord Support](https://discord.gg/PxN5xMBbGY)**

---
*Développé avec ❤️ pour la communauté FiveM.*
