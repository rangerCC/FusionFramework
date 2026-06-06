-- =============================================================
-- 0002_subscription_session_admin.sql
-- Subscriptions, sessions, usage, admin. PostgreSQL 14+.
-- =============================================================

BEGIN;

-- -------------------------------------------------------------
-- subscriptions — current entitlement per original transaction.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscriptions (
  id                       BIGINT      PRIMARY KEY,
  user_id                  BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  original_transaction_id  VARCHAR(64) NOT NULL UNIQUE,
  latest_transaction_id    VARCHAR(64),
  product_id               VARCHAR(128) NOT NULL,
  status                   VARCHAR(16) NOT NULL,             -- active|expired|grace|billing_retry|revoked
  expires_at               TIMESTAMPTZ,
  auto_renew               BOOLEAN     NOT NULL DEFAULT false,
  environment              VARCHAR(8)  NOT NULL DEFAULT 'Production', -- Production|Sandbox
  app_account_token        UUID,                             -- from the transaction; links to users.app_account_token
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_subs_user ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subs_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subs_token ON subscriptions(app_account_token);

DROP TRIGGER IF EXISTS trg_subs_updated ON subscriptions;
CREATE TRIGGER trg_subs_updated BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -------------------------------------------------------------
-- subscription_events — Apple notification log (idempotent + audit).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscription_events (
  id                       BIGINT      PRIMARY KEY,
  original_transaction_id  VARCHAR(64),
  notification_type        VARCHAR(32) NOT NULL,
  subtype                  VARCHAR(32),
  notification_uuid        VARCHAR(64) NOT NULL UNIQUE,       -- idempotency key
  environment              VARCHAR(8)  NOT NULL DEFAULT 'Production',
  signed_date              TIMESTAMPTZ,
  raw_payload              JSONB       NOT NULL,
  processed_at             TIMESTAMPTZ,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_events_orig_tx ON subscription_events(original_transaction_id);

-- -------------------------------------------------------------
-- usage_quota — per-account, per-month free-generation counter.
-- One row per (user, period). Atomic consume via ON CONFLICT.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usage_quota (
  user_id     BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  period      CHAR(7)     NOT NULL,                          -- 'YYYY-MM'
  used        INTEGER     NOT NULL DEFAULT 0,
  quota       INTEGER     NOT NULL DEFAULT 3,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, period)
);

DROP TRIGGER IF EXISTS trg_usage_updated ON usage_quota;
CREATE TRIGGER trg_usage_updated BEFORE UPDATE ON usage_quota
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- -------------------------------------------------------------
-- refresh_tokens — hashed, revocable, rotated.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          BIGINT       PRIMARY KEY,
  user_id     BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  VARCHAR(128) NOT NULL UNIQUE,                  -- sha256 hex
  device_id   VARCHAR(128) NOT NULL,
  expires_at  TIMESTAMPTZ  NOT NULL,
  revoked     BOOLEAN      NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rt_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_rt_user_device ON refresh_tokens(user_id, device_id);

-- -------------------------------------------------------------
-- devices — device registry (push, last seen).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
  id           BIGINT       PRIMARY KEY,
  user_id      BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id    VARCHAR(128) NOT NULL,
  push_token   VARCHAR(256),
  platform     VARCHAR(16)  NOT NULL DEFAULT 'ios',
  last_seen_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
  CONSTRAINT uq_user_device UNIQUE (user_id, device_id)
);

-- -------------------------------------------------------------
-- admin_users / audit_logs
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_users (
  id            BIGINT      PRIMARY KEY,
  username      VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(128) NOT NULL,                       -- bcrypt
  role          VARCHAR(16) NOT NULL DEFAULT 'viewer',       -- super|support|viewer
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id          BIGINT      PRIMARY KEY,
  actor       VARCHAR(64) NOT NULL,                          -- admin username or 'system'
  action      VARCHAR(64) NOT NULL,                          -- e.g. 'quota.adjust'
  target      VARCHAR(64),                                   -- e.g. user public_id
  detail      JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_logs(actor);
CREATE INDEX IF NOT EXISTS idx_audit_target ON audit_logs(target);

COMMIT;
