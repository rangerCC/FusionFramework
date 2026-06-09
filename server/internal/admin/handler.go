package admin

import (
	"encoding/json"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/idgen"
	"github.com/alitrip/socialstory-server/internal/platform/jwtx"
	"github.com/alitrip/socialstory-server/internal/usage"
	"github.com/alitrip/socialstory-server/internal/util"
)

// Handler serves the admin backend.
type Handler struct {
	repo  *repo
	jwt   *jwtx.Manager
	usage *usage.AdminOps
}

func NewHandler(pool *pgxpool.Pool, ids *idgen.Snowflake, jwt *jwtx.Manager, uops *usage.AdminOps) *Handler {
	return &Handler{repo: &repo{pool: pool, ids: ids}, jwt: jwt, usage: uops}
}

// RegisterPublic mounts admin login (no auth).
func (h *Handler) RegisterPublic(r *gin.RouterGroup) {
	r.POST("/admin/login", h.login)
}

// RegisterAuthed mounts admin routes behind AdminAuth middleware.
func (h *Handler) RegisterAuthed(r *gin.RouterGroup) {
	r.GET("/admin/users", h.listUsers)
	r.GET("/admin/users/:id", h.userDetail)
	r.POST("/admin/users/:id/quota", h.adjustQuota)
	r.POST("/admin/users/:id/status", h.setStatus)
	r.GET("/admin/dashboard", h.dashboard)
}

// AdminAuth validates the admin JWT and loads the role into context.
func (h *Handler) AdminAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		tok := httpx.BearerToken(c)
		if tok == "" {
			httpx.AbortFail(c, httpx.ErrAdminUnauth)
			return
		}
		id, err := h.jwt.Verify(tok)
		if err != nil || id == 0 {
			httpx.AbortFail(c, httpx.ErrAdminUnauth)
			return
		}
		a, err := h.repo.findAdminByID(c.Request.Context(), id)
		if err != nil || a == nil {
			httpx.AbortFail(c, httpx.ErrAdminUnauth)
			return
		}
		c.Set(httpx.CtxAdminUser, a.Username)
		c.Set(httpx.CtxAdminRole, a.Role)
		c.Next()
	}
}

func (h *Handler) role(c *gin.Context) string {
	if v, ok := c.Get(httpx.CtxAdminRole); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func (h *Handler) requireRole(c *gin.Context, roles ...string) bool {
	r := h.role(c)
	for _, want := range roles {
		if r == want {
			return true
		}
	}
	httpx.Fail(c, httpx.ErrAdminForbidden)
	return false
}

type loginReq struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func (h *Handler) login(c *gin.Context) {
	var req loginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	a, err := h.repo.findAdmin(c.Request.Context(), req.Username)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	if a == nil || bcrypt.CompareHashAndPassword([]byte(a.PasswordHash), []byte(req.Password)) != nil {
		httpx.Fail(c, httpx.ErrAdminUnauth)
		return
	}
	tok, err := h.jwt.Issue(a.ID)
	if err != nil {
		httpx.Fail(c, httpx.ErrInternal)
		return
	}
	httpx.OK(c, gin.H{"access_token": tok, "expires_in": 7200, "role": a.Role})
}

func (h *Handler) listUsers(c *gin.Context) {
	keyword := c.Query("keyword")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	if page < 1 {
		page = 1
	}
	size, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if size < 1 || size > 100 {
		size = 20
	}
	rows, total, err := h.repo.listUsers(c.Request.Context(), keyword, size, (page-1)*size)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	items := []gin.H{}
	for _, u := range rows {
		var phone interface{}
		if u.Phone != nil {
			phone = util.MaskPhone(*u.Phone)
		}
		items = append(items, gin.H{
			"user_id": u.PublicID, "nickname": u.Nickname, "phone_masked": phone,
			"status": u.Status, "is_subscribed": u.IsSubscribed,
			"children_count": u.ChildrenCount, "created_at": u.CreatedAt,
		})
	}
	httpx.OK(c, gin.H{"items": items, "total": total, "page": page, "page_size": size})
}

func (h *Handler) userDetail(c *gin.Context) {
	// Aggregation kept light here; returns the user list row shape plus ids.
	uid, err := h.repo.userIDByPublic(c.Request.Context(), c.Param("id"))
	if err != nil || uid == 0 {
		httpx.Fail(c, httpx.ErrNotFound)
		return
	}
	httpx.OK(c, gin.H{"user_id": c.Param("id"), "internal_id": uid})
}

type quotaReq struct {
	Delta  int    `json:"delta"`
	Reason string `json:"reason"`
}

func (h *Handler) adjustQuota(c *gin.Context) {
	if !h.requireRole(c, "super", "support") {
		return
	}
	var req quotaReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	uid, err := h.repo.userIDByPublic(c.Request.Context(), c.Param("id"))
	if err != nil || uid == 0 {
		httpx.Fail(c, httpx.ErrNotFound)
		return
	}
	// delta is "extra allowance" → reduce used by delta (negative used delta).
	used, quota, err := h.usage.Adjust(c.Request.Context(), uid, -req.Delta)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	detail, _ := json.Marshal(req)
	actor, _ := c.Get(httpx.CtxAdminUser)
	h.repo.audit(c.Request.Context(), toStr(actor), "quota.adjust", c.Param("id"), detail)
	remaining := quota - used
	if remaining < 0 {
		remaining = 0
	}
	httpx.OK(c, gin.H{"period": h.usage.Period(), "used": used, "remaining": remaining})
}

type statusReq struct {
	Status int16  `json:"status"`
	Reason string `json:"reason"`
}

func (h *Handler) setStatus(c *gin.Context) {
	if !h.requireRole(c, "super") {
		return
	}
	var req statusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	uid, err := h.repo.userIDByPublic(c.Request.Context(), c.Param("id"))
	if err != nil || uid == 0 {
		httpx.Fail(c, httpx.ErrNotFound)
		return
	}
	if err := h.repo.setUserStatus(c.Request.Context(), uid, req.Status); err != nil {
		httpx.Fail(c, err)
		return
	}
	detail, _ := json.Marshal(req)
	actor, _ := c.Get(httpx.CtxAdminUser)
	h.repo.audit(c.Request.Context(), toStr(actor), "user.status", c.Param("id"), detail)
	httpx.OK(c, nil)
}

func (h *Handler) dashboard(c *gin.Context) {
	data, err := h.repo.dashboard(c.Request.Context())
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, data)
}

func toStr(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	return "system"
}
