package subscription

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// Sub is a subscription row.
type Sub struct {
	ProductID   string
	Status      string
	ExpiresAt   *time.Time
	AutoRenew   bool
	Environment string
}

type repo struct {
	pool *pgxpool.Pool
	ids  *idgen.Snowflake
}

// activeForUser returns the most relevant active subscription, or nil.
func (r *repo) activeForUser(ctx context.Context, userID int64) (*Sub, error) {
	const q = `
		SELECT product_id, status, expires_at, auto_renew, environment
		FROM subscriptions
		WHERE user_id=$1 AND status='active' AND (expires_at IS NULL OR expires_at > now())
		ORDER BY expires_at DESC NULLS LAST LIMIT 1`
	var s Sub
	err := r.pool.QueryRow(ctx, q, userID).Scan(&s.ProductID, &s.Status, &s.ExpiresAt, &s.AutoRenew, &s.Environment)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

// userIDByAppAccountToken maps an Apple appAccountToken back to our user.
func (r *repo) userIDByAppAccountToken(ctx context.Context, token string) (int64, error) {
	var id int64
	err := r.pool.QueryRow(ctx, `SELECT id FROM users WHERE app_account_token=$1`, token).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	return id, err
}

// appAccountToken returns the user's token (for verify ownership check).
func (r *repo) appAccountToken(ctx context.Context, userID int64) (string, error) {
	var token string
	err := r.pool.QueryRow(ctx, `SELECT app_account_token FROM users WHERE id=$1`, userID).Scan(&token)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	return token, err
}

// upsert writes/updates a subscription keyed by original_transaction_id.
func (r *repo) upsert(ctx context.Context, userID int64, s upsertSub) error {
	const q = `
		INSERT INTO subscriptions
			(id, user_id, original_transaction_id, latest_transaction_id, product_id,
			 status, expires_at, auto_renew, environment, app_account_token)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		ON CONFLICT (original_transaction_id) DO UPDATE SET
			latest_transaction_id = EXCLUDED.latest_transaction_id,
			product_id = EXCLUDED.product_id,
			status = EXCLUDED.status,
			expires_at = EXCLUDED.expires_at,
			auto_renew = EXCLUDED.auto_renew,
			environment = EXCLUDED.environment`
	_, err := r.pool.Exec(ctx, q, r.ids.Next(), userID,
		s.OriginalTransactionID, s.LatestTransactionID, s.ProductID,
		s.Status, s.ExpiresAt, s.AutoRenew, s.Environment, s.AppAccountToken)
	return err
}

type upsertSub struct {
	OriginalTransactionID string
	LatestTransactionID   string
	ProductID             string
	Status                string
	ExpiresAt             *time.Time
	AutoRenew             bool
	Environment           string
	AppAccountToken       string
}

// eventSeen reports whether a notificationUUID was already processed (idempotency).
func (r *repo) eventSeen(ctx context.Context, uuid string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM subscription_events WHERE notification_uuid=$1)`, uuid).Scan(&exists)
	return exists, err
}

func (r *repo) recordEvent(ctx context.Context, e eventRow) error {
	const q = `
		INSERT INTO subscription_events
			(id, original_transaction_id, notification_type, subtype, notification_uuid, environment, signed_date, raw_payload, processed_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8, now())
		ON CONFLICT (notification_uuid) DO NOTHING`
	_, err := r.pool.Exec(ctx, q, r.ids.Next(), e.OriginalTransactionID, e.NotificationType,
		e.Subtype, e.NotificationUUID, e.Environment, e.SignedDate, e.RawPayload)
	return err
}

type eventRow struct {
	OriginalTransactionID string
	NotificationType      string
	Subtype               string
	NotificationUUID      string
	Environment           string
	SignedDate            time.Time
	RawPayload            []byte
}
