#!/usr/bin/env bash
set -e

echo ""
echo "=========================================================="
echo "   TWITCH OVERLAY GENERATOR"
echo "=========================================================="
echo ""

# Prérequis
if ! command -v node &> /dev/null; then
    echo "ERREUR: Node.js n'est pas installé."
    echo "Télécharge-le sur https://nodejs.org/"
    exit 1
fi
echo "[OK] Node.js $(node --version)"
echo "[OK] npm $(npm --version)"
echo ""

# Config
echo "=== Configuration ==="
echo "Appuie sur Entrée pour accepter la valeur par défaut."
echo ""

read -p "Nom du dossier [twitch-overlay] : " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-twitch-overlay}

read -p "Ton pseudo Twitch (obligatoire) : " TWITCH_NAME

if [ -z "$TWITCH_NAME" ]; then
    echo "ERREUR: le pseudo Twitch est obligatoire."
    exit 1
fi

read -p "Handle YouTube (ou Entrée pour vide) : " YOUTUBE_HANDLE
read -p "Handle Instagram (ou Entrée pour vide) : " INSTAGRAM_HANDLE
read -p "URL de ton site (ou Entrée pour vide) : " WEBSITE_URL
read -p "Objectif en bits [1000] : " GOAL_AMOUNT
GOAL_AMOUNT=${GOAL_AMOUNT:-1000}
read -p "Port HTTP [3000] : " PORT
PORT=${PORT:-3000}

echo ""
echo "=== Récapitulatif ==="
echo "  Dossier   : $PROJECT_NAME"
echo "  Twitch    : $TWITCH_NAME"
echo "  YouTube   : ${YOUTUBE_HANDLE:-non renseigné}"
echo "  Instagram : ${INSTAGRAM_HANDLE:-non renseigné}"
echo "  Site web  : ${WEBSITE_URL:-non renseigné}"
echo "  Objectif  : $GOAL_AMOUNT bits"
echo "  Port      : $PORT"
echo ""

read -p "Confirmer et créer le projet ? (o/n) : " CONFIRM
if [ "$CONFIRM" != "o" ] && [ "$CONFIRM" != "O" ] && [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Annulé."
    exit 0
fi

# Création
echo ""
echo "=== Création ==="

if [ -d "$PROJECT_NAME" ]; then
    echo "ERREUR: le dossier '$PROJECT_NAME' existe déjà."
    exit 1
fi

mkdir -p "$PROJECT_NAME/sounds"
cd "$PROJECT_NAME"
echo "[OK] Dossier créé"

# package.json
cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Overlay Twitch néon",
  "type": "module",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node --watch server.js"
  },
  "license": "MIT",
  "engines": { "node": ">=18.0.0" },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "ws": "^8.18.0"
  }
}
EOF
echo "[OK] package.json"

cat > .gitignore << 'EOF'
node_modules/
.env
.tokens.json
.DS_Store
Thumbs.db
*.log
npm-debug.log*
.vscode/
.idea/
*.swp
EOF
echo "[OK] .gitignore"

cat > .env.example << EOF
TWITCH_CLIENT_ID=ton_client_id_ici
TWITCH_CLIENT_SECRET=ton_client_secret_ici
TWITCH_BROADCASTER_ID=123456789
TWITCH_BROADCASTER_NAME=$TWITCH_NAME
PORT=$PORT
EOF
echo "[OK] .env.example"

cat > .env << EOF
TWITCH_CLIENT_ID=REMPLACE_MOI
TWITCH_CLIENT_SECRET=REMPLACE_MOI
TWITCH_BROADCASTER_ID=REMPLACE_MOI
TWITCH_BROADCASTER_NAME=$TWITCH_NAME
PORT=$PORT
EOF
echo "[OK] .env"

cat > LICENSE << 'EOF'
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
EOF
echo "[OK] LICENSE"

cat > README.md << EOF
# Twitch Overlay

Overlay Twitch néon avec chat, alertes bits et QR codes.

## Installation

\`\`\`bash
npm install
cp .env.example .env
# Édite .env avec tes identifiants
npm start
\`\`\`

## Configuration Twitch

1. https://dev.twitch.tv/console
2. Register Your Application
3. OAuth Redirect URL: http://localhost:$PORT/callback
4. Category: Application Integration
5. Type: Confidential
6. Copie Client ID + Secret dans .env
7. Trouve ton ID numérique sur StreamWeasels
8. Lance npm start
9. http://localhost:$PORT/login

## OBS

- Source Navigateur: http://localhost:$PORT/overlays.html
- 1920x1080
EOF
echo "[OK] README.md"

# server.js (copie exacte du fichier server.js)
cat > server.js << 'SERVEREOF'
import 'dotenv/config';
import express from 'express';
import { WebSocketServer, WebSocket } from 'ws';
import { createServer } from 'http';
import fs from 'fs';
import path from 'path';

const TWITCH_CLIENT_ID = (process.env.TWITCH_CLIENT_ID || '').trim();
const TWITCH_CLIENT_SECRET = (process.env.TWITCH_CLIENT_SECRET || '').trim();
const TWITCH_BROADCASTER_ID = (process.env.TWITCH_BROADCASTER_ID || '').trim();
const PORT = parseInt((process.env.PORT || '3000').trim(), 10);
const REDIRECT_URI = `http://localhost:${PORT}/callback`;
const SCOPES = ['moderator:read:followers','channel:read:subscriptions','bits:read','channel:read:redemptions','user:read:chat','user:bot'];
const TOKEN_FILE = path.join(process.cwd(), '.tokens.json');
let userAccessToken = null, refreshToken = null, tokenExpiry = 0;

function loadTokens() {
  try { const d = JSON.parse(fs.readFileSync(TOKEN_FILE,'utf-8')); userAccessToken=d.access_token; refreshToken=d.refresh_token; tokenExpiry=d.expiry||0; console.log('🔑 Tokens chargés'); }
  catch { console.log('ℹ️  Aucun token sauvegardé.'); }
}
function saveTokens(data) {
  const p = { access_token: data.access_token, refresh_token: data.refresh_token, expiry: Date.now() + data.expires_in*1000 };
  fs.writeFileSync(TOKEN_FILE, JSON.stringify(p,null,2));
  userAccessToken=p.access_token; refreshToken=p.refresh_token; tokenExpiry=p.expiry;
}
async function refreshUserToken() {
  if (!refreshToken) throw new Error('Pas de refresh token');
  const res = await fetch('https://id.twitch.tv/oauth2/token', { method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:new URLSearchParams({ client_id:TWITCH_CLIENT_ID, client_secret:TWITCH_CLIENT_SECRET, grant_type:'refresh_token', refresh_token:refreshToken }) });
  const data = await res.json();
  if (!res.ok) throw new Error('Refresh échoué');
  saveTokens(data); return data.access_token;
}
async function getValidToken() { if (userAccessToken && Date.now() < tokenExpiry - 60000) return userAccessToken; return await refreshUserToken(); }
function getAuthUrl() { return 'https://id.twitch.tv/oauth2/authorize?' + new URLSearchParams({ client_id:TWITCH_CLIENT_ID, redirect_uri:REDIRECT_URI, response_type:'code', scope:SCOPES.join(' ') }); }

const app = express();
app.use(express.static('.'));
app.get('/login', (req, res) => res.redirect(getAuthUrl()));
app.get('/callback', async (req, res) => {
  const { code, error, error_description } = req.query;
  if (error) return res.status(400).send(`Erreur: ${error} - ${error_description}`);
  if (!code) return res.status(400).send('Pas de code');
  try {
    const r = await fetch('https://id.twitch.tv/oauth2/token', { method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:new URLSearchParams({ client_id:TWITCH_CLIENT_ID, client_secret:TWITCH_CLIENT_SECRET, code, grant_type:'authorization_code', redirect_uri:REDIRECT_URI }) });
    const data = await r.json();
    if (!r.ok) throw new Error(JSON.stringify(data));
    saveTokens(data);
    res.send('<html><body style="font-family:sans-serif;background:#111;color:#0f0;padding:40px;text-align:center"><h1>✅ Autorisation réussie !</h1><p>Tu peux fermer cette page.</p><script>setTimeout(()=>window.close(),3000)</script></body></html>');
    setTimeout(() => connectEventSub().catch(console.error), 1000);
  } catch (err) { res.status(500).send('Erreur: ' + err.message); }
});
app.get('/health', (req, res) => res.json({ ok:true, clients:clients.size }));
app.get('/favicon.ico', (req, res) => res.status(204).end());

const wss = new WebSocketServer({ port: 8080 });
const clients = new Set();
wss.on('connection', (ws) => { clients.add(ws); console.log(`🖥️  Overlay connecté (${clients.size})`); ws.on('close', () => clients.delete(ws)); });
function broadcast(e) { const p = JSON.stringify(e); for (const c of clients) if (c.readyState === WebSocket.OPEN) c.send(p); }

let eventSubWs = null, sessionId = null, keepaliveTimer = null;
async function connectEventSub() {
  const token = await getValidToken();
  eventSubWs = new WebSocket('wss://eventsub.wss.twitch.tv/ws');
  eventSubWs.on('message', async (raw) => {
    const msg = JSON.parse(raw.toString());
    clearTimeout(keepaliveTimer);
    keepaliveTimer = setTimeout(() => eventSubWs.close(), 15000);
    if (msg.metadata.message_type === 'session_welcome') { sessionId = msg.payload.session.id; await subscribeToEvents(sessionId, token); }
    else if (msg.metadata.message_type === 'notification') handleTwitchEvent(msg.metadata.subscription_type, msg.payload.event);
    else if (msg.metadata.message_type === 'session_reconnect') { const u = msg.payload.session.reconnect_url; eventSubWs.close(); setTimeout(() => connectToUrl(u, token), 1000); }
  });
  eventSubWs.on('close', () => setTimeout(() => connectEventSub().catch(console.error), 5000));
}
function connectToUrl(url, token) {
  const ws = new WebSocket(url);
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    if (msg.metadata.message_type === 'session_welcome') { sessionId = msg.payload.session.id; subscribeToEvents(sessionId, token); }
    else if (msg.metadata.message_type === 'notification') handleTwitchEvent(msg.metadata.subscription_type, msg.payload.event);
  });
  eventSubWs = ws;
}
async function subscribeToEvents(sid, token) {
  const subs = [
    { type:'channel.follow', version:'2', condition:{ broadcaster_user_id:TWITCH_BROADCASTER_ID, moderator_user_id:TWITCH_BROADCASTER_ID } },
    { type:'channel.subscribe', version:'1', condition:{ broadcaster_user_id:TWITCH_BROADCASTER_ID } },
    { type:'channel.subscription.gift', version:'1', condition:{ broadcaster_user_id:TWITCH_BROADCASTER_ID } },
    { type:'channel.cheer', version:'1', condition:{ broadcaster_user_id:TWITCH_BROADCASTER_ID } },
    { type:'channel.raid', version:'1', condition:{ to_broadcaster_user_id:TWITCH_BROADCASTER_ID } },
    { type:'channel.chat.message', version:'1', condition:{ broadcaster_user_id:TWITCH_BROADCASTER_ID, user_id:TWITCH_BROADCASTER_ID } }
  ];
  for (const s of subs) {
    try {
      const r = await fetch('https://api.twitch.tv/helix/eventsub/subscriptions', { method:'POST', headers:{ 'Client-Id':TWITCH_CLIENT_ID, 'Authorization':`Bearer ${token}`, 'Content-Type':'application/json' }, body: JSON.stringify({ type:s.type, version:s.version, condition:s.condition, transport:{ method:'websocket', session_id:sid } }) });
      const d = await r.json();
      if (r.ok) console.log(`  ✅ ${s.type}`); else console.warn(`  ⚠️  ${s.type}: ${d.message}`);
    } catch (e) { console.error(`  ❌ ${s.type}`); }
  }
}
function handleTwitchEvent(subType, e) {
  let p = null;
  if (subType === 'channel.follow') p = { type:'follow', user:e.user_name };
  else if (subType === 'channel.subscribe') p = { type:'subscribe', user:e.user_name };
  else if (subType === 'channel.subscription.gift') p = { type:'subgift', user:e.user_name };
  else if (subType === 'channel.cheer') p = { type:'cheer', user:e.is_anonymous?'Anonyme':e.user_name, bits:e.bits, message:e.message||'' };
  else if (subType === 'channel.raid') p = { type:'raid', user:e.from_broadcaster_user_name, viewers:e.viewers };
  else if (subType === 'channel.chat.message') p = { type:'chat', user:e.chatter_user_name, message:e.message?.text||'' };
  if (p) broadcast(p);
}

createServer(app).listen(PORT, () => {
  console.log(`🌐 http://localhost:${PORT}`);
  console.log(`🔐 http://localhost:${PORT}/login`);
  console.log(`📡 ws://localhost:8080`);
});

loadTokens();
if (userAccessToken || refreshToken) connectEventSub().catch(e => console.log('👉 http://localhost:' + PORT + '/login'));
else console.log(`\n👉 Ouvre http://localhost:${PORT}/login\n`);
SERVEREOF
echo "[OK] server.js"

# overlays.html — version courte
TWITCH_URL="https://twitch.tv/${TWITCH_NAME}"
YOUTUBE_URL="${YOUTUBE_HANDLE:+https://youtube.com/@${YOUTUBE_HANDLE}}"
INSTAGRAM_URL="${INSTAGRAM_HANDLE:+https://instagram.com/${INSTAGRAM_HANDLE}}"
WEBSITE_URL_FINAL="${WEBSITE_URL:-https://twitch.tv/${TWITCH_NAME}}"

cat > overlays.html << HTMLEOF
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Overlay — $TWITCH_NAME</title>
<script src="https://cdn.jsdelivr.net/npm/qrcode@1.5.3/build/qrcode.min.js"><\/script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{width:1920px;height:1080px;font-family:'Segoe UI',system-ui,sans-serif;background:transparent;overflow:hidden;color:#fff;user-select:none}
#overlay{position:fixed;inset:0;pointer-events:none;z-index:1}
.glass{border-radius:16px;border:2px solid transparent;background:linear-gradient(180deg,rgba(255,255,255,0.08),transparent 65%) padding-box,linear-gradient(120deg,rgba(255,20,147,0.95),rgba(0,245,255,0.95)) border-box;background-color:rgba(0,0,0,0.08);box-shadow:0 0 10px rgba(255,20,147,0.55),0 0 14px rgba(0,245,255,0.45)}
#top-row{position:absolute;top:20px;left:20px;right:20px;display:flex;justify-content:space-between;gap:24px;z-index:2}
#top-bar{flex:1;padding:14px 24px;max-width:800px}
.goal-item{display:flex;align-items:center;gap:18px}
.goal-name{font-size:16px;font-weight:800;min-width:130px}
.goal-bar-bg{flex:1;height:16px;background:rgba(0,0,0,0.35);border-radius:8px;overflow:hidden}
.goal-bar-fill{height:100%;width:0%;background:linear-gradient(90deg,#ff1493,#6bfaff);transition:width 0.9s}
.goal-val{font-size:20px;font-weight:900;min-width:130px;text-align:right}
#tip-counter{padding:14px 28px;text-align:center;min-width:200px}
#tip-counter .label{font-size:14px;letter-spacing:4px;font-weight:800}
#tip-counter .value{font-size:44px;font-weight:900}
#qr-panel{position:absolute;top:130px;left:20px;width:400px;display:grid;grid-template-columns:1fr 1fr;gap:10px;z-index:2}
.qr-item{display:flex;flex-direction:column;align-items:center;gap:6px;padding:8px;border-radius:12px;background:rgba(0,0,0,0.15);border:1.5px solid rgba(255,255,255,0.15)}
.qr-box{position:relative;width:100px;height:100px;background:#fff;border-radius:8px;padding:4px}
.qr-box img{width:100%;height:100%;image-rendering:pixelated}
.qr-logo{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:26px;height:26px;background:#fff;border-radius:5px;padding:3px}
.qr-logo svg{width:100%;height:100%;display:block}
.qr-label{font-size:12px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase}
#left-column{position:absolute;top:430px;left:20px;width:400px;bottom:100px;display:flex;flex-direction:column;gap:12px;z-index:2}
#chat-panel{flex:1;padding:16px 20px;border-radius:16px;background:rgba(0,0,0,0.15);border:2px solid rgba(255,255,255,0.15);display:flex;flex-direction:column;overflow:hidden}
#chat-panel .panel-title{font-size:14px;letter-spacing:4px;font-weight:800;text-align:center;margin-bottom:10px}
#chat-messages{flex:1;display:flex;flex-direction:column;gap:5px;overflow-y:auto}
.chat-msg{font-size:17px;line-height:1.3}
.chat-msg .chat-user{font-weight:800;color:#b380ff;margin-right:6px}
#event-feed{max-height:160px;display:flex;flex-direction:column-reverse;gap:6px;overflow:hidden}
.event-item{padding:8px 14px;border-radius:10px;font-size:15px;display:flex;gap:8px;border:2px solid transparent;background:linear-gradient(180deg,rgba(255,255,255,0.05),transparent 60%) padding-box,linear-gradient(120deg,#00f5ff,#6bfaff) border-box}
.event-user{font-weight:800;color:#6bfaff}
#right-panels{position:absolute;top:130px;right:-20px;width:320px;bottom:100px;display:flex;flex-direction:column;gap:12px;z-index:2}
.panel{padding:12px 16px;border-radius:14px}
.panel-title{font-size:14px;letter-spacing:4px;font-weight:800;text-align:center;margin-bottom:10px}
.tipper-row,.history-row{display:flex;gap:10px;padding:5px 4px;font-size:18px}
.tipper-amount,.history-amount{font-weight:900;color:#6bfaff;margin-left:auto}
.tipper-empty{text-align:center;font-size:14px;opacity:0.5}
.weekly-row{display:flex;justify-content:space-between;padding:5px 4px;font-size:18px}
#tip-alert{position:absolute;top:46%;left:50%;padding:40px 72px;border-radius:28px;text-align:center;opacity:0;transform:translate(-50%,-50%) scale(0);transition:transform 0.6s cubic-bezier(0.68,-0.55,0.27,1.55),opacity 0.35s;background:radial-gradient(120% 100% at 50% 0%,rgba(145,70,255,0.3),transparent 60%);border:2px solid #9146ff;box-shadow:0 0 16px rgba(145,70,255,0.9),0 0 36px rgba(145,70,255,0.9);z-index:4}
#tip-alert.show{opacity:1;transform:translate(-50%,-50%) scale(1)}
#tip-alert .tip-user{font-size:2.2em;font-weight:800}
#tip-alert .tip-amount{font-size:4.4em;font-weight:900;color:#ffd700}
#tip-alert .tip-amount::after{content:' BITS';font-size:0.3em;margin-left:14px;color:#fff}
#bottom-row{position:absolute;bottom:20px;left:20px;right:-12px;display:flex;align-items:center;justify-content:space-between;gap:20px;z-index:2}
#session-info{padding:12px 26px;border-radius:999px;font-size:18px;display:flex;gap:20px}
#status{font-size:14px;padding:10px 20px;border-radius:999px;border:2px solid #9146ff}
#status.ok{color:#6bffc6}
#status.error{color:#ff9b57}
#status.wait{color:#ffe067}
</style>
</head>
<body>
<div id="overlay">
  <div id="top-row">
    <div id="top-bar" class="glass"><div class="goal-item"><span class="goal-name">BITS</span><div class="goal-bar-bg"><div class="goal-bar-fill" id="goal-fill"></div></div><span class="goal-val" id="goal-val">0 / $GOAL_AMOUNT</span></div></div>
    <div id="tip-counter" class="glass"><div class="label">BITS</div><div class="value" id="total-tips">0</div></div>
  </div>
  <div id="qr-panel">
    <div class="qr-item"><div class="qr-box"><img id="qr-twitch" alt="Twitch"/><div class="qr-logo"><svg viewBox="0 0 24 24" fill="#9146FF"><path d="M11.571 4.714h1.715v5.143H11.57zm4.715 0H18v5.143h-1.714zM6 0L1.714 4.286v15.428h5.143V24l4.286-4.286h3.428L22.286 12V0zm14.571 11.143l-3.428 3.428h-3.429l-3 3v-3H6.857V1.714h13.714Z"/></svg></div></div><div class="qr-label" style="color:#b380ff">Twitch</div></div>
    <div class="qr-item"><div class="qr-box"><img id="qr-youtube" alt="YouTube"/><div class="qr-logo"><svg viewBox="0 0 24 24" fill="#FF0000"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg></div></div><div class="qr-label" style="color:#ff5555">YouTube</div></div>
    <div class="qr-item"><div class="qr-box"><img id="qr-instagram" alt="Instagram"/><div class="qr-logo"><svg viewBox="0 0 24 24" fill="#DD2A7B"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8z"/></svg></div></div><div class="qr-label" style="color:#ff5fb0">Instagram</div></div>
    <div class="qr-item"><div class="qr-box"><img id="qr-website" alt="Site"/><div class="qr-logo"><svg viewBox="0 0 24 24" fill="#00F5FF"><path d="M12 0a12 12 0 1 0 0 24 12 12 0 0 0 0-24zm0 2c1.85 0 3.58.43 5.13 1.18A5.6 5.6 0 0 0 12 8a5.6 5.6 0 0 0-5.13-4.82A9.95 9.95 0 0 1 12 2zM2 12a9.93 9.93 0 0 1 1.74-5.6 4.06 4.06 0 0 0 3.76 4.27v3.5a1.4 1.4 0 0 0 1.4 1.4h1.65v3.93A10.02 10.02 0 0 1 2 12zm10 9.94v-4.44l1.7-.85a1.4 1.4 0 0 0 .77-1.25v-1.45h1.88a1.4 1.4 0 0 0 1.4-1.4V9.6a1.4 1.4 0 0 0-1.1-1.37l-5.17-1.3A2.27 2.27 0 0 1 9.5 4.72 8.02 8.02 0 0 1 20 12c0 4.42-3.58 8-8 8z"/></svg></div></div><div class="qr-label" style="color:#6bfaff">Site</div></div>
  </div>
  <div id="left-column">
    <div id="chat-panel"><div class="panel-title">💬 CHAT</div><div id="chat-messages"></div></div>
    <div id="event-feed"></div>
  </div>
  <div id="right-panels">
    <div class="panel glass"><div class="panel-title">TOP BITS</div><div id="tippers-list"><div class="tipper-empty">Aucun bit</div></div></div>
    <div class="panel glass"><div class="panel-title">DERNIERS</div><div id="history-list"><div class="tipper-empty">—</div></div></div>
    <div class="panel glass"><div class="panel-title">SEMAINE</div><div class="weekly-row"><span>Bits</span><span id="weekly-tokens">0</span></div><div class="weekly-row"><span>Events</span><span id="weekly-tips">0</span></div></div>
  </div>
  <div id="tip-alert"><div class="tip-user" id="tip-user"></div><div class="tip-amount" id="tip-amount">0</div></div>
  <div id="bottom-row">
    <div id="session-info" class="glass"><span>⏱ <span id="sess-time">00:00:00</span></span><span>💰 <span id="sess-tips">0 events</span></span></div>
    <div id="status" class="wait">Init…</div>
  </div>
</div>
<script>
const WS_URL='ws://localhost:8080';
const GOAL_AMOUNT=$GOAL_AMOUNT;
let ws=null,reconnectTimer=null,totalBits=0,eventCount=0,tippers={},history=[],sessionStart=Date.now();
const \$=id=>document.getElementById(id);
const feed=\$('event-feed'),chatBox=\$('chat-messages');
const QR_CONFIGS=[
{id:'qr-twitch',url:'$TWITCH_URL'},
{id:'qr-youtube',url:'${YOUTUBE_URL:-$TWITCH_URL}'},
{id:'qr-instagram',url:'${INSTAGRAM_URL:-$TWITCH_URL}'},
{id:'qr-website',url:'$WEBSITE_URL_FINAL'}
];
function generateAllQR(){if(typeof QRCode==='undefined')return fallbackAllQR();QR_CONFIGS.forEach(c=>{QRCode.toDataURL(c.url,{width:300,margin:1,errorCorrectionLevel:'H'}).then(u=>{const i=\$(c.id);if(i)i.src=u}).catch(()=>fallbackOneQR(c))})}
function fallbackAllQR(){QR_CONFIGS.forEach(fallbackOneQR)}
function fallbackOneQR(c){const i=\$(c.id);if(i)i.src='https://api.qrserver.com/v1/create-qr-code/?size=300x300&data='+encodeURIComponent(c.url)+'&margin=1&ecc=H'}
function setStatus(t,c){const e=\$('status');e.textContent=t;e.className=c||''}
function connectWebSocket(){if(ws&&ws.readyState===WebSocket.OPEN)return;setStatus('Connexion…','wait');ws=new WebSocket(WS_URL);ws.onopen=()=>setStatus('En direct','ok');ws.onmessage=e=>{try{handleEvent(JSON.parse(e.data))}catch(err){console.error(err)}};ws.onerror=e=>console.error(e);ws.onclose=()=>{setStatus('Reconnexion…','error');clearTimeout(reconnectTimer);reconnectTimer=setTimeout(connectWebSocket,3000)}}
function handleEvent(d){const u=d.user||'Anonyme';eventCount++;if(d.type==='follow')addEvent('follow','💜',u,'a suivi !');else if(d.type==='subscribe')addEvent('subscribe','⭐',u,"s'est abonné !");else if(d.type==='subgift')addEvent('subgift','🎁',u,'a offert un sub !');else if(d.type==='cheer'){const b=parseInt(d.bits||0,10);totalBits+=b;\$('total-tips').textContent=totalBits;\$('goal-fill').style.width=Math.min((totalBits/GOAL_AMOUNT)*100,100)+'%';\$('goal-val').textContent=totalBits+' / '+GOAL_AMOUNT;if(!tippers[u])tippers[u]={name:u,tokens:0};tippers[u].tokens+=b;history.push({user:u,amount:b,ts:Date.now()});if(history.length>20)history.shift();renderTippers();renderHistory();addEvent('cheer','💎',u,'+'+b+' bits');showAlert(u,b)}else if(d.type==='raid')addEvent('raid','🚀',u,'raid '+(d.viewers||0)+' viewers');else if(d.type==='chat')addChat(u,d.message||'');\$('sess-tips').textContent=eventCount+' events'}
function addChat(u,t){const e=document.createElement('div');e.className='chat-msg';e.innerHTML='<span class="chat-user">'+esc(u)+'</span><span class="chat-text">'+esc(t)+'</span>';chatBox.appendChild(e);while(chatBox.children.length>50)chatBox.removeChild(chatBox.firstChild);chatBox.scrollTop=chatBox.scrollHeight}
function addEvent(t,i,u,d){const e=document.createElement('div');e.className='event-item '+t;e.innerHTML='<span>'+i+'</span><span class="event-user">'+esc(u)+'</span><span>'+esc(d)+'</span>';feed.prepend(e);while(feed.children.length>6)feed.removeChild(feed.lastChild)}
function esc(s){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function renderTippers(){const s=Object.values(tippers).sort((a,b)=>b.tokens-a.tokens).slice(0,5);const e=\$('tippers-list');if(!s.length){e.innerHTML='<div class="tipper-empty">Aucun bit</div>';return}const m=['🥇','🥈','🥉'];e.innerHTML=s.map((t,i)=>'<div class="tipper-row"><span>'+(m[i]||(i+1)+'.')+'</span><span>'+esc(t.name)+'</span><span class="tipper-amount">'+t.tokens+'</span></div>').join('')}
function renderHistory(){const e=\$('history-list');const it=history.slice(-6).reverse();if(!it.length){e.innerHTML='<div class="tipper-empty">—</div>';return}e.innerHTML=it.map(h=>{const d=new Date(h.ts);return '<div class="history-row"><span>'+String(d.getHours()).padStart(2,'0')+':'+String(d.getMinutes()).padStart(2,'0')+'</span><span>'+esc(h.user)+'</span><span class="history-amount">+'+h.amount+'</span></div>'}).join('')}
function showAlert(u,a){const al=\$('tip-alert');\$('tip-user').textContent=u;\$('tip-amount').textContent=a;al.classList.add('show');setTimeout(()=>al.classList.remove('show'),6000)}
setInterval(()=>{const e=Math.floor((Date.now()-sessionStart)/1000);\$('sess-time').textContent=String(Math.floor(e/3600)).padStart(2,'0')+':'+String(Math.floor((e%3600)/60)).padStart(2,'0')+':'+String(e%60).padStart(2,'0')},1000);
generateAllQR();connectWebSocket();
<\/script>
</body>
</html>
HTMLEOF
echo "[OK] overlays.html"

touch sounds/.gitkeep

cat > start.bat << 'EOF'
@echo off
cd /d "%~dp0"
node server.js
pause
EOF
cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
node server.js
EOF
chmod +x start.sh

echo "[OK] start.bat / start.sh"
echo ""

echo "=== Installation npm ==="
npm install --silent
echo "[OK] Dépendances installées"

echo ""
echo "=========================================================="
echo "  PROJET CREE AVEC SUCCES"
echo "=========================================================="
echo ""
echo "  Dossier : $PROJECT_NAME/"
echo ""
echo "  Etapes :"
echo "    1. cd $PROJECT_NAME"
echo "    2. Edite .env avec tes identifiants Twitch"
echo "    3. npm start"
echo "    4. http://localhost:$PORT/login"
echo ""
echo "  Creer une app Twitch sur https://dev.twitch.tv/console"
echo "  Redirect URL : http://localhost:$PORT/callback"
echo ""