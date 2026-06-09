package usage

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// AdminOps exposes quota operations needed by the admin module, without
// exposing the full HTTP handler. Avoids the admin package importing handler glue.
type AdminOps struct {
	repo         *repo
	defaultQuota int
	loc          *time.Location
}

func NewAdminOps(pool *pgxpool.Pool, defaultQuota int) *AdminOps {
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		loc = time.UTC
	}
	return &AdminOps{repo: &repo{pool: pool}, defaultQuota: defaultQuota, loc: loc}
}

// Period returns the current YYYY-MM period.
func (a *AdminOps) Period() string { return time.Now().In(a.loc).Format("2006-01") }

// Adjust applies a delta to the current period's used count (clamped at 0).
// Returns the resulting (used, quota).
func (a *AdminOps) Adjust(ctx context.Context, userID int64, delta int) (used, quota int, err error) {
	return a.repo.adjust(ctx, userID, a.Period(), delta, a.defaultQuota)
}
