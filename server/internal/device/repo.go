package device

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

type user struct {
	PublicID        string
	AppAccountToken uuid.UUID
}

type repo struct {
	pool *pgxpool.Pool
	ids  *idgen.Snowflake
}

// findOrCreate returns the existing user for deviceID, or inserts a new one.
// Uses ON CONFLICT to remain safe under concurrent first-registrations.
func (r *repo) findOrCreate(ctx context.Context, deviceID string) (*user, error) {
	// Happy-path: device already registered.
	var u user
	err := r.pool.QueryRow(ctx,
		`SELECT public_id, app_account_token FROM users WHERE device_id = $1`, deviceID,
	).Scan(&u.PublicID, &u.AppAccountToken)
	if err == nil {
		return &u, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}

	// New device — allocate a snowflake id and a public_id.
	id := r.ids.Next()
	publicID := fmt.Sprintf("u_%d", id)

	_, err = r.pool.Exec(ctx,
		`INSERT INTO users (id, public_id, device_id)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (device_id) DO NOTHING`,
		id, publicID, deviceID,
	)
	if err != nil {
		return nil, err
	}

	// Re-fetch; handles the ON CONFLICT DO NOTHING race where another goroutine won.
	err = r.pool.QueryRow(ctx,
		`SELECT public_id, app_account_token FROM users WHERE device_id = $1`, deviceID,
	).Scan(&u.PublicID, &u.AppAccountToken)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// userIDByDevice looks up the internal user id for a device_id.
// Returns (0, nil) when not found.
func (r *repo) userIDByDevice(ctx context.Context, deviceID string) (int64, error) {
	var id int64
	err := r.pool.QueryRow(ctx,
		`SELECT id FROM users WHERE device_id = $1 AND status = 1`, deviceID,
	).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}
	return id, nil
}
