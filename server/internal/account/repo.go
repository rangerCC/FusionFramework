package account

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Profile is the account view returned to clients.
type Profile struct {
	ID              int64
	PublicID        string
	Nickname        string
	AvatarURL       *string
	AppAccountToken string
	Phone           *string // raw, for masking in handler
	CreatedAt       time.Time
}

type repo struct {
	pool *pgxpool.Pool
}

func (r *repo) getProfile(ctx context.Context, userID int64) (*Profile, error) {
	const q = `
		SELECT u.id, u.public_id, u.nickname, u.avatar_url, u.app_account_token, u.created_at,
		       (SELECT identifier FROM auth_identities WHERE user_id = u.id AND provider='phone' LIMIT 1)
		FROM users u WHERE u.id = $1 AND u.status >= 0`
	var p Profile
	err := r.pool.QueryRow(ctx, q, userID).Scan(
		&p.ID, &p.PublicID, &p.Nickname, &p.AvatarURL, &p.AppAccountToken, &p.CreatedAt, &p.Phone)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *repo) updateProfile(ctx context.Context, userID int64, nickname, avatarURL *string) error {
	const q = `
		UPDATE users SET
			nickname   = COALESCE($2, nickname),
			avatar_url = COALESCE($3, avatar_url)
		WHERE id = $1`
	_, err := r.pool.Exec(ctx, q, userID, nickname, avatarURL)
	return err
}

type binding struct {
	Provider   string
	Identifier string
}

func (r *repo) bindings(ctx context.Context, userID int64) ([]binding, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT provider, identifier FROM auth_identities WHERE user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []binding
	for rows.Next() {
		var b binding
		if err := rows.Scan(&b.Provider, &b.Identifier); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

// deactivate soft-deletes the account and cascades to children + tokens.
func (r *repo) deactivate(ctx context.Context, userID int64) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `UPDATE users SET status = -1 WHERE id = $1`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE children SET deleted_at = now() WHERE user_id = $1 AND deleted_at IS NULL`, userID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE refresh_tokens SET revoked = true WHERE user_id = $1`, userID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
