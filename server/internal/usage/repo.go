package usage

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

type repo struct {
	pool *pgxpool.Pool
}

// get returns (used, quota) for the user/period, creating the row lazily on read
// via COALESCE defaults (no row yet → used=0).
func (r *repo) get(ctx context.Context, userID int64, period string, defaultQuota int) (used, quota int, err error) {
	const q = `SELECT used, quota FROM usage_quota WHERE user_id=$1 AND period=$2`
	err = r.pool.QueryRow(ctx, q, userID, period).Scan(&used, &quota)
	if err != nil {
		// No row yet for this period.
		return 0, defaultQuota, nil
	}
	return used, quota, nil
}

// consumeFree atomically increments used iff used < quota. Returns the new used
// count and whether it succeeded (false = quota exhausted).
func (r *repo) consumeFree(ctx context.Context, userID int64, period string, defaultQuota int) (used int, ok bool, err error) {
	const q = `
		INSERT INTO usage_quota (user_id, period, used, quota)
		VALUES ($1, $2, 1, $3)
		ON CONFLICT (user_id, period) DO UPDATE
			SET used = usage_quota.used + 1
			WHERE usage_quota.used < usage_quota.quota
		RETURNING used`
	err = r.pool.QueryRow(ctx, q, userID, period, defaultQuota).Scan(&used)
	if err != nil {
		// No RETURNING row → ON CONFLICT WHERE failed → exhausted.
		// Read current used to report it.
		u, _, gerr := r.get(ctx, userID, period, defaultQuota)
		if gerr != nil {
			return 0, false, gerr
		}
		return u, false, nil
	}
	return used, true, nil
}

// recordSubscribed logs a generation for a subscribed user without limiting.
func (r *repo) recordSubscribed(ctx context.Context, userID int64, period string) error {
	const q = `
		INSERT INTO usage_quota (user_id, period, used, quota)
		VALUES ($1, $2, 1, 2147483647)
		ON CONFLICT (user_id, period) DO UPDATE SET used = usage_quota.used + 1`
	_, err := r.pool.Exec(ctx, q, userID, period)
	return err
}

// adjust applies a delta to used (admin compensation). Clamped at 0.
func (r *repo) adjust(ctx context.Context, userID int64, period string, delta, defaultQuota int) (used, quota int, err error) {
	const q = `
		INSERT INTO usage_quota (user_id, period, used, quota)
		VALUES ($1, $2, GREATEST(0, $3), $4)
		ON CONFLICT (user_id, period) DO UPDATE
			SET used = GREATEST(0, usage_quota.used + $3)
		RETURNING used, quota`
	err = r.pool.QueryRow(ctx, q, userID, period, delta, defaultQuota).Scan(&used, &quota)
	return
}
