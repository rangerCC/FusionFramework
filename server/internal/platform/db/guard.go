package db

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// GuardEnvironment binds a database to a single environment. The first time it
// runs it stamps the env into a one-row app_meta table; on every subsequent
// boot it refuses to start if the stamped env differs from the running env.
//
// This is the hard backstop against the worst isolation failure: a test/staging
// instance pointed (by a bad DATABASE_URL) at the production database. Even a
// correct password won't let the wrong environment mutate the data.
func GuardEnvironment(ctx context.Context, pool *pgxpool.Pool, env string) error {
	if _, err := pool.Exec(ctx, `CREATE TABLE IF NOT EXISTS app_meta (
		id INT PRIMARY KEY DEFAULT 1,
		environment TEXT NOT NULL,
		CONSTRAINT app_meta_singleton CHECK (id = 1)
	)`); err != nil {
		return fmt.Errorf("ensure app_meta: %w", err)
	}

	var stamped string
	err := pool.QueryRow(ctx, `SELECT environment FROM app_meta WHERE id = 1`).Scan(&stamped)
	if errors.Is(err, pgx.ErrNoRows) {
		// First boot against this database: claim it for this environment.
		_, err = pool.Exec(ctx, `INSERT INTO app_meta (id, environment) VALUES (1, $1)`, env)
		return err
	}
	if err != nil {
		return fmt.Errorf("read app_meta: %w", err)
	}
	if stamped != env {
		return fmt.Errorf(
			"environment mismatch: this database is stamped %q but APP_ENV=%q — refusing to start to avoid cross-environment data access",
			stamped, env)
	}
	return nil
}
