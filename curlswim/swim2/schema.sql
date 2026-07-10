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
