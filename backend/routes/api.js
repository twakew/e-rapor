const express = require('express');
const router = express.Router();
const db = require('../db');
const { verifyToken } = require('../middleware/auth');

// Apply JWT authentication middleware to all API routes
router.use(verifyToken);

// --- Security guards -------------------------------------------------------
// 1) Identifier guard: every key from query/body must be a plain identifier,
//    so nothing can break out of "..." / bare interpolation in SQL below.
const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
function keysValid(v) {
  if (Array.isArray(v)) return v.every(keysValid);
  if (v && typeof v === 'object') {
    return Object.keys(v).every((k) => IDENT.test(k) && keysValid(v[k]));
  }
  return true;
}
function hasKey(v, names) {
  if (Array.isArray(v)) return v.some((x) => hasKey(x, names));
  if (v && typeof v === 'object') {
    return Object.keys(v).some((k) => names.includes(k) || hasKey(v[k], names));
  }
  return false;
}

// 2) Role lookup: role lives in profiles, keyed by users.id.
const STAFF_ROLES = ['Guru', 'Admin', 'Super Admin'];
const ADMIN_ROLES = ['Admin', 'Super Admin'];
function requireRole(roles) {
  return async (req, res, next) => {
    try {
      const r = await db.query('SELECT role FROM profiles WHERE id = $1', [req.userId]);
      const role = r.rows[0] && r.rows[0].role;
      if (!role || !roles.includes(role)) {
        return res.status(403).json({ error: 'Insufficient role' });
      }
      req.userRole = role;
      next();
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: 'Internal server error' });
    }
  };
}
const requireStaff = requireRole(STAFF_ROLES);
const requireAdmin = requireRole(ADMIN_ROLES);

router.use((req, res, next) => {
  const queryOk = Object.keys(req.query).every((k) => IDENT.test(k));
  if (!queryOk || !keysValid(req.body)) {
    return res.status(400).json({ error: 'Invalid parameter name' });
  }
  const tableSeg = req.path.split('/')[1];
  const isRpc = tableSeg === 'rpc';
  const isWrite = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method);
  if (isWrite && !isRpc) {
    // role / is_verified on profiles may only be written by admin.
    if (tableSeg === 'profiles' && hasKey(req.body, ['role', 'is_verified'])) {
      return requireAdmin(req, res, next);
    }
    // Writes to data tables require staff; RPC reads stay authenticated-only.
    return requireStaff(req, res, next);
  }
  next();
});
// --- End security guards ---------------------------------------------------

// Generic GET for a table with query filters
router.get('/:table', async (req, res) => {
  const table = req.params.table;
  
  // Basic security: restrict allowed tables
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) {
    return res.status(403).json({ error: 'Access to table denied' });
  }

  try {
    let query = `SELECT * FROM ${table}`;
    const values = [];
    
    // Handle simple exact match filters from query parameters
    const queryKeys = Object.keys(req.query).filter(k => k !== 'limit');
    if (queryKeys.length > 0) {
      const conditions = [];
      let i = 1;
      for (const key of queryKeys) {
        conditions.push(`"${key}" = $${i}`);
        values.push(req.query[key]);
        i++;
      }
      query += ' WHERE ' + conditions.join(' AND ');
    }

    // Default sorting
    if (table === 'school_data') {
        // No order by for school data (usually just 1 row)
    } else {
        query += ' ORDER BY created_at DESC';
    }

    // Support limit parameter
    if (req.query.limit) {
      query += ` LIMIT ${parseInt(req.query.limit)}`;
    }
    
    const result = await db.query(query, values);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generic GET for a table by ID
router.get('/:table/:id', async (req, res) => {
  const { table, id } = req.params;
  
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) return res.status(403).json({ error: 'Access to table denied' });

  try {
    const result = await db.query(`SELECT * FROM ${table} WHERE id = $1`, [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generic POST
router.post('/:table', async (req, res) => {
  const table = req.params.table;
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) return res.status(403).json({ error: 'Access denied' });

  try {
    const keys = Object.keys(req.body);
    const values = Object.values(req.body);
    
    if (keys.length === 0) return res.status(400).json({ error: 'Empty body' });

    const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');
    const columns = keys.join(', ');

    const query = `INSERT INTO ${table} (${columns}) VALUES (${placeholders}) RETURNING *`;
    const result = await db.query(query, values);
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// Bulk DELETE endpoint
router.delete('/:table/bulk', async (req, res) => {
  const table = req.params.table;
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) return res.status(403).json({ error: 'Access denied' });

  // Use query params for DELETE since body might be stripped in some clients/proxies,
  // but for Dio, passing data in delete works. We'll support both body or query.
  const where = req.body.where || req.query;
  if (!where || Object.keys(where).length === 0) return res.status(400).json({ error: 'Missing where condition' });

  try {
    const whereKeys = Object.keys(where);
    const whereValues = Object.values(where);
    const whereClause = whereKeys.map((key, i) => `"${key}" = $${i + 1}`).join(' AND ');

    const query = `DELETE FROM ${table} WHERE ${whereClause} RETURNING id`;
    const result = await db.query(query, whereValues);
    
    res.json({ message: 'Deleted successfully', ids: result.rows.map(r => r.id) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Bulk UPDATE endpoint
router.put('/:table/bulk', async (req, res) => {
  const table = req.params.table;
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) return res.status(403).json({ error: 'Access denied' });

  const { where, updates } = req.body;
  if (!where || !updates) return res.status(400).json({ error: 'Missing where or updates' });

  try {
    const updateKeys = Object.keys(updates);
    const updateValues = Object.values(updates);
    
    if (updateKeys.length === 0) return res.status(400).json({ error: 'Empty updates' });

    let queryParams = [...updateValues];
    const updateSet = updateKeys.map((key, i) => `"${key}" = $${i + 1}`).join(', ');

    const whereKeys = Object.keys(where);
    if (whereKeys.length === 0) return res.status(400).json({ error: 'Empty where clause' });
    const whereValues = Object.values(where);
    let whereIdx = queryParams.length + 1;
    const whereClause = whereKeys.map((key) => {
      const val = where[key];
      queryParams.push(val);
      return `"${key}" = $${whereIdx++}`;
    }).join(' AND ');

    const query = `UPDATE ${table} SET ${updateSet} WHERE ${whereClause} RETURNING *`;
    const result = await db.query(query, queryParams);
    
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generic PUT (Update)
router.put('/:table/:id', async (req, res) => {
  const { table, id } = req.params;
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) return res.status(403).json({ error: 'Access denied' });

  try {
    const keys = Object.keys(req.body);
    const values = Object.values(req.body);
    
    if (keys.length === 0) return res.status(400).json({ error: 'Empty body' });

    const updates = keys.map((key, i) => `"${key}" = $${i + 1}`).join(', ');
    values.push(id); // for the WHERE id = $last

    const query = `UPDATE ${table} SET ${updates} WHERE id = $${values.length} RETURNING *`;
    const result = await db.query(query, values);
    
    if (result.rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generic DELETE
router.delete('/:table/:id', async (req, res) => {
  const { table, id } = req.params;
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) return res.status(403).json({ error: 'Access denied' });

  try {
    const result = await db.query(`DELETE FROM ${table} WHERE id = $1 RETURNING id`, [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Not found' });
    res.json({ message: 'Deleted successfully', id: result.rows[0].id });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
// UPSERT endpoint (for attendance batch save)
router.post('/:table/upsert', async (req, res) => {
  const table = req.params.table;
  const allowedTables = ['students', 'teachers', 'classes', 'attendance', 'assessments', 'school_data', 'documentation', 'profiles', 'batches'];
  if (!allowedTables.includes(table)) return res.status(403).json({ error: 'Access denied' });

  const { records, conflict } = req.body;
  if (!records || !Array.isArray(records) || records.length === 0) {
    return res.status(400).json({ error: 'records must be a non-empty array' });
  }
  if (conflict !== undefined &&
      (typeof conflict !== 'string' ||
       !conflict.split(',').every((c) => IDENT.test(c.trim())))) {
    return res.status(400).json({ error: 'Invalid conflict column' });
  }

  try {
    const results = [];
    for (const record of records) {
      const keys = Object.keys(record);
      const vals = Object.values(record);
      if (keys.length === 0) continue;

      const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');
      const columns = keys.map(k => `"${k}"`).join(', ');
      const updates = keys.map((k, i) => `"${k}" = $${i + 1}`).join(', ');

      let query;
      if (conflict) {
        // ON CONFLICT DO UPDATE
        const conflictCols = conflict.split(',').map(c => `"${c.trim()}"`).join(', ');
        query = `INSERT INTO ${table} (${columns}) VALUES (${placeholders})
                 ON CONFLICT (${conflictCols}) DO UPDATE SET ${updates} RETURNING *`;
      } else {
        query = `INSERT INTO ${table} (${columns}) VALUES (${placeholders}) RETURNING *`;
      }

      const r = await db.query(query, vals);
      if (r.rows.length > 0) results.push(r.rows[0]);
    }
    res.status(200).json(results);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});
// RPC endpoint for OneSignal Push Notifications
router.post('/rpc/send-push-notification', requireStaff, async (req, res) => {
  const { user_id, title, message, data } = req.body;
  const appId = process.env.ONESIGNAL_APP_ID;
  const apiKey = process.env.ONESIGNAL_REST_API_KEY;

  if (!appId || !apiKey) {
    console.error('OneSignal is not configured in .env');
    return res.status(500).json({ error: 'OneSignal configuration missing' });
  }

  const payload = {
    app_id: appId,
    headings: { en: title },
    contents: { en: message },
    data: data || {},
  };

  if (user_id) {
    payload.include_external_user_ids = [user_id];
  } else {
    payload.included_segments = ['Active Users', 'Subscribed Users'];
  }

  try {
    const response = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': `key ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });

    const result = await response.json();
    if (!response.ok) {
      console.error('OneSignal Error:', result);
      return res.status(response.status).json(result);
    }

    res.json(result);
  } catch (err) {
    console.error('Fetch Error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC Stub: check_auth_blocked
router.post('/rpc/check_auth_blocked', async (req, res) => {
  res.json(false);
});

// RPC Stub: reset_login_attempts
router.post('/rpc/reset_login_attempts', async (req, res) => {
  res.json({ message: 'reset' });
});

// RPC Stub: record_login_failure
router.post('/rpc/record_login_failure', async (req, res) => {
  res.json({ message: 'recorded' });
});

// RPC: get_student_stats_summary — total siswa per kelas dengan status
router.post('/rpc/get_student_stats_summary', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT 
        "class" as class_name,
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE status = 'Lulus') as lulus_count
      FROM students
      GROUP BY "class"
    `);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: get_public_teachers — daftar guru non-sensitif
router.post('/rpc/get_public_teachers', async (req, res) => {
  try {
    const result = await db.query(`
      SELECT id, name, subject, gender, phone, address, created_at
      FROM teachers
      ORDER BY name
    `);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: get_my_profile — profil siswa berdasarkan NIS
router.post('/rpc/get_my_profile', async (req, res) => {
  const { p_nis } = req.body;
  if (!p_nis) return res.status(400).json({ error: 'Missing p_nis' });
  try {
    const result = await db.query(`SELECT * FROM students WHERE nis = $1 LIMIT 1`, [p_nis]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: get_student_auth — auth siswa berdasarkan NIS
router.post('/rpc/get_student_auth', async (req, res) => {
  const { p_nis } = req.body;
  if (!p_nis) return res.status(400).json({ error: 'Missing p_nis' });
  try {
    const result = await db.query(`SELECT id, nis, name, "class", rombel FROM students WHERE nis = $1 LIMIT 1`, [p_nis]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: get_my_rapor — rapor siswa berdasarkan NIS
router.post('/rpc/get_my_rapor', async (req, res) => {
  const { p_nis } = req.body;
  if (!p_nis) return res.status(400).json({ error: 'Missing p_nis' });
  try {
    const studentRes = await db.query(`SELECT id FROM students WHERE nis = $1 LIMIT 1`, [p_nis]);
    if (studentRes.rows.length === 0) return res.json([]);
    const studentId = studentRes.rows[0].id;
    const result = await db.query(`SELECT * FROM assessments WHERE student_id = $1 ORDER BY semester`, [studentId]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: get_my_attendance — absensi siswa berdasarkan NIS
router.post('/rpc/get_my_attendance', async (req, res) => {
  const { p_nis } = req.body;
  if (!p_nis) return res.status(400).json({ error: 'Missing p_nis' });
  try {
    const studentRes = await db.query(`SELECT id FROM students WHERE nis = $1 LIMIT 1`, [p_nis]);
    if (studentRes.rows.length === 0) return res.json([]);
    const studentId = studentRes.rows[0].id;
    const result = await db.query(`SELECT * FROM attendance WHERE student_id = $1 ORDER BY date DESC`, [studentId]);
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: get_my_classmates — teman sekelas berdasarkan NIS
router.post('/rpc/get_my_classmates', async (req, res) => {
  const { p_nis } = req.body;
  if (!p_nis) return res.json([]);
  try {
    const myRes = await db.query(`SELECT "class", rombel FROM students WHERE nis = $1 LIMIT 1`, [p_nis]);
    if (myRes.rows.length === 0) return res.json([]);
    const { class: cls, rombel } = myRes.rows[0];
    const result = await db.query(
      `SELECT id, nis, name, gender, "class", rombel, religion, address FROM students WHERE "class" = $1 AND rombel = $2 ORDER BY name`,
      [cls, rombel]
    );
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: verify_user_by_admin — verifikasi akun oleh admin
router.post('/rpc/verify_user_by_admin', requireAdmin, async (req, res) => {
  console.log('[verify_user_by_admin] Request body:', req.body);

  const { p_user_id, p_role, target_user_id, new_role } = req.body;
  const userId = p_user_id || target_user_id;
  const role = p_role || new_role || 'Guru';
  if (!['Guru', 'Admin'].includes(role)) {
    return res.status(400).json({ error: 'Role tidak valid' });
  }

  console.log('[verify_user_by_admin] userId:', userId, 'role:', role);

  if (!userId) {
    console.log('[verify_user_by_admin] Error: Missing user_id');
    return res.status(400).json({ error: 'Missing user_id parameter' });
  }

  try {
    await db.query(`UPDATE profiles SET role = $1, is_verified = true WHERE id = $2`, [role, userId]);
    res.json({ message: 'User verified successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// RPC: delete_user_by_admin — hapus akun oleh admin
router.post('/rpc/delete_user_by_admin', requireAdmin, async (req, res) => {
  const { target_user_id } = req.body;
  if (!target_user_id) return res.status(400).json({ error: 'Missing target_user_id' });
  try {
    await db.query(`DELETE FROM profiles WHERE id = $1`, [target_user_id]);
    await db.query(`DELETE FROM users WHERE id = $1`, [target_user_id]);
    res.json({ message: 'User deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

