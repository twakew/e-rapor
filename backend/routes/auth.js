const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../db');
const { verifyToken } = require('../middleware/auth');
require('dotenv').config();

// Login
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    const user = result.rows[0];
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Gate verifikasi: akun yang belum diverifikasi admin tidak boleh masuk.
    // (Baris profiles dibuat otomatis trigger on_user_created; kalau tidak ada
    // baris sama sekali — skema lama — lolos supaya tidak mengunci akun legacy.)
    const prof = await db.query('SELECT is_verified FROM profiles WHERE id = $1', [user.id]);
    if (prof.rows.length > 0 && prof.rows[0].is_verified === false) {
      return res.status(403).json({ error: 'Akun belum diverifikasi. Hubungi admin sekolah.' });
    }
    
    const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '24h' });
    
    res.json({ token, user: { id: user.id, email: user.email, full_name: user.full_name } });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Register
router.post('/register', async (req, res) => {
  const { email, password, full_name } = req.body;
  if (!password || password.length < 8) {
    return res.status(400).json({ error: 'Password minimal 8 karakter' });
  }
  try {
    const hash = await bcrypt.hash(password, 10);
    const result = await db.query(
      'INSERT INTO users (email, password_hash, full_name) VALUES ($1, $2, $3) RETURNING id, email, full_name',
      [email, hash, full_name || '']
    );
    const user = result.rows[0];
    const token = jwt.sign({ id: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '24h' });
    
    res.json({ token, user });
  } catch (error) {
    console.error(error);
    if (error.code === '23505') { // Unique violation
        return res.status(400).json({ error: 'Email already exists' });
    }
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update password — hanya untuk sesi login yang valid (JWT).
router.post('/update-password', verifyToken, async (req, res) => {
  const { password } = req.body;
  if (!password || password.length < 8) {
    return res.status(400).json({ error: 'Password minimal 8 karakter' });
  }
  try {
    const hash = await bcrypt.hash(password, 10);
    await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, req.userId]);
    res.json({ message: 'Password updated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
