package auth

import (
	"github.com/gin-gonic/gin"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/util"
)

// Handler wires auth endpoints to the service.
type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler { return &Handler{svc: svc} }

// Register mounts public auth routes under the given group.
func (h *Handler) Register(r *gin.RouterGroup) {
	r.POST("/auth/sms/send", h.sendCode)
	r.POST("/auth/login/sms", h.loginSMS)
	r.POST("/auth/login/wechat", h.loginWechat)
	r.POST("/auth/token/refresh", h.refresh)
}

// RegisterAuthed mounts auth routes that require a valid access token.
func (h *Handler) RegisterAuthed(r *gin.RouterGroup) {
	r.POST("/auth/logout", h.logout)
}

func userJSON(u *User) gin.H {
	return gin.H{
		"user_id":           u.PublicID,
		"nickname":          u.Nickname,
		"avatar_url":        u.AvatarURL,
		"app_account_token": u.AppAccountToken,
		"bindings":          gin.H{"phone": true, "wechat": false, "apple": false},
	}
}

type sendCodeReq struct {
	Phone string `json:"phone"`
	Scene string `json:"scene"`
}

func (h *Handler) sendCode(c *gin.Context) {
	var req sendCodeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	if req.Scene == "" {
		req.Scene = "login"
	}
	resend, err := h.svc.SendCode(c.Request.Context(), req.Phone, req.Scene)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, gin.H{"expires_in": int(codeTTL.Seconds()), "resend_after": resend})
}

type loginSMSReq struct {
	Phone    string `json:"phone"`
	Code     string `json:"code"`
	DeviceID string `json:"device_id"`
}

func (h *Handler) loginSMS(c *gin.Context) {
	var req loginSMSReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	res, err := h.svc.LoginSMS(c.Request.Context(), req.Phone, req.Code, req.DeviceID)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	u := userJSON(res.User)
	u["phone_masked"] = util.MaskPhone(req.Phone)
	httpx.OK(c, gin.H{
		"access_token":  res.Tokens.AccessToken,
		"refresh_token": res.Tokens.RefreshToken,
		"expires_in":    res.Tokens.ExpiresIn,
		"is_new_user":   res.IsNewUser,
		"user":          u,
	})
}

func (h *Handler) loginWechat(c *gin.Context) {
	// Not enabled this phase (see Doc). Reserved for wechat unionid login.
	httpx.Fail(c, httpx.ErrNotEnabled)
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token"`
	DeviceID     string `json:"device_id"`
}

func (h *Handler) refresh(c *gin.Context) {
	var req refreshReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	pair, err := h.svc.Refresh(c.Request.Context(), req.RefreshToken, req.DeviceID)
	if err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, gin.H{
		"access_token":  pair.AccessToken,
		"refresh_token": pair.RefreshToken,
		"expires_in":    pair.ExpiresIn,
	})
}

type logoutReq struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) logout(c *gin.Context) {
	var req logoutReq
	if err := c.ShouldBindJSON(&req); err != nil {
		httpx.Fail(c, httpx.ErrBadJSON)
		return
	}
	if err := h.svc.Logout(c.Request.Context(), req.RefreshToken); err != nil {
		httpx.Fail(c, err)
		return
	}
	httpx.OK(c, nil)
}
