-- schema.sql --- table definition for the swim-times Postgres database.
--
-- The swim-times executable (tangled from swim-times.w) streams one row
-- per swim into this table via a prepared INSERT ... ON CONFLICT DO
-- NOTHING statement.  The UNIQUE constraint below is the conflict target
-- and is what makes re-running the fetch idempotent: a swim already
-- present is silently skipped rather than duplicated.
--
-- Columns mirror the CSV layout emitted with `-o csv`:
--   swimmer, event, swim_time, swim_date, standard, meet
-- plus sort_key, a numeric proxy (seconds) used to order times
-- fastest-first.
--
-- swim_date, standard, and meet are nullable on purpose: the public
-- anonymous best-times feed (GetBestTimesForMember) supplies only the
-- event and the time, so db_insert_row writes SQL NULL for those three
-- fields.  Rows loaded from the richer (signed-in) endpoints may carry
-- them.  The natural-key UNIQUE constraint below treats NULLs as
-- distinct per SQL semantics, which is acceptable here.

CREATE TABLE IF NOT EXISTS swim_times (
    id         BIGSERIAL PRIMARY KEY,
    swimmer    TEXT        NOT NULL,   -- full name, on every row
    event      TEXT        NOT NULL,   -- e.g. '50 FR SCY'
    swim_time  TEXT        NOT NULL,   -- formatted, e.g. '1:02.45' or '36.94r'
    swim_date  DATE,                   -- date of the swim
    standard   TEXT,                   -- motivational level: B, BB, A, ...
    meet       TEXT,                   -- meet name
    sort_key   DOUBLE PRECISION,       -- seconds; smaller = faster
    loaded_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Duplicate guard: the same swimmer's same time in the same event at
    -- the same meet on the same date is one swim.  This tuple is the
    -- ON CONFLICT target referenced by db_insert_row in swim-times.w.
    CONSTRAINT swim_times_natural_key
        UNIQUE (swimmer, event, swim_time, swim_date, meet)
);

-- Helpful secondary indexes for the offline read path (ILIKE on swimmer,
-- equality on event, ordering by sort_key).
CREATE INDEX IF NOT EXISTS swim_times_swimmer_idx ON swim_times (swimmer);
CREATE INDEX IF NOT EXISTS swim_times_event_idx   ON swim_times (event);

-- --------------------------------------------------------------------------
-- Motivational time standards (USA Swimming 2024-2028).
--
-- The anonymous best-times feed does not report the motivational standard a
-- swim attained, so swim-times computes it locally: given a swimmer's gender,
-- age group, event, and time, it asks this table for the fastest standard the
-- time meets.  One row per (gender, age_group, event, standard) holds the cut
-- time in seconds (smaller = faster).  Seeded from motivational-standards.sql,
-- which is generated from the official PDF by tools/parse-motivational.py.
--
-- Classification query (fastest standard met by SECS seconds):
--   SELECT standard FROM motivational_standard
--    WHERE gender=$1 AND age_group=$2 AND event=$3 AND cut_seconds >= $4
--    ORDER BY cut_seconds ASC LIMIT 1;
-- No row => the time is slower than the B cut (or the group is untabulated).

CREATE TABLE IF NOT EXISTS motivational_standard (
    gender      CHAR(1)          NOT NULL,   -- 'F' or 'M'
    age_group   TEXT             NOT NULL,   -- '10&U','11-12','13-14','15-16','17-18'
    event       TEXT             NOT NULL,   -- e.g. '50 FR SCY'
    standard    TEXT             NOT NULL,   -- 'B','BB','A','AA','AAA','AAAA'
    cut_seconds DOUBLE PRECISION NOT NULL,   -- the cut, in seconds
    CONSTRAINT motivational_standard_pk
        PRIMARY KEY (gender, age_group, event, standard)
);

-- The classification query filters by (gender, age_group, event) and orders by
-- cut_seconds; this index serves it directly.
CREATE INDEX IF NOT EXISTS motivational_standard_lookup_idx
    ON motivational_standard (gender, age_group, event, cut_seconds);
