-- =============================================================
-- 0006_poc_device_identity.sql — PoC Phase 1: device-identity model
-- Drops phone/JWT auth tables, rebuilds users as device-keyed.
-- PostgreSQL 14+. Runs inside a transaction; idempotent via IF EXISTS.
-- =============================================================

BEGIN;

-- -------------------------------------------------------------
-- Drop tables that are no longer needed (dependency order)
-- -------------------------------------------------------------

-- usage_quota references users → drop first
DROP TABLE IF EXISTS usage_quota CASCADE;

-- refresh_tokens references users → drop
DROP TABLE IF EXISTS refresh_tokens CASCADE;

-- devices references users → drop
DROP TABLE IF EXISTS devices CASCADE;

-- auth_identities references users → drop
DROP TABLE IF EXISTS auth_identities CASCADE;

-- -------------------------------------------------------------
-- Rebuild users table for device-identity model
-- (column set changed significantly, so DROP + CREATE)
-- -------------------------------------------------------------
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
  id                BIGINT      PRIMARY KEY,                       -- snowflake id
  public_id         VARCHAR(32) NOT NULL UNIQUE,                   -- e.g. "u_01H8..."
  device_id         VARCHAR(128) NOT NULL UNIQUE,                  -- client-supplied device fingerprint
  app_account_token UUID        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  status            SMALLINT    NOT NULL DEFAULT 1,                -- 1 normal, 0 banned
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ON users(device_id);

DROP TRIGGER IF EXISTS trg_users_updated ON users;
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
