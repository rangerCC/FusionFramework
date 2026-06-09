package account

import (
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/oss"
	"github.com/alitrip/socialstory-server/internal/util"
)

// Handler serves account endpoints (all require auth).
type Handler struct {
	repo   *repo
	signer oss.Signer
}

func NewHandler(pool *pgxpool.Pool, signer oss.Signer) *Handler {
	return &Handler{repo: &repo{pool: pool}, signer: signer}
}

func (h *Handler) Register(r *gin.RouterGroup) {
	r.GET("/account/profile", h.getProfile)
	r.PUT("/account/profile", h.updateProfile)
	r.POST("/account/avatar/upload-url", h.avatarUploadURL)
	r.GET("/account/bindings", h.getBindings)
	r.POST("/account/bind/wechat", h.bindWechat)
	r.DELETE("/account/bind/:provider", h.unbind)
	r.POST("/account/deactivate", h.deactivate)
}

func (h *Handler) getProfile(c *gin.Context) {
	uid := httpx.UserID(c)
	p, err := h.repo.getProfile(c.Request.Context(), uid)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if p == nil {
		httpx.Fail(c, httpx.ErrUnauthorized)
		return
	}
	httpx.OK(c, profileJSON(p))
}

type updateProfileReq struct {
	Nickname  *string `json:"nickname"`
	AvatarURL *string `json:"avatar_url"`
}

func (h *Handler) updateProfile(c *gin.Context) {
	var req updateProfileReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	if req.Nickname != nil {
		n := len([]rune(*req.Nickname))
		if n == 0 || n > 24 {
			httpx.Fail(c, httpx.ErrBadNickname)
			return
		}
	}
	uid := httpx.UserID(c)
	if err := h.repo.updateProfile(c.Request.Context(), uid, req.Nickname, req.AvatarURL); err != nil {
		httpx.Fail(c, err)
		return
	}
	p, err := h.repo.getProfile(c.Request.Context(), uid)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, profileJSON(p))
}

func (h *Handler) avatarUploadURL(c *gin.Context) {
	uid := httpx.UserID(c)
	p, err := h.repo.getProfile(c.Request.Context(), uid)
	if err != nil || p == nil {
		httpx.Fail(c, httpx.ErrUnauthorized)
		return
	}
	grant, err := h.signer.AvatarUploadGrant(p.PublicID)
	if err != nil {
		httpx.Fail(c, httpx.ErrInternal)
		return
	}
	httpx.OK(c, grant)
}

func (h *Handler) getBindings(c *gin.Context) {
	uid := httpx.UserID(c)
	bs, err := h.repo.bindings(c.Request.Context(), uid)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	have := map[string]string{}
	for _, b := range bs {
		have[b.Provider] = b.Identifier
	}
	out := []gin.H{}
	for _, p := range []string{"phone", "wechat", "apple"} {
		var masked interface{}
		bound := false
		if id, ok := have[p]; ok {
			bound = true
			if p == "phone" {
				masked = util.MaskPhone(id)
			}
		}
		out = append(out, gin.H{"provider": p, "bound": bound, "identifier_masked": masked})
	}
	httpx.OK(c, gin.H{"bindings": out})
}

func (h *Handler) bindWechat(c *gin.Context) { httpx.Fail(c, httpx.ErrNotEnabled) }
func (h *Handler) unbind(c *gin.Context)     { httpx.Fail(c, httpx.ErrNotEnabled) }

func (h *Handler) deactivate(c *gin.Context) {
	// Note: production should re-verify an SMS code here before deactivating.
	uid := httpx.UserID(c)
	if err := h.repo.deactivate(c.Request.Context(), uid); err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, nil)
}

func profileJSON(p *Profile) gin.H {
	var phoneMasked interface{}
	if p.Phone != nil {
		phoneMasked = util.MaskPhone(*p.Phone)
	}
	return gin.H{
		"user_id":           p.PublicID,
		"nickname":          p.Nickname,
		"avatar_url":        p.AvatarURL,
		"phone_masked":      phoneMasked,
		"app_account_token": p.AppAccountToken,
		"bindings":          gin.H{"phone": p.Phone != nil, "wechat": false, "apple": false},
		"created_at":        p.CreatedAt,
	}
}
