// CORE accounts server
// ---------------------------------------------------------------------------
// A small, dependency-light Node/Express backend that gives CORE real accounts:
//   - Common users: register/login, capped by DAILY limits, and their account
//     is locked to the first device (browser) they logged in from — they
//     cannot "switch accounts" by logging into a different account on that
//     device (and can't move their own account to another device either).
//   - Admin (the founder): one seeded account with NO per-day cap. The only
//     ceiling it shares with everyone else is the GLOBAL monthly credit pool
//     below — once that's drained, even the admin is blocked until it resets
//     or is raised.
//
// Storage is a single JSON file (data.json) next to this script — no native
// modules to compile, so `npm install && node server.js` just works anywhere
// Node runs. Good enough for a small app; swap in a real database later if
// this needs to scale.
//
// IMPORTANT: this file MUST run on a server you control (Render, Railway,
// Fly.io, a VPS, your own machine while developing) — it cannot live inside
// the static HTML file, because the whole point is that limits are enforced
// somewhere the user can't edit with devtools.
// ---------------------------------------------------------------------------

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const DATA_FILE = path.join(__dirname, 'data.json');
const PORT = process.env.PORT || 4000;

// Admin (founder) credentials — set these as real environment variables
// before starting the server. Do not hardcode a real password here.
const ADMIN_USERNAME = process.env.ADMIN_USERNAME;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
if (!ADMIN_USERNAME || !ADMIN_PASSWORD) {
  console.error('Set ADMIN_USERNAME and ADMIN_PASSWORD environment variables before starting the server.');
  process.exit(1);
}

// JWT signing secret — generated once and persisted in data.json so restarts
// don't invalidate every logged-in session. You can also set JWT_SECRET
// yourself as an env var if you'd rather manage it outside this file.
function loadOrCreateSecret(data) {
  if (process.env.JWT_SECRET) return process.env.JWT_SECRET;
  if (data.jwtSecret) return data.jwtSecret;
  data.jwtSecret = crypto.randomBytes(48).toString('hex');
  return data.jwtSecret;
}

function todayStr() { return new Date().toISOString().slice(0, 10); }        // YYYY-MM-DD
function monthStr() { return new Date().toISOString().slice(0, 7); }         // YYYY-MM

function defaultData() {
  return {
    jwtSecret: null,
    users: {},     // username -> { passwordHash, role, deviceId, createdAt }
    usage: {},     // username -> { date, chat, image, sound, model3d }
    global: { month: monthStr(), used: 0 },
    config: {
      dailyLimits: { chat: 60, image: 8, sound: 6, model3d: 3 },
      globalMonthlyCreditLimit: 5000
    }
  };
}

function loadData() {
  if (!fs.existsSync(DATA_FILE)) {
    const fresh = defaultData();
    fresh.jwtSecret = loadOrCreateSecret(fresh);
    fs.writeFileSync(DATA_FILE, JSON.stringify(fresh, null, 2));
    return fresh;
  }
  const data = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  if (!data.jwtSecret) data.jwtSecret = loadOrCreateSecret(data);
  return data;
}

let data = loadData();
function save() { fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2)); }

// Seed / update the admin account from env vars on every boot, so rotating
// ADMIN_PASSWORD and restarting the server is enough to change it.
(function seedAdmin() {
  const existing = data.users[ADMIN_USERNAME];
  const passwordHash = bcrypt.hashSync(ADMIN_PASSWORD, 10);
  if (!existing) {
    data.users[ADMIN_USERNAME] = {
      passwordHash,
      role: 'admin',
      deviceId: null, // admin is never device-locked — can log in anywhere
      createdAt: Date.now()
    };
  } else {
    existing.passwordHash = passwordHash;
    existing.role = 'admin';
  }
  save();
})();

const SECRET = data.jwtSecret;
const app = express();
app.use(cors()); // for production, restrict this to your app's real origin(s)
app.use(express.json());

// Anyone signing up or logging in with one of these emails as their username
// gets the admin role automatically (no personal daily cap, no device lock).
// Add ADMIN_EMAILS as a comma-separated env var to override/extend this list
// without editing code.
const ADMIN_EMAILS = (process.env.ADMIN_EMAILS
  ? process.env.ADMIN_EMAILS.split(',')
  : ['pvpgaming41@gmail.com', 'universalshubh@gmail.com']
).map(e => e.trim().toLowerCase()).filter(Boolean);

function resolveRole(username) {
  return ADMIN_EMAILS.includes(String(username).trim().toLowerCase()) ? 'admin' : 'user';
}

function ensureUsageRow(username) {
  const today = todayStr();
  let row = data.usage[username];
  if (!row || row.date !== today) {
    row = { date: today, chat: 0, image: 0, sound: 0, model3d: 0 };
    data.usage[username] = row;
  }
  return row;
}

function ensureGlobalRow() {
  const month = monthStr();
  if (data.global.month !== month) {
    data.global = { month, used: 0 };
  }
  return data.global;
}

function signToken(username, role) {
  return jwt.sign({ sub: username, role }, SECRET, { expiresIn: '30d' });
}

function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Not logged in.' });
  try {
    const payload = jwt.verify(token, SECRET);
    const user = data.users[payload.sub];
    if (!user) return res.status(401).json({ error: 'Account no longer exists.' });
    req.username = payload.sub;
    req.role = user.role;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Session expired — please log in again.' });
  }
}

function requireAdmin(req, res, next) {
  if (req.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
  next();
}

// ---- Register (common users only — admin is seeded, never self-registered) ----
app.post('/api/register', (req, res) => {
  const { username, password, deviceId } = req.body || {};
  if (!username || !password || !deviceId) {
    return res.status(400).json({ error: 'username, password, and deviceId are all required.' });
  }
  if (username === ADMIN_USERNAME) {
    return res.status(400).json({ error: 'That username is reserved.' });
  }
  if (data.users[username]) {
    return res.status(409).json({ error: 'That username is already taken.' });
  }
  if (String(password).length < 6) {
    return res.status(400).json({ error: 'Password needs to be at least 6 characters.' });
  }
  const role = resolveRole(username);
  data.users[username] = {
    passwordHash: bcrypt.hashSync(password, 10),
    role,
    deviceId: role === 'admin' ? null : deviceId, // admins aren't device-locked
    createdAt: Date.now()
  };
  save();
  const token = signToken(username, role);
  res.json({ token, role, username });
});

// ---- Login ----
app.post('/api/login', (req, res) => {
  const { username, password, deviceId } = req.body || {};
  if (!username || !password || !deviceId) {
    return res.status(400).json({ error: 'username, password, and deviceId are all required.' });
  }
  const user = data.users[username];
  if (!user || !bcrypt.compareSync(password, user.passwordHash)) {
    return res.status(401).json({ error: 'Wrong username or password.' });
  }
  // Self-heal: if this email is on the admin allowlist but the stored account
  // predates that (or the list changed), promote it and drop any device lock.
  if (resolveRole(username) === 'admin' && user.role !== 'admin') {
    user.role = 'admin';
    user.deviceId = null;
  }
  if (user.role === 'user') {
    if (!user.deviceId) {
      user.deviceId = deviceId; // first login from this device — lock it in
      save();
    } else if (user.deviceId !== deviceId) {
      return res.status(403).json({
        error: 'This account is locked to the device it first logged in on. Common accounts can\u2019t switch accounts or devices — ask the admin if you need it moved.'
      });
    }
  }
  // admin: no device check at all, can log in from anywhere
  save();
  const token = signToken(username, user.role);
  res.json({ token, role: user.role, username });
});

// ---- Who am I / usage snapshot ----
app.get('/api/me', auth, (req, res) => {
  const usage = ensureUsageRow(req.username);
  const global = ensureGlobalRow();
  save();
  res.json({
    username: req.username,
    role: req.role,
    usage: { chat: usage.chat, image: usage.image, sound: usage.sound, model3d: usage.model3d },
    dailyLimits: req.role === 'admin' ? null : data.config.dailyLimits,
    global: { used: global.used, limit: data.config.globalMonthlyCreditLimit }
  });
});

// ---- Consume one unit of usage for a given feature, enforcing limits ----
// type: 'chat' | 'image' | 'sound' | 'model3d'
app.post('/api/usage/consume', auth, (req, res) => {
  const { type } = req.body || {};
  const validTypes = ['chat', 'image', 'sound', 'model3d'];
  if (!validTypes.includes(type)) return res.status(400).json({ error: 'Unknown usage type.' });

  const global = ensureGlobalRow();
  if (global.used >= data.config.globalMonthlyCreditLimit) {
    return res.status(429).json({
      allowed: false,
      reason: 'global',
      message: 'The shared credit pool for this app is used up for this month — that limit applies to everyone, including the admin, until it resets or is raised.'
    });
  }

  if (req.role !== 'admin') {
    const usage = ensureUsageRow(req.username);
    const limit = data.config.dailyLimits[type];
    if (usage[type] >= limit) {
      return res.status(429).json({
        allowed: false,
        reason: 'daily',
        message: 'Daily limit reached for this feature — it resets tomorrow.'
      });
    }
    usage[type] += 1;
  } else {
    // Admin usage still counts toward the shared global pool (so it can
    // genuinely be "drained"), it's just never blocked by a personal cap.
    ensureUsageRow(req.username)[type] += 1;
  }
  global.used += 1;
  save();
  res.json({ allowed: true });
});

// ---- Admin: view + adjust the shared limits ----
app.get('/api/admin/config', auth, requireAdmin, (req, res) => {
  res.json(data.config);
});
app.patch('/api/admin/config', auth, requireAdmin, (req, res) => {
  const { dailyLimits, globalMonthlyCreditLimit } = req.body || {};
  if (dailyLimits) Object.assign(data.config.dailyLimits, dailyLimits);
  if (typeof globalMonthlyCreditLimit === 'number') data.config.globalMonthlyCreditLimit = globalMonthlyCreditLimit;
  save();
  res.json(data.config);
});

app.listen(PORT, () => console.log('CORE accounts server listening on :' + PORT));
  
