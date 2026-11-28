-- =============================================================
-- 0004_children_default.sql — mark one child per account as default
-- =============================================================

BEGIN;

ALTER TABLE children ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT false;

-- At most one default child per account (ignoring soft-deleted rows).
CREATE UNIQUE INDEX IF NOT EXISTS uq_children_default
	ON children(user_id) WHERE is_default AND deleted_at IS NULL;

COMMIT;
