package subscription

import (
	"io"

	"github.com/gin-gonic/gin"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
)

// Handler serves subscription endpoints.
type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// RegisterAuthed mounts endpoints requiring a logged-in user.
func (h *Handler) RegisterAuthed(r *gin.RouterGroup) {
	r.GET("/subscription", h.current)
	r.POST("/subscription/verify", h.verify)
}

// RegisterPublic mounts the Apple webhook (no app auth; JWS-verified).
func (h *Handler) RegisterPublic(r *gin.RouterGroup) {
	r.POST("/webhook/appstore/notifications", h.webhook)
}

func subJSON(s *Sub) gin.H {
	if s == nil {
		return gin.H{"is_active": false, "status": "none"}
	}
	return gin.H{
		"is_active":   s.Status == "active",
		"product_id":  s.ProductID,
		"expires_at":  s.ExpiresAt,
		"auto_renew":  s.AutoRenew,
		"status":      s.Status,
		"environment": s.Environment,
		"source":      "app_store",
	}
}

func (h *Handler) current(c *gin.Context) {
	sub, err := h.svc.Current(c.Request.Context(), httpx.UserID(c))
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, subJSON(sub))
}

type verifyReq struct {
	TransactionID string `json:"transaction_id"`
}

func (h *Handler) verify(c *gin.Context) {
	var req verifyReq
	if err := c.ShouldBindJSON(&req); err != nil || req.TransactionID == "" {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	uid := httpx.UserID(c)
	token, _ := h.svc.UserToken(c.Request.Context(), uid)
	sub, err := h.svc.Verify(c.Request.Context(), uid, token, req.TransactionID)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, subJSON(sub))
}

type webhookReq struct {
	SignedPayload string `json:"signedPayload"`
}

func (h *Handler) webhook(c *gin.Context) {
	var req webhookReq
	if err := c.ShouldBindJSON(&req); err != nil || req.SignedPayload == "" {
		// Drain body and still 200 to avoid Apple hammering on malformed test pings,
		// but signal nothing processed.
		_, _ = io.Copy(io.Discard, c.Request.Body)
		c.Status(400)
		return
	}
	if err := h.svc.HandleNotification(c.Request.Context(), req.SignedPayload); err != nil {
		// Non-2xx makes Apple retry.
		c.Status(500)
		return
	}
	c.Status(200)
}
