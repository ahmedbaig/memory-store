import { execFileSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';
import pg from 'pg';

const secretsDir = () => process.env.HOMELAB_SECRETS ?? join(homedir(), 'Work/PersonalProjects/homelab-secrets');

export const databaseUrl = () =>
  process.env.MEMORY_DATABASE_URL ??
  execFileSync('sops', ['decrypt', '--extract', '["memory_database_url"]', join(secretsDir(), 'memory/postgres.sops.yaml')], { encoding: 'utf8' }).trim();

export const connect = () => {
  const url = new URL(databaseUrl());
  url.searchParams.delete('sslmode');
  return new pg.Pool({ connectionString: url.toString(), ssl: { rejectUnauthorized: false }, max: 4 });
};

export const withClient = async (pool, fn) => {
  const client = await pool.connect();
  try {
    return await fn(client);
  } finally {
    client.release();
  }
};

export const inTransaction = (pool, fn) =>
  withClient(pool, async client => {
    await client.query('begin');
    try {
      const result = await fn(client);
      await client.query('commit');
      return result;
    } catch (error) {
      await client.query('rollback');
      throw error;
    }
  });
