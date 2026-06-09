package admin

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

type repo struct {
	pool *pgxpool.Pool
	ids  *idgen.Snowflake
}

type adminUser struct {
	ID           int64
	Username     string
	PasswordHash string
	Role         string
}

func (r *repo) findAdmin(ctx context.Context, username string) (*adminUser, error) {
	var a adminUser
	err := r.pool.QueryRow(ctx,
		`SELECT id, username, password_hash, role FROM admin_users WHERE username=$1`, username,
	).Scan(&a.ID, &a.Username, &a.PasswordHash, &a.Role)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &a, err
}

func (r *repo) findAdminByID(ctx context.Context, id int64) (*adminUser, error) {
	var a adminUser
	err := r.pool.QueryRow(ctx,
		`SELECT id, username, password_hash, role FROM admin_users WHERE id=$1`, id,
	).Scan(&a.ID, &a.Username, &a.PasswordHash, &a.Role)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &a, err
}

// userRow is a row in the admin user list.
type userRow struct {
	PublicID      string
	Nickname      string
	Phone         *string
	Status        int16
	IsSubscribed  bool
	ChildrenCount int
	CreatedAt     time.Time
}

func (r *repo) listUsers(ctx context.Context, keyword string, limit, offset int) ([]userRow, int, error) {
	// keyword matches phone identifier or nickname.
	const base = `
		FROM users u
		LEFT JOIN auth_identities ai ON ai.user_id=u.id AND ai.provider='phone'
		WHERE ($1='' OR u.nickname ILIKE '%'||$1||'%' OR ai.identifier ILIKE '%'||$1||'%')`
	var total int
	if err := r.pool.QueryRow(ctx, `SELECT count(*) `+base, keyword).Scan(&total); err != nil {
		return nil, 0, err
	}
	const q = `
		SELECT u.public_id, u.nickname, ai.identifier, u.status, u.created_at,
		   EXISTS(SELECT 1 FROM subscriptions s WHERE s.user_id=u.id AND s.status='active' AND (s.expires_at IS NULL OR s.expires_at>now())),
		   (SELECT count(*) FROM children c WHERE c.user_id=u.id AND c.deleted_at IS NULL)
		` + base + ` ORDER BY u.created_at DESC LIMIT $2 OFFSET $3`
	rows, err := r.pool.Query(ctx, q, keyword, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var out []userRow
	for rows.Next() {
		var u userRow
		if err := rows.Scan(&u.PublicID, &u.Nickname, &u.Phone, &u.Status, &u.CreatedAt,
			&u.IsSubscribed, &u.ChildrenCount); err != nil {
			return nil, 0, err
		}
		out = append(out, u)
	}
	return out, total, rows.Err()
}

func (r *repo) userIDByPublic(ctx context.Context, publicID string) (int64, error) {
	var id int64
	err := r.pool.QueryRow(ctx, `SELECT id FROM users WHERE public_id=$1`, publicID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	return id, err
}

func (r *repo) setUserStatus(ctx context.Context, userID int64, status int16) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `UPDATE users SET status=$2 WHERE id=$1`, userID, status); err != nil {
		return err
	}
	if status == 0 {
		if _, err := tx.Exec(ctx, `UPDATE refresh_tokens SET revoked=true WHERE user_id=$1`, userID); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

func (r *repo) audit(ctx context.Context, actor, action, target string, detail []byte) {
	_, _ = r.pool.Exec(ctx,
		`INSERT INTO audit_logs (id, actor, action, target, detail) VALUES ($1,$2,$3,$4,$5)`,
		r.ids.Next(), actor, action, target, detail)
}

func (r *repo) dashboard(ctx context.Context) (map[string]interface{}, error) {
	out := map[string]interface{}{}
	var totalUsers, activeSubs int
	_ = r.pool.QueryRow(ctx, `SELECT count(*) FROM users WHERE status>=0`).Scan(&totalUsers)
	_ = r.pool.QueryRow(ctx, `SELECT count(*) FROM subscriptions WHERE status='active' AND (expires_at IS NULL OR expires_at>now())`).Scan(&activeSubs)
	var newToday int
	_ = r.pool.QueryRow(ctx, `SELECT count(*) FROM users WHERE created_at::date = now()::date`).Scan(&newToday)
	out["total_users"] = totalUsers
	out["new_users_today"] = newToday
	out["active_subscriptions"] = activeSubs
	out["revenue_estimate_month"] = 0
	return out, nil
}
