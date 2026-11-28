-- =============================================================
-- 0005_featured_stories.sql — server-managed featured (精选) stories
-- =============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS featured_stories (
	id          BIGINT      PRIMARY KEY,                 -- snowflake
	public_id   VARCHAR(40) NOT NULL UNIQUE,             -- "feat_xxx", exposed as story_id
	title       TEXT        NOT NULL,
	image_url   TEXT,                                    -- first page illustration (list thumbnail)
	word_count  INTEGER     NOT NULL DEFAULT 0,
	raw_json    JSONB       NOT NULL,                    -- full coze story JSON (lossless)
	sort        INTEGER     NOT NULL DEFAULT 0,          -- display order (asc)
	created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
	updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- List ordering. The list ETag is derived at query time from
-- count(*) + max(updated_at), so no separate version table is needed.
CREATE INDEX IF NOT EXISTS idx_featured_sort ON featured_stories(sort, created_at);

DROP TRIGGER IF EXISTS trg_featured_updated ON featured_stories;
CREATE TRIGGER trg_featured_updated BEFORE UPDATE ON featured_stories
	FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
