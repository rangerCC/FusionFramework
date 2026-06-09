package children

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

const maxChildren = 10

// Child is a child profile.
type Child struct {
	ID            int64
	PublicID      string
	Name          string
	Gender        string
	Birthday      time.Time
	DiagnosisType string
	LanguageLevel string
	Interests     []string
	AvatarURL     *string
	IsDefault     bool
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

type repo struct {
	pool *pgxpool.Pool
	ids  *idgen.Snowflake
}

func (r *repo) count(ctx context.Context, userID int64) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT count(*) FROM children WHERE user_id=$1 AND deleted_at IS NULL`, userID).Scan(&n)
	return n, err
}

func (r *repo) list(ctx context.Context, userID int64) ([]Child, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, public_id, name, gender, birthday, diagnosis_type, language_level, interests, avatar_url, is_default, created_at, updated_at
		FROM children WHERE user_id=$1 AND deleted_at IS NULL ORDER BY created_at ASC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Child
	for rows.Next() {
		c, err := scanChild(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func (r *repo) create(ctx context.Context, userID int64, in childInput) (*Child, error) {
	interests, _ := json.Marshal(in.Interests)
	const q = `
		INSERT INTO children (id, public_id, user_id, name, gender, birthday, diagnosis_type, language_level, interests)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
		RETURNING id, public_id, name, gender, birthday, diagnosis_type, language_level, interests, avatar_url, is_default, created_at, updated_at`
	row := r.pool.QueryRow(ctx, q, r.ids.Next(), idgen.PublicID("c"), userID,
		in.Name, in.Gender, in.Birthday, in.DiagnosisType, in.LanguageLevel, interests)
	return scanChild(row)
}

// update applies partial fields; returns ErrNoRows-equivalent via nil result.
func (r *repo) update(ctx context.Context, userID int64, publicID string, in childInput) (*Child, error) {
	var interests interface{}
	if in.Interests != nil {
		b, _ := json.Marshal(in.Interests)
		interests = b
	}
	const q = `
		UPDATE children SET
			name = COALESCE($3, name),
			gender = COALESCE($4, gender),
			birthday = COALESCE($5, birthday),
			diagnosis_type = COALESCE($6, diagnosis_type),
			language_level = COALESCE($7, language_level),
			interests = COALESCE($8, interests)
		WHERE public_id = $1 AND user_id = $2 AND deleted_at IS NULL
		RETURNING id, public_id, name, gender, birthday, diagnosis_type, language_level, interests, avatar_url, is_default, created_at, updated_at`
	row := r.pool.QueryRow(ctx, q, publicID, userID,
		in.Name, in.Gender, in.Birthday, in.DiagnosisType, in.LanguageLevel, interests)
	ch, err := scanChild(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return ch, err
}

func (r *repo) softDelete(ctx context.Context, userID int64, publicID string) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`UPDATE children SET deleted_at = now() WHERE public_id=$1 AND user_id=$2 AND deleted_at IS NULL`,
		publicID, userID)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// setDefault makes publicID the account's sole default child (transactional).
// Returns false if the child doesn't exist / isn't owned by the user.
func (r *repo) setDefault(ctx context.Context, userID int64, publicID string) (bool, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return false, err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx,
		`UPDATE children SET is_default=false WHERE user_id=$1 AND is_default AND deleted_at IS NULL`,
		userID); err != nil {
		return false, err
	}
	tag, err := tx.Exec(ctx,
		`UPDATE children SET is_default=true WHERE public_id=$1 AND user_id=$2 AND deleted_at IS NULL`,
		publicID, userID)
	if err != nil {
		return false, err
	}
	if tag.RowsAffected() == 0 {
		return false, nil
	}
	return true, tx.Commit(ctx)
}

// childInput carries create/update fields. Pointers allow partial update.
type childInput struct {
	Name          *string
	Gender        *string
	Birthday      *time.Time
	DiagnosisType *string
	LanguageLevel *string
	Interests     []string
}

func scanChild(row pgx.Row) (*Child, error) {
	var c Child
	var interests []byte
	err := row.Scan(&c.ID, &c.PublicID, &c.Name, &c.Gender, &c.Birthday,
		&c.DiagnosisType, &c.LanguageLevel, &interests, &c.AvatarURL, &c.IsDefault, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, err
	}
	if len(interests) > 0 {
		_ = json.Unmarshal(interests, &c.Interests)
	}
	return &c, nil
}
