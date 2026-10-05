create table if not exists source (
  id          bigserial primary key,
  kind        text not null check (kind in ('memory_file', 'vault_page', 'transcript', 'manual')),
  uri         text not null unique,
  title       text not null,
  sha256      text not null,
  content     text not null,
  meta        jsonb not null default '{}',
  imported_at timestamptz not null default now()
);

create table if not exists entry (
  id            bigserial primary key,
  kind          text not null check (kind in ('rule', 'fact', 'decision', 'procedure', 'event', 'entity', 'profile', 'reference', 'project', 'page', 'section')),
  scope         text not null check (scope in ('work', 'personal', 'homelab')),
  project       text,
  title         text not null,
  summary       text,
  body          text not null,
  tags          text[] not null default '{}',
  data          jsonb not null default '{}',
  source_id     bigint references source(id) on delete cascade,
  anchor        text,
  provenance    text not null default 'imported' check (provenance in ('user', 'inferred', 'verified', 'imported')),
  confidence    real not null default 0.7 check (confidence between 0 and 1),
  valid_from    timestamptz not null default now(),
  valid_to      timestamptz,
  superseded_by bigint references entry(id),
  verify_cmd    text,
  verified_at   timestamptz,
  embedding     vector(768),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  tsv           tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(summary, '')), 'B') ||
    setweight(to_tsvector('english', body), 'C')
  ) stored,
  unique (source_id, anchor)
);

create table if not exists relation (
  src        bigint not null references entry(id) on delete cascade,
  rel        text not null,
  dst        bigint not null references entry(id) on delete cascade,
  note       text,
  created_at timestamptz not null default now(),
  primary key (src, rel, dst)
);

create index if not exists entry_tsv_idx on entry using gin (tsv);
create index if not exists entry_title_trgm_idx on entry using gin (title gin_trgm_ops);
create index if not exists entry_body_trgm_idx on entry using gin (body gin_trgm_ops);
create index if not exists entry_scope_kind_idx on entry (scope, kind);
create index if not exists entry_project_idx on entry (project);
create index if not exists entry_tags_idx on entry using gin (tags);
create index if not exists entry_embedding_idx on entry using hnsw (embedding vector_cosine_ops);
create index if not exists relation_dst_idx on relation (dst, rel);

create or replace view current_entry as
  select * from entry
  where superseded_by is null and (valid_to is null or valid_to > now());

create or replace function search_entries(q text, in_scope text default null, max_rows int default 10)
returns table (id bigint, kind text, scope text, project text, title text, summary text, rank real)
language sql stable as $$
  with query as (select websearch_to_tsquery('english', q) as tsq)
  select e.id, e.kind, e.scope, e.project, e.title, e.summary,
         (ts_rank_cd(e.tsv, query.tsq) + 0.3 * greatest(similarity(e.title, q), word_similarity(q, e.body)))::real as rank
  from current_entry e, query
  where (in_scope is null or e.scope = in_scope)
    and (e.tsv @@ query.tsq or e.title % q or q <% e.body)
  order by rank desc
  limit max_rows
$$;

create table if not exists schema_migration (
  name       text primary key,
  applied_at timestamptz not null default now()
);
