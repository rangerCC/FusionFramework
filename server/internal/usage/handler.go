package usage

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
)

// SubChecker reports whether a user currently has an active subscription.
// Implemented by the subscription module; injected to avoid an import cycle.
type SubChecker interface {
	IsActive(ctx context.Context, userID int64) (bool, error)
}

// Handler serves free-quota endpoints (all require auth).
type Handler struct {
	repo         *repo
	sub          SubChecker
	defaultQuota int
	loc          *time.Location
}

func NewHandler(pool *pgxpool.Pool, sub SubChecker, defaultQuota int) *Handler {
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		loc = time.UTC
	}
	return &Handler{repo: &repo{pool: pool}, sub: sub, defaultQuota: defaultQuota, loc: loc}
}

func (h *Handler) Register(r *gin.RouterGroup) {
	r.GET("/usage", h.get)
	r.POST("/usage/consume", h.consume)
}

func (h *Handler) period() string { return time.Now().In(h.loc).Format("2006-01") }

func (h *Handler) get(c *gin.Context) {
	uid := httpx.UserID(c)
	ctx := c.Request.Context()
	subscribed, err := h.sub.IsActive(ctx, uid)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	period := h.period()
	if subscribed {
		httpx.OK(c, gin.H{
			"can_generate": true, "is_subscribed": true,
			"monthly_quota": nil, "used": 0, "remaining": nil, "period": period,
		})
		return
	}
	used, quota, err := h.repo.get(ctx, uid, period, h.defaultQuota)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	remaining := quota - used
	if remaining < 0 {
		remaining = 0
	}
	httpx.OK(c, gin.H{
		"can_generate":  remaining > 0,
		"is_subscribed": false,
		"monthly_quota": quota,
		"used":          used,
		"remaining":     remaining,
		"period":        period,
	})
}

type consumeReq struct {
	StoryID string `json:"story_id"`
	ChildID string `json:"child_id"`
}

func (h *Handler) consume(c *gin.Context) {
	var req consumeReq
	_ = c.ShouldBindJSON(&req) // body optional
	uid := httpx.UserID(c)
	ctx := c.Request.Context()
	period := h.period()

	subscribed, err := h.sub.IsActive(ctx, uid)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if subscribed {
		_ = h.repo.recordSubscribed(ctx, uid, period)
		httpx.OK(c, gin.H{"remaining": nil, "used": 0})
		return
	}
	used, ok, err := h.repo.consumeFree(ctx, uid, period, h.defaultQuota)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if !ok {
		httpx.Fail(c, httpx.ErrQuotaExhausted)
		return
	}
	remaining := h.defaultQuota - used
	if remaining < 0 {
		remaining = 0
	}
	httpx.OK(c, gin.H{"remaining": remaining, "used": used})
}
