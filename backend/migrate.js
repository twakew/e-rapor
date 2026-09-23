const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

async function runMigration() {
  // 1. Connect to default 'postgres' database to create the new database
  const defaultClient = new Client({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: 'postgres'
  });

  try {
    await defaultClient.connect();
    console.log('Connected to default postgres database.');
    
    // Check if database exists
    const dbName = process.env.DB_NAME;
    const res = await defaultClient.query(`SELECT 1 FROM pg_database WHERE datname = $1`, [dbName]);
    
    if (res.rowCount === 0) {
      console.log(`Database "${dbName}" does not exist. Creating...`);
      await defaultClient.query(`CREATE DATABASE "${dbName}"`);
      console.log('Database created successfully.');
    } else {
      console.log(`Database "${dbName}" already exists.`);
    }
  } catch (err) {
    console.error('Error in creating database:', err);
    process.exit(1);
  } finally {
    await defaultClient.end();
  }

  // 2. Connect to the target database and run migration
  const client = new Client({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME
  });

  try {
    await client.connect();
    console.log(`Connected to database "${process.env.DB_NAME}".`);
    
    const sqlPath = path.join(__dirname, '../supabase/migrations/self_hosted_migration.sql');
    const sqlFile = fs.readFileSync(sqlPath, 'utf8');
    
    console.log('Executing migration script...');
    await client.query(sqlFile);
    console.log('Migration completed successfully!');
  } catch (err) {
    console.error('Error executing migration script:', err);
    process.exit(1);
  } finally {
    await client.end();
  }
}

runMigration();
