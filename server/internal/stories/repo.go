package stories

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// Story is a featured (精选) story row. RawJSON is the full coze story payload.
type Story struct {
	PublicID  string
	Title     string
	ImageURL  string
	WordCount int
	RawJSON   json.RawMessage
	Sort      int
	CreatedAt time.Time
}

type repo struct {
	pool *pgxpool.Pool
	ids  *idgen.Snowflake
}

// listAll returns featured stories in display order.
func (r *repo) listAll(ctx context.Context) ([]Story, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT public_id, title, image_url, word_count, raw_json, sort, created_at
		FROM featured_stories ORDER BY sort ASC, created_at ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Story
	for rows.Next() {
		var s Story
		var img *string
		if err := rows.Scan(&s.PublicID, &s.Title, &img, &s.WordCount, &s.RawJSON, &s.Sort, &s.CreatedAt); err != nil {
			return nil, err
		}
		if img != nil {
			s.ImageURL = *img
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// etag derives a list fingerprint from row count + latest update time. Any
// insert/delete/update changes one of them, so the ETag changes too. No
// separate version table needed.
func (r *repo) etag(ctx context.Context) (string, error) {
	var count int64
	var maxUpdated time.Time
	err := r.pool.QueryRow(ctx,
		`SELECT count(*), COALESCE(max(updated_at), 'epoch'::timestamptz) FROM featured_stories`,
	).Scan(&count, &maxUpdated)
	if err != nil {
		return "", err
	}
	seed := fmt.Sprintf("%d:%d", count, maxUpdated.UnixNano())
	sum := sha1.Sum([]byte(seed))
	return `"` + hex.EncodeToString(sum[:]) + `"`, nil // quoted per HTTP ETag syntax
}

// insert creates a featured story from a raw coze payload + extracted columns.
func (r *repo) insert(ctx context.Context, in insertInput) (*Story, error) {
	const q = `
		INSERT INTO featured_stories (id, public_id, title, image_url, word_count, raw_json, sort)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		RETURNING public_id, title, image_url, word_count, raw_json, sort, created_at`
	row := r.pool.QueryRow(ctx, q, r.ids.Next(), idgen.PublicID("feat"),
		in.Title, nullable(in.ImageURL), in.WordCount, in.RawJSON, in.Sort)
	var s Story
	var img *string
	if err := row.Scan(&s.PublicID, &s.Title, &img, &s.WordCount, &s.RawJSON, &s.Sort, &s.CreatedAt); err != nil {
		return nil, err
	}
	if img != nil {
		s.ImageURL = *img
	}
	return &s, nil
}

func (r *repo) deleteByPublicID(ctx context.Context, publicID string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM featured_stories WHERE public_id=$1`, publicID)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

type insertInput struct {
	Title     string
	ImageURL  string
	WordCount int
	RawJSON   json.RawMessage
	Sort      int
}

func nullable(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}
