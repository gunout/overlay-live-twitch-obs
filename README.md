<div align="center">

# 🎨 Twitch Overlay

**Overlay Twitch néon avec chat, alertes bits, top tippers et QR codes sociaux**

Un overlay complet, prêt à l'emploi, à coller directement dans OBS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D18-339933?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Twitch](https://img.shields.io/badge/Twitch-EventSub-9146FF?logo=twitch&logoColor=white)](https://dev.twitch.tv/docs/eventsub/)
[![OBS](https://img.shields.io/badge/OBS-Studio-302E31?logo=obsstudio&logoColor=white)](https://obsproject.com/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

[Fonctionnalités](#-fonctionnalités) · [Installation](#-installation) · [Configuration](#-configuration-twitch) · [OBS](#-intégration-obs) · [Dépannage](#-dépannage)

</div>

---

## SCREENSHOTS

<img width="1630" height="836" alt="Screenshot 2026-10-17 at 01-49-45 Aero Overlay — gleaphe313 (1920×1080)" src="https://github.com/user-attachments/assets/dc001241-dfbf-477f-a8f1-ff2df9181233" />

## ✨ Fonctionnalités

| | Fonctionnalité | Description |
|---|---|---|
| 💬 | **Chat Twitch** | Messages en direct, intégrés dans l'overlay |
| 💎 | **Alertes bits** | Animation néon déclenchée à chaque cheer |
| 🏆 | **Top tippers** | Classement en temps réel des meilleurs donateurs |
| 📊 | **Stats hebdomadaires** | Cumul des bits de la semaine, remis à zéro automatiquement |
| 🎯 | **Objectif personnalisable** | Barre de progression vers un objectif de bits |
| 📱 | **4 QR codes** | Twitch, YouTube, Instagram, Site web avec logos au centre |
| 🎨 | **Design Aero Glass** | Néon rose/cyan, effets de glow, animations fluides |
| ⚡ | **Temps réel** | WebSocket local, latence < 100 ms |
| 🔄 | **Reconnexion auto** | Reprend là où il s'est arrêté après une coupure |
| 🌐 | **Multi-réseaux** | Prêt pour Twitch, extensible YouTube et Kick |

---

## 📋 Prérequis

Avant de commencer, assure-toi d'avoir :

- ✅ **Node.js 18+** — [Télécharger](https://nodejs.org/)
- ✅ **OBS Studio 28+** — [Télécharger](https://obsproject.com/)
- ✅ **Un compte Twitch** avec la **2FA activée**
- ✅ **Git** (optionnel, pour cloner le repo)

Vérifie ta version de Node :

```bash
node --version
# Doit afficher v18.x.x ou supérieur
```

---

## 🚀 Installation

### 1. Cloner le repo

```bash
git clone https://github.com/TON-PSEUDO/twitch-overlay.git
cd twitch-overlay
```

Ou télécharge le ZIP et extrais-le.

### 2. Installer les dépendances

```bash
npm install
```

### 3. Configurer l'environnement

```bash
cp .env.example .env
```

Édite `.env` et remplis les 4 valeurs (voir [Configuration Twitch](#-configuration-twitch) ci-dessous).

### 4. Lancer le serveur

```bash
npm start
```

Tu dois voir :

```
🌐 http://localhost:3000
🔐 http://localhost:3000/login
📡 ws://localhost:8080
```

### 5. Autoriser Twitch (une seule fois)

Ouvre dans ton navigateur :

```
http://localhost:3000/login
```

Accepte les permissions. Tu verras :

```
✅ Autorisation réussie !
✅ EventSub connecté. Session: xxxx
  ✅ Abonné: channel.follow
  ✅ Abonné: channel.subscribe
  ✅ Abonné: channel.cheer
  ✅ Abonné: channel.chat.message
```

### 6. Ajouter à OBS

Voir [Intégration OBS](#-intégration-obs) ci-dessous.

---

## 🔑 Configuration Twitch

### Étape 1 — Créer une application Twitch

1. Va sur **[dev.twitch.tv/console](https://dev.twitch.tv/console)**
2. Clique sur **"Register Your Application"**
3. Remplis le formulaire :

| Champ | Valeur |
|---|---|
| **Name** | `mon-overlay` (unique) |
| **OAuth Redirect URL** | `http://localhost:3000/callback` |
| **Category** | `Application Integration` |
| **Client Type** | `Confidential` |

4. Clique sur **"Create"**

### Étape 2 — Récupérer les identifiants

1. Clique sur **"Manage"** sur ton application
2. Copie le **Client ID**
3. Clique sur **"New Secret"** → copie le **Client Secret**

⚠️ **Le Client Secret ne s'affiche qu'une seule fois.** Copie-le immédiatement.

### Étape 3 — Trouver ton ID numérique

Ton **ID numérique** Twitch n'est **pas** ton pseudo. Trouve-le sur :

👉 [StreamWeasels — Twitch ID Converter](https://www.streamweasels.com/support/convert-twitch-username-to-user-id/)

Entre ton pseudo → copie le nombre qui s'affiche (ex : `123456789`).

### Étape 4 — Remplir `.env`

```env
TWITCH_CLIENT_ID=abc123def456...
TWITCH_CLIENT_SECRET=xyz789...
TWITCH_BROADCASTER_ID=123456789
TWITCH_BROADCASTER_NAME=ton_pseudo
PORT=3000
```

---

## 🖥️ Intégration OBS

### Ajouter l'overlay

1. Dans OBS, panneau **Sources** → **+** → **Navigateur**
2. Nom : `Twitch Overlay`
3. **URL** : `http://localhost:3000/overlays.html`
4. **Largeur** : `1920` — **Hauteur** : `1080`
5. **Décoche** ☐ "Arrêter la source quand elle n'est plus visible"
6. Clique sur **OK**

### Résolution OBS recommandée

| Paramètre | Valeur |
|---|---|
| **Résolution de base** | 1920×1080 |
| **Résolution de sortie** | 1920×1080 (ou 1280×720) |
| **FPS** | 30 ou 60 |

---

## 🎮 Paramètres URL

Ajoute ces paramètres à l'URL OBS pour personnaliser l'affichage :

| Paramètre | Effet |
|---|---|
| `?clean=1` | Mode épuré (masque chat + panneaux) |
| `?mini=1` | Colonnes latérales réduites |
| `?ultra=1` | Objectif seul en bas d'écran |
| `?fresh=1` | Reset de la session au démarrage |
| `?freshweek=1` | Reset des stats hebdomadaires |
| `?test=1` | Mode démo (sans connexion Twitch) |

**Exemple** :

```
http://localhost:3000/overlays.html?mini=1&test=1
```

### Raccourcis clavier (dans l'overlay)

| Touche | Action |
|---|---|
| **P** | Pause / Reprendre |
| **E** | Exporter les stats en CSV |
| **U** | Mode ultra-minimal |
| **M** | Mode mini |

---

## ⚙️ Personnalisation

### Changer les QR codes

Édite `overlays.html`, cherche le bloc `QR_CONFIGS` :

```javascript
const QR_CONFIGS = [
  { id: 'qr-twitch',    url: 'https://twitch.tv/TON-PSEUDO' },
  { id: 'qr-youtube',   url: 'https://youtube.com/@TON-PSEUDO' },
  { id: 'qr-instagram', url: 'https://instagram.com/TON-PSEUDO' },
  { id: 'qr-website',   url: 'https://ton-site.com' }
];
```

### Changer l'objectif de bits

Cherche `GOAL_AMOUNT` dans `overlays.html` :

```javascript
const GOAL_AMOUNT = 1000;  // Change cette valeur
```

### Changer les couleurs

Dans le CSS, modifie les variables `:root` :

```css
:root {
  --girl-1: #ff1493;   /* Rose vif */
  --boy-1: #00f5ff;    /* Cyan */
  --gold-2: #ffd700;   /* Or */
  --twitch-1: #9146ff; /* Violet Twitch */
}
```

---

## 📂 Structure du projet

```
twitch-overlay/
├── server.js          # Serveur Node.js (EventSub + WebSocket)
├── overlays.html      # Overlay HTML pour OBS
├── package.json       # Dépendances et scripts
├── .env.example       # Template de configuration
├── .env               # Ta config (ne pas commiter)
├── .tokens.json       # Tokens OAuth (généré auto)
├── start.sh           # Lanceur Mac/Linux
├── start.bat          # Lanceur Windows
└── sounds/            # Fichiers audio (optionnel)
```

---

## 🔧 Dépannage

<details>
<summary><strong>⚠️ subscription missing proper authorization</strong></summary>

Ton token n'a pas les bons scopes. Solution :

```bash
rm .tokens.json
npm start
# Va sur http://localhost:3000/login et réautorise
```

</details>

<details>
<summary><strong>❌ redirect_mismatch</strong></summary>

L'URL dans la console Twitch ne correspond pas. Vérifie :

- Pas de slash final : `callback` et **pas** `callback/`
- Protocole **HTTP** (pas HTTPS)
- Port exact : `3000` si `PORT=3000`

</details>

<details>
<summary><strong>❌ EADDRINUSE (port déjà utilisé)</strong></summary>

Un autre programme utilise le port 3000. Change dans `.env` :

```env
PORT=3001
```

</details>

<details>
<summary><strong>🖥️ L'overlay ne s'affiche pas dans OBS</strong></summary>

Vérifie :
1. Le serveur Node tourne (`npm start`)
2. L'URL est bien `http://localhost:3000/overlays.html`
3. La case "Fichier local" est **décochée**
4. Le statut affiche `En direct` (vert)

</details>

<details>
<summary><strong>💬 Le chat n'apparaît pas</strong></summary>

Vérifie que ton token a les scopes `user:read:chat` et `user:bot`. Si non :

```bash
rm .tokens.json
npm start
# Réautorise sur /login
```

</details>

---

## 🛠️ Stack technique

| Composant | Technologie |
|---|---|
| **Runtime** | Node.js 18+ |
| **Serveur HTTP** | Express |
| **WebSocket** | ws |
| **Twitch API** | EventSub WebSocket |
| **Auth** | OAuth 2.0 Authorization Code |
| **QR Codes** | qrcode.js + API fallback |
| **Design** | CSS pur + Aero Glass |

---

## 🤝 Contribution

Les contributions sont les bienvenues !

1. Fork le projet
2. Crée une branche (`git checkout -b feature/AmazingFeature`)
3. Commit tes changements (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Ouvre une Pull Request

---

## 📝 License

Ce projet est sous licence **MIT**. Voir [LICENSE](LICENSE) pour plus de détails.

---

## 🙏 Remerciements

- [Twitch EventSub](https://dev.twitch.tv/docs/eventsub/) pour l'API temps réel
- [qrcode.js](https://github.com/soldair/node-qrcode) pour la génération des QR
- [Simple Icons](https://simpleicons.org/) pour les logos des réseaux
- La communauté OBS pour le support continu

---

<div align="center">

**⭐ Si ce projet t'a aidé, mets une étoile sur GitHub !**

Fait avec 💜 et 💙

</div>
