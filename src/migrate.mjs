import { readdir, readFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { connect, inTransaction, withClient } from './db.mjs';

const dir = join(dirname(fileURLToPath(import.meta.url)), '../migrations');

const pending = async client => {
  await client.query('create table if not exists schema_migration (name text primary key, applied_at timestamptz not null default now())');
  const applied = new Set((await client.query('select name from schema_migration')).rows.map(r => r.name));
  return (await readdir(dir)).filter(f => f.endsWith('.sql')).sort().filter(f => !applied.has(f));
};

const apply = (pool, name) =>
  inTransaction(pool, async client => {
    await client.query(await readFile(join(dir, name), 'utf8'));
    await client.query('insert into schema_migration (name) values ($1)', [name]);
    console.log('applied', name);
  });

const pool = connect();
const todo = await withClient(pool, pending);
for (const name of todo) await apply(pool, name);
if (!todo.length) console.log('up to date');
await pool.end();
