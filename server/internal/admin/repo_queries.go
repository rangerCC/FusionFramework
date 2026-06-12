package admin

import (
	"context"
	"encoding/json"
	"time"
)

// --- user detail aggregation ---

type userDetail struct {
	Profile      map[string]interface{}   `json:"profile"`
	Bindings     []map[string]interface{} `json:"bindings"`
	Children     []map[string]interface{} `json:"children"`
	Subscription map[string]interface{}   `json:"subscription"`
	Usage        map[string]interface{}   `json:"usage"`
}

// userDetailByPublic aggregates everything the dashboard shows for one user.
func (r *repo) userDetailByPublic(ctx context.Context, publicID string) (*userDetail, error) {
	var (
		id        int64
		nickname  string
		avatar    *string
		status    int16
		token     string
		createdAt time.Time
	)
	err := r.pool.QueryRow(ctx,
		`SELECT id, nickname, avatar_url, status, app_account_token, created_at
		 FROM users WHERE public_id=$1`, publicID,
	).Scan(&id, &nickname, &avatar, &status, &token, &createdAt)
	if err != nil {
		return nil, nil // treated as not-found by caller
	}

	d := &userDetail{
		Profile: map[string]interface{}{
			"user_id": publicID, "nickname": nickname, "avatar_url": avatar,
			"status": status, "app_account_token": token, "created_at": createdAt,
		},
		Bindings: []map[string]interface{}{},
		Children: []map[string]interface{}{},
	}

	// Bindings
	if rows, e := r.pool.Query(ctx,
		`SELECT provider, identifier FROM auth_identities WHERE user_id=$1`, id); e == nil {
		defer rows.Close()
		for rows.Next() {
			var provider, identifier string
			if rows.Scan(&provider, &identifier) == nil {
				d.Bindings = append(d.Bindings, map[string]interface{}{
					"provider": provider, "identifier": maskIdentifier(provider, identifier),
				})
			}
		}
	}

	// Children (not soft-deleted)
	if rows, e := r.pool.Query(ctx,
		`SELECT public_id, name, gender, birthday, diagnosis_type, language_level, is_default
		 FROM children WHERE user_id=$1 AND deleted_at IS NULL ORDER BY created_at ASC`, id); e == nil {
		defer rows.Close()
		for rows.Next() {
			var cid, name, gender, diag, level string
			var bday time.Time
			var isDefault bool
			if rows.Scan(&cid, &name, &gender, &bday, &diag, &level, &isDefault) == nil {
				d.Children = append(d.Children, map[string]interface{}{
					"child_id": cid, "name": name, "gender": gender,
					"birthday": bday.Format("2006-01-02"), "diagnosis_type": diag,
					"language_level": level, "is_default": isDefault,
				})
			}
		}
	}

	// Subscription (latest)
	var (
		productID, subStatus, environment string
		expiresAt                         *time.Time
		autoRenew                         bool
	)
	if r.pool.QueryRow(ctx,
		`SELECT product_id, status, expires_at, auto_renew, environment
		 FROM subscriptions WHERE user_id=$1 ORDER BY updated_at DESC LIMIT 1`, id,
	).Scan(&productID, &subStatus, &expiresAt, &autoRenew, &environment) == nil {
		d.Subscription = map[string]interface{}{
			"product_id": productID, "status": subStatus, "expires_at": expiresAt,
			"auto_renew": autoRenew, "environment": environment,
		}
	}

	// Usage (current month)
	period := time.Now().Format("2006-01")
	var used, quota int
	if r.pool.QueryRow(ctx,
		`SELECT used, quota FROM usage_quota WHERE user_id=$1 AND period=$2`, id, period,
	).Scan(&used, &quota) == nil {
		d.Usage = map[string]interface{}{"period": period, "used": used, "quota": quota}
	} else {
		d.Usage = map[string]interface{}{"period": period, "used": 0, "quota": nil}
	}

	return d, nil
}

func maskIdentifier(provider, identifier string) string {
	if provider == "phone" && len(identifier) == 11 {
		return identifier[:3] + "****" + identifier[7:]
	}
	return identifier
}

// --- subscriptions list ---

type subRow struct {
	UserPublicID string     `json:"user_id"`
	Nickname     string     `json:"nickname"`
	ProductID    string     `json:"product_id"`
	Status       string     `json:"status"`
	ExpiresAt    *time.Time `json:"expires_at"`
	AutoRenew    bool       `json:"auto_renew"`
	Environment  string     `json:"environment"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

func (r *repo) listSubscriptions(ctx context.Context, status, env, keyword string, limit, offset int) ([]subRow, int, error) {
	const base = `
		FROM subscriptions s
		JOIN users u ON u.id = s.user_id
		LEFT JOIN auth_identities ai ON ai.user_id=u.id AND ai.provider='phone'
		WHERE ($1='' OR s.status=$1)
		  AND ($2='' OR s.environment=$2)
		  AND ($3='' OR u.nickname ILIKE '%'||$3||'%' OR ai.identifier ILIKE '%'||$3||'%')`
	var total int
	if err := r.pool.QueryRow(ctx, `SELECT count(*) `+base, status, env, keyword).Scan(&total); err != nil {
		return nil, 0, err
	}
	q := `SELECT u.public_id, u.nickname, s.product_id, s.status, s.expires_at, s.auto_renew, s.environment, s.updated_at ` +
		base + ` ORDER BY s.updated_at DESC LIMIT $4 OFFSET $5`
	rows, err := r.pool.Query(ctx, q, status, env, keyword, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var out []subRow
	for rows.Next() {
		var s subRow
		if err := rows.Scan(&s.UserPublicID, &s.Nickname, &s.ProductID, &s.Status,
			&s.ExpiresAt, &s.AutoRenew, &s.Environment, &s.UpdatedAt); err != nil {
			return nil, 0, err
		}
		out = append(out, s)
	}
	return out, total, rows.Err()
}

// --- audit logs list ---

type auditRow struct {
	Actor     string          `json:"actor"`
	Action    string          `json:"action"`
	Target    string          `json:"target"`
	Detail    json.RawMessage `json:"detail"`
	CreatedAt time.Time       `json:"created_at"`
}

func (r *repo) listAuditLogs(ctx context.Context, actor, action, target string, limit, offset int) ([]auditRow, int, error) {
	const base = `
		FROM audit_logs
		WHERE ($1='' OR actor ILIKE '%'||$1||'%')
		  AND ($2='' OR action ILIKE '%'||$2||'%')
		  AND ($3='' OR target ILIKE '%'||$3||'%')`
	var total int
	if err := r.pool.QueryRow(ctx, `SELECT count(*) `+base, actor, action, target).Scan(&total); err != nil {
		return nil, 0, err
	}
	q := `SELECT actor, action, COALESCE(target,''), detail, created_at ` +
		base + ` ORDER BY created_at DESC LIMIT $4 OFFSET $5`
	rows, err := r.pool.Query(ctx, q, actor, action, target, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var out []auditRow
	for rows.Next() {
		var a auditRow
		if err := rows.Scan(&a.Actor, &a.Action, &a.Target, &a.Detail, &a.CreatedAt); err != nil {
			return nil, 0, err
		}
		out = append(out, a)
	}
	return out, total, rows.Err()
}

// storiesGeneratedToday sums today's usage increments as a proxy for generations.
func (r *repo) storiesGeneratedToday(ctx context.Context) int {
	var n int
	_ = r.pool.QueryRow(ctx,
		`SELECT COALESCE(sum(used),0) FROM usage_quota WHERE updated_at::date = now()::date`,
	).Scan(&n)
	return n
}
