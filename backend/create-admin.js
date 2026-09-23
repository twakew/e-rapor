require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});

async function createAdmin() {
  const email = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_PASSWORD;
  const fullName = 'Administrator';

  if (!email || !password || password.length < 12) {
    console.error('Set ADMIN_EMAIL and ADMIN_PASSWORD (minimal 12 karakter) di backend/.env dulu.');
    process.exit(1);
  }
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Check if user already exists
    let userRes = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let userId;
    
    if (userRes.rows.length > 0) {
      console.log('Account already exists in users table. Updating password...');
      userId = userRes.rows[0].id;
      await pool.query(
        'UPDATE users SET password_hash = $1 WHERE email = $2',
        [hashedPassword, email]
      );
    } else {
      console.log('Creating new admin account in users table...');
      userRes = await pool.query(
        'INSERT INTO users (email, password_hash, full_name) VALUES ($1, $2, $3) RETURNING id',
        [email, hashedPassword, fullName]
      );
      userId = userRes.rows[0].id;
    }
    
    // Check profiles
    const profRes = await pool.query('SELECT * FROM profiles WHERE id = $1', [userId]);
    if (profRes.rows.length > 0) {
      console.log('Profile exists. Updating role to Admin...');
      await pool.query('UPDATE profiles SET role = $1, is_verified = $2 WHERE id = $3', ['Admin', true, userId]);
    } else {
      console.log('Profile does not exist. Creating profile...');
      await pool.query(
        'INSERT INTO profiles (id, email, full_name, role, is_verified) VALUES ($1, $2, $3, $4, $5)',
        [userId, email, fullName, 'Admin', true]
      );
    }
    
    console.log('\n--- Kredensial Admin ---');
    console.log('Email   :', email);
    console.log('Password: (rahasia, lihat ADMIN_PASSWORD di backend/.env)');
    console.log('------------------------\n');
  } catch (err) {
    console.error('Error creating admin account:', err);
  } finally {
    pool.end();
  }
}

createAdmin();
