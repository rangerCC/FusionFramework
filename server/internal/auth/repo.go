package auth

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// User is the account row (subset used by auth/account).
type User struct {
	ID              int64
	PublicID        string
	Nickname        string
	AvatarURL       *string
	AppAccountToken string
	Status          int16
	CreatedAt       time.Time
}

type repo struct {
	pool *pgxpool.Pool
	ids  *idgen.Snowflake
}

// findUserByIdentity returns the user for a (provider, identifier), or nil.
func (r *repo) findUserByIdentity(ctx context.Context, provider, identifier string) (*User, error) {
	const q = `
		SELECT u.id, u.public_id, u.nickname, u.avatar_url, u.app_account_token, u.status, u.created_at
		FROM users u
		JOIN auth_identities ai ON ai.user_id = u.id
		WHERE ai.provider = $1 AND ai.identifier = $2`
	row := r.pool.QueryRow(ctx, q, provider, identifier)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return u, err
}

// createUserWithIdentity creates a user + its first identity in one tx.
func (r *repo) createUserWithIdentity(ctx context.Context, provider, identifier, nickname string) (*User, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	userID := r.ids.Next()
	publicID := idgen.PublicID("u")
	const insUser = `
		INSERT INTO users (id, public_id, nickname)
		VALUES ($1, $2, $3)
		RETURNING id, public_id, nickname, avatar_url, app_account_token, status, created_at`
	u, err := scanUser(tx.QueryRow(ctx, insUser, userID, publicID, nickname))
	if err != nil {
		return nil, err
	}
	const insIdentity = `
		INSERT INTO auth_identities (id, user_id, provider, identifier)
		VALUES ($1, $2, $3, $4)`
	if _, err := tx.Exec(ctx, insIdentity, r.ids.Next(), userID, provider, identifier); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return u, nil
}

// --- refresh tokens ---

func (r *repo) saveRefreshToken(ctx context.Context, userID int64, tokenHash, deviceID string, exp time.Time) error {
	const q = `INSERT INTO refresh_tokens (id, user_id, token_hash, device_id, expires_at)
	           VALUES ($1, $2, $3, $4, $5)`
	_, err := r.pool.Exec(ctx, q, r.ids.Next(), userID, tokenHash, deviceID, exp)
	return err
}

type refreshRow struct {
	ID        int64
	UserID    int64
	DeviceID  string
	ExpiresAt time.Time
	Revoked   bool
}

func (r *repo) findRefreshToken(ctx context.Context, tokenHash string) (*refreshRow, error) {
	const q = `SELECT id, user_id, device_id, expires_at, revoked
	           FROM refresh_tokens WHERE token_hash = $1`
	var rr refreshRow
	err := r.pool.QueryRow(ctx, q, tokenHash).Scan(&rr.ID, &rr.UserID, &rr.DeviceID, &rr.ExpiresAt, &rr.Revoked)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &rr, nil
}

func (r *repo) revokeRefreshToken(ctx context.Context, tokenHash string) error {
	_, err := r.pool.Exec(ctx, `UPDATE refresh_tokens SET revoked = true WHERE token_hash = $1`, tokenHash)
	return err
}

func (r *repo) revokeAllForUser(ctx context.Context, userID int64) error {
	_, err := r.pool.Exec(ctx, `UPDATE refresh_tokens SET revoked = true WHERE user_id = $1 AND revoked = false`, userID)
	return err
}

func scanUser(row pgx.Row) (*User, error) {
	var u User
	err := row.Scan(&u.ID, &u.PublicID, &u.Nickname, &u.AvatarURL, &u.AppAccountToken, &u.Status, &u.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}
