# DoltgreSQL 1.3.1: full-text search fails: `to_tsvector` and `to_tsquery` are not found, and `@@` is not yet supported

On DoltgreSQL 1.3.1, full-text search fails at its first step: `to_tsvector` is not found, and neither is
`to_tsquery`. The `@@` match operator is refused as well, whatever its operands, so a match between two
plain text values fails too:

```
psql:/tmp/repro.sql:2: ERROR:  function: 'to_tsvector' not found
psql:/tmp/repro.sql:5: ERROR:  function: 'to_tsquery' not found
psql:/tmp/repro.sql:9: ERROR:  @@ is not yet supported
psql:/tmp/repro.sql:12: ERROR:  @@ is not yet supported
```

PostgreSQL 18.6 answers `'cat':2 'fat':1` and `'cat'`, and `t` for both matches.

Reported upstream: https://github.com/dolthub/doltgresql/issues/3335

## Reproduce it

You need Docker and a POSIX shell: Linux, macOS, or Windows with WSL. The first run downloads the images.

```sh
git clone https://github.com/Reliable-Collaboration/repro-doltgresql-bug-text-search-operator.git
cd repro-doltgresql-bug-text-search-operator
./repro.sh
```

`repro.sh` starts PostgreSQL 18.6 and DoltgreSQL 1.3.1 in two throwaway containers, waits until both
accept connections, runs [`repro.sql`](repro.sql) on each with the `psql` client inside its container,
prints the two outputs side by side, and removes the containers. It exits 0 when DoltgreSQL's output is
identical to PostgreSQL's, and 1 when it differs.

To try another DoltgreSQL release, name its image:

```sh
DOLTGRESQL_IMAGE=dolthub/doltgresql:latest ./repro.sh
```

### Without the script

The same steps by hand, from the repository directory. PostgreSQL first:

```sh
docker run -d --name repro-doltgresql-bug-text-search-operator-postgres -e POSTGRES_PASSWORD=password postgres:18.6-bookworm
docker cp repro.sql repro-doltgresql-bug-text-search-operator-postgres:/tmp/repro.sql
docker exec -t -e PGPASSWORD=password repro-doltgresql-bug-text-search-operator-postgres psql -X -P pager=off -h 127.0.0.1 -U postgres -d postgres --echo-all -f /tmp/repro.sql
docker rm -f repro-doltgresql-bug-text-search-operator-postgres
```

Then DoltgreSQL:

```sh
docker run -d --name repro-doltgresql-bug-text-search-operator-doltgresql -e DOLTGRES_PASSWORD=password dolthub/doltgresql:1.3.1
docker cp repro.sql repro-doltgresql-bug-text-search-operator-doltgresql:/tmp/repro.sql
docker exec -t -e PGPASSWORD=password repro-doltgresql-bug-text-search-operator-doltgresql psql -X -P pager=off -h 127.0.0.1 -U postgres -d postgres --echo-all -f /tmp/repro.sql
docker rm -f repro-doltgresql-bug-text-search-operator-doltgresql
```

If `docker exec` answers that the connection was refused, the server is still starting: wait a few
seconds and run it again.

## The test

[`repro.sql`](repro.sql):

```sql
-- A document as a tsvector.
SELECT to_tsvector('english', 'fat cats');

-- A query as a tsquery.
SELECT to_tsquery('english', 'cat');

-- The two matched with the @@ operator.
SELECT to_tsvector('english', 'fat cats')
       @@ to_tsquery('english', 'cat');

-- The @@ operator between two text values.
SELECT 'fat cats' @@ 'cat';
```

## Expected behavior

The document becomes a `tsvector`, the query a `tsquery`, and both matches answer `t`. This is what
PostgreSQL 18.6 does:

```
-- A document as a tsvector.
SELECT to_tsvector('english', 'fat cats');
   to_tsvector   
-----------------
 'cat':2 'fat':1
(1 row)

-- A query as a tsquery.
SELECT to_tsquery('english', 'cat');
 to_tsquery 
------------
 'cat'
(1 row)

-- The two matched with the @@ operator.
SELECT to_tsvector('english', 'fat cats')
       @@ to_tsquery('english', 'cat');
 ?column? 
----------
 t
(1 row)

-- The @@ operator between two text values.
SELECT 'fat cats' @@ 'cat';
 ?column? 
----------
 t
(1 row)
```

## Actual behavior

Each of the four statements answers an error. This is what DoltgreSQL 1.3.1 does:

```
-- A document as a tsvector.
SELECT to_tsvector('english', 'fat cats');
psql:/tmp/repro.sql:2: ERROR:  function: 'to_tsvector' not found
-- A query as a tsquery.
SELECT to_tsquery('english', 'cat');
psql:/tmp/repro.sql:5: ERROR:  function: 'to_tsquery' not found
-- The two matched with the @@ operator.
SELECT to_tsvector('english', 'fat cats')
       @@ to_tsquery('english', 'cat');
psql:/tmp/repro.sql:9: ERROR:  @@ is not yet supported
-- The @@ operator between two text values.
SELECT 'fat cats' @@ 'cat';
psql:/tmp/repro.sql:12: ERROR:  @@ is not yet supported
```

## Side by side

The full output of `./repro.sh`. A line wider than its column is cut off at the column's edge, as the two
`not found` errors are here; the whole errors are under Actual behavior.

```
Starting postgres:18.6-bookworm@sha256:1c59e2c3c818eaa0f0628f695b36e7c9e362d6b219b36a54a32df645cbd7e1af
Starting dolthub/doltgresql:1.3.1@sha256:6c85cb1f35beabf47f094336a420255130b841b1645f36d79ef046276af36851

Left: PostgreSQL. Right: DoltgreSQL. Lines that differ are marked with |.

-- A document as a tsvector.                                  -- A document as a tsvector.
SELECT to_tsvector('english', 'fat cats');                    SELECT to_tsvector('english', 'fat cats');
   to_tsvector                                              | psql:/tmp/repro.sql:2: ERROR:  function: 'to_tsvector' not 
-----------------                                           <
 'cat':2 'fat':1                                            <
(1 row)                                                     <
                                                            <
-- A query as a tsquery.                                      -- A query as a tsquery.
SELECT to_tsquery('english', 'cat');                          SELECT to_tsquery('english', 'cat');
 to_tsquery                                                 | psql:/tmp/repro.sql:5: ERROR:  function: 'to_tsquery' not f
------------                                                <
 'cat'                                                      <
(1 row)                                                     <
                                                            <
-- The two matched with the @@ operator.                      -- The two matched with the @@ operator.
SELECT to_tsvector('english', 'fat cats')                     SELECT to_tsvector('english', 'fat cats')
       @@ to_tsquery('english', 'cat');                              @@ to_tsquery('english', 'cat');
 ?column?                                                   | psql:/tmp/repro.sql:9: ERROR:  @@ is not yet supported
----------                                                  <
 t                                                          <
(1 row)                                                     <
                                                            <
-- The @@ operator between two text values.                   -- The @@ operator between two text values.
SELECT 'fat cats' @@ 'cat';                                   SELECT 'fat cats' @@ 'cat';
 ?column?                                                   | psql:/tmp/repro.sql:12: ERROR:  @@ is not yet supported
----------                                                  <
 t                                                          <
(1 row)                                                     <
                                                            <

Result: DoltgreSQL's output differs from PostgreSQL's on 4 line(s), marked with |.
```

## Other observations

Each was run on the same two images with the `psql` client inside each container:

- The types are missing too: `SELECT 'fat cats'::tsvector` answers ``unable to resolve type `tsvector` ``,
  `SELECT 'cat'::tsquery` answers ``unable to resolve type `tsquery` ``, and
  `CREATE TABLE tv (id int, v tsvector)` answers `type "tsvector" does not exist`. PostgreSQL answers
  `'cats' 'fat'` and `'cat'`, and creates the table.
- The schema-qualified type name is accepted, but as the type `unknown`:
  `pg_typeof('fat cats'::pg_catalog.tsvector)` answers `unknown`, where PostgreSQL answers `tsvector`;
  `SELECT 'fat cats'::pg_catalog.tsvector` answers `fat cats`, where PostgreSQL answers `'cats' 'fat'`; and
  `CREATE TABLE tv2 (v pg_catalog.tsvector)` succeeds. The qualified function,
  `pg_catalog.to_tsvector('english', 'fat cats')`, answers `function: 'to_tsvector' not found`.
- The forms without a configuration, `to_tsvector('fat cats')` and `to_tsquery('cat')`, are not found
  either, and neither are `plainto_tsquery('english', 'cat')` and
  `ts_rank(to_tsvector('fat cats'), to_tsquery('cat'))`.
- `@@` is refused whatever its operands: `SELECT 1 @@ 2` answers `@@ is not yet supported`, where
  PostgreSQL answers `operator does not exist: integer @@ integer`, and so does the JSON path match
  `SELECT '{"a": 1}'::jsonb @@ '$.a == 1'`, which PostgreSQL answers with `t`.
- `@@` is refused before the table is looked up: `SELECT id FROM no_such_table WHERE body @@ 'cat'`
  answers `@@ is not yet supported`, where PostgreSQL answers `relation "no_such_table" does not exist`.
- Over a table with a `text` column, `WHERE body @@ 'cat'` and
  `WHERE to_tsvector('english', body) @@ to_tsquery('english', 'cat')` answer `@@ is not yet supported`;
  PostgreSQL answers the row whose `body` is `fat cats`.
- The setting exists: `SHOW default_text_search_config` answers `pg_catalog.english` on both engines,
  though DoltgreSQL names the column `@@session.default_text_search_config`. DoltgreSQL's `pg_ts_config`
  holds one configuration, `simple`; PostgreSQL's holds 30.
- `SELECT 'english'::regconfig` answers ``unable to resolve type `regconfig` ``; PostgreSQL answers
  `english`.
- Upstream, issue [#759](https://github.com/dolthub/doltgresql/issues/759), "`TSVECTOR` support", was
  closed in favor of [#1212](https://github.com/dolthub/doltgresql/issues/1212), "Vector support", which
  asks for pgvector; pull request [#1530](https://github.com/dolthub/doltgresql/pull/1530), "support `@@`
  text search operator", was closed without being merged.

## Environment

- DoltgreSQL 1.3.1, the newest release when this was written: image `dolthub/doltgresql:1.3.1`, digest
  `sha256:6c85cb1f35beabf47f094336a420255130b841b1645f36d79ef046276af36851`. Its bundled `psql` is 17.11.
- PostgreSQL 18.6: image `postgres:18.6-bookworm`, digest
  `sha256:1c59e2c3c818eaa0f0628f695b36e7c9e362d6b219b36a54a32df645cbd7e1af`. Its `psql` is 18.6.
- Reproduced on 2026-09-11 (UTC) with Docker 29.7.2 on Linux x86_64 (WSL 2).
