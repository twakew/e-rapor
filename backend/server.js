const express = require('express');
const cors = require('cors');
require('dotenv').config();
const path = require('path');

const authRoutes = require('./routes/auth');
const storageRoutes = require('./routes/storage');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

// Rate limit in-memory per IP untuk /auth (login/register) — cegah brute force.
// ponytail: cukup untuk 1 instance lokal; kalau nanti multi-instance, pindah
// ke Redis / express-rate-limit.
const AUTH_WINDOW_MS = 15 * 60 * 1000;
const AUTH_MAX_ATTEMPTS = 15;
const authAttempts = new Map();
app.use('/auth', (req, res, next) => {
  if (req.method === 'GET') return next();
  const now = Date.now();
  if (authAttempts.size > 1000) {
    for (const [k, v] of authAttempts) {
      if (now - v.start > AUTH_WINDOW_MS) authAttempts.delete(k);
    }
  }
  const ip = req.ip || (req.socket && req.socket.remoteAddress) || 'unknown';
  let entry = authAttempts.get(ip);
  if (!entry || now - entry.start > AUTH_WINDOW_MS) {
    entry = { start: now, n: 0 };
    authAttempts.set(ip, entry);
  }
  entry.n += 1;
  if (entry.n > AUTH_MAX_ATTEMPTS) {
    return res.status(429).json({ error: 'Terlalu banyak percobaan. Coba lagi dalam 15 menit.' });
  }
  next();
});

// CORS: hanya origin yang terdaftar. Desktop/mobile tidak kirim Origin
// (selalu lolos); browser wajib cocok dengan CORS_ORIGIN di .env.
const CORS_ORIGINS = (process.env.CORS_ORIGIN || 'http://localhost:8080,http://127.0.0.1:8080')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
app.use(
  cors({
    origin: (origin, cb) => cb(null, !origin || CORS_ORIGINS.includes(origin)),
  })
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
// Security headers ringan tanpa dependensi (API JSON, bukan HTML).
app.use((req, res, next) => {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
  });
  next();
});
// Request tanpa body: req.body bisa undefined -> normalisasi supaya
// destructure `req.body.where` dsb. tidak melempar di luar try.
app.use((req, res, next) => {
  if (req.body === undefined) req.body = {};
  next();
});

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.use('/auth', authRoutes);
app.use('/storage', storageRoutes);
app.use('/api', apiRoutes);

// Health check
app.get('/', (req, res) => {
  res.json({ message: 'Backend API is running' });
});

// Error handler JSON — jangan bocorkan stack trace HTML ke client.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
