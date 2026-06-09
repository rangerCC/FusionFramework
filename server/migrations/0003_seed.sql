-- =============================================================
-- 0003_seed.sql — initial data (dev / first deploy)
-- NOTE: replace the admin password hash before production use.
-- =============================================================

BEGIN;

-- Default super admin. Password hash below is a bcrypt placeholder — DO NOT use
-- in production. Generate a real one, e.g.:
--   htpasswd -bnBC 12 "" 'your-strong-password' | tr -d ':\n' | sed 's/^\$2y/\$2a/'
-- then replace the string.
INSERT INTO admin_users (id, username, password_hash, role)
VALUES (
  1,
  'admin',
  '$2a$12$REPLACE_ME_WITH_A_REAL_BCRYPT_HASH_xxxxxxxxxxxxxxxxxxxxxx',
  'super'
)
ON CONFLICT (username) DO NOTHING;

COMMIT;
