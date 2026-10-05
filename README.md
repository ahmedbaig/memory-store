# memory-store

Structured long-term memory for Claude in Postgres: typed entries with scope, provenance, confidence, validity windows and links, searchable by keyword, fuzzy match and (later) embeddings.

Runs against the `memory` database on the homelab Postgres (CT 112, `10.10.20.4`, Postgres 17 + pgvector + pg_trgm). The connection string comes from `homelab-secrets/memory/postgres.sops.yaml` (or `MEMORY_DATABASE_URL`).

```bash
npm install
npm run migrate          # apply migrations/*.sql
npm run seed             # import memory files + Obsidian vault (changed files only)
npm run seed -- --force  # re-import everything
```

## Model

| Table | What |
|---|---|
| `source` | One imported file (Claude memory note, vault page) with its full text and hash |
| `entry` | One unit of knowledge: `kind` (rule, fact, decision, procedure, event, entity, profile, reference, project, page, section), `scope` (work, personal, homelab), `project`, `provenance` (user, inferred, verified, imported), `confidence`, `valid_from`/`valid_to`, `superseded_by`, `verify_cmd`, `embedding` |
| `relation` | Typed edges between entries (`links_to` from `[[wikilinks]]`, `part_of` from page sections) |
| `current_entry` | View of entries that are neither superseded nor expired |

```sql
select * from search_entries('thin pool cleanup', 'homelab', 5);
```

## Sources

- Claude memory notes: `~/.claude/projects/*/memory/*.md` plus any `extraMemoryRoots`, de-duplicated by real path and content
- Obsidian vault: every page except `Operations/Credentials.md`, split into one entry per `##` section

## Local config

Machine-specific settings (extra memory roots, project folder prefixes, the keyword patterns that decide `work` / `homelab` / `personal` scope) live in `memory-store.config.json`, which is gitignored. Start from `memory-store.config.example.json`.

## Next

Tracked as [issues](https://github.com/ahmedbaig/memory-store/issues).
