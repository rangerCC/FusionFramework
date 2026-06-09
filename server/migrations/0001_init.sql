-- =============================================================
-- 0001_init.sql — Social Story account backend schema
-- PostgreSQL 14+
-- Run inside a transaction. Idempotent-ish via IF NOT EXISTS.
-- =============================================================

BEGIN;

-- For UUID generation (app_account_token). pgcrypto provides gen_random_uuid().
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- updated_at auto-touch trigger function
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- -------------------------------------------------------------
-- users — the account subject. Login methods hang off it.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id                BIGINT      PRIMARY KEY,                 -- snowflake id
  public_id         VARCHAR(32) NOT NULL UNIQUE,             -- e.g. "u_01H8XK..."
  nickname          VARCHAR(64) NOT NULL DEFAULT '',
  avatar_url        VARCHAR(512),
  app_account_token UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  status            SMALLINT    NOT NULL DEFAULT 1,          -- 1 normal, 0 banned, -1 deactivated
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_users_updated ON users;
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -------------------------------------------------------------
-- auth_identities — pluggable login identities (phone/wechat/apple).
-- One user can have many; "bind wechat" = insert a row here.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auth_identities (
  id          BIGINT       PRIMARY KEY,
  user_id     BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider    VARCHAR(16)  NOT NULL,                         -- 'phone' | 'wechat' | 'apple'
  identifier  VARCHAR(128) NOT NULL,                         -- phone / wechat unionid / apple sub
  union_id    VARCHAR(64),                                   -- wechat only
  open_id     VARCHAR(64),                                   -- wechat only (per-app)
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_provider_identifier UNIQUE (provider, identifier)
);
CREATE INDEX IF NOT EXISTS idx_auth_identities_user ON auth_identities(user_id);

-- -------------------------------------------------------------
-- children — child profiles, aligned with story-generation params.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS children (
  id              BIGINT      PRIMARY KEY,
  public_id       VARCHAR(32) NOT NULL UNIQUE,               -- "c_01H9..."
  user_id         BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            VARCHAR(64) NOT NULL,
  gender          VARCHAR(8)  NOT NULL,                      -- boy | girl
  birthday        DATE        NOT NULL,
  diagnosis_type  VARCHAR(32) NOT NULL,                      -- asd|adhd|social_anxiety|other
  language_level  VARCHAR(16) NOT NULL,                      -- simple|moderate|advanced
  interests       JSONB       NOT NULL DEFAULT '[]'::jsonb,
  avatar_url      VARCHAR(512),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_children_user ON children(user_id) WHERE deleted_at IS NULL;

DROP TRIGGER IF EXISTS trg_children_updated ON children;
CREATE TRIGGER trg_children_updated BEFORE UPDATE ON children
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
