package device

import (
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
)

// Handler serves device-identity endpoints.
type Handler struct{ repo *repo }

// NewHandler wires up the handler with its repo.
func NewHandler(pool *pgxpool.Pool, ids *idgen.Snowflake) *Handler {
	return &Handler{repo: &repo{pool: pool, ids: ids}}
}

// Register mounts the public device routes.
func (h *Handler) Register(r *gin.RouterGroup) {
	r.POST("/device/register", h.register)
}

type registerReq struct {
	DeviceID string `json:"device_id" binding:"required"`
}

// register finds or creates the user for the given device_id.
func (h *Handler) register(c *gin.Context) {
	var req registerReq
	if err := c.ShouldBindJSON(&req); err != nil || len(req.DeviceID) < 8 {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	u, err := h.repo.findOrCreate(c.Request.Context(), req.DeviceID)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, gin.H{
		"public_id":         u.PublicID,
		"app_account_token": u.AppAccountToken.String(),
	})
}
