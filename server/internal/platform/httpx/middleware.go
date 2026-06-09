package httpx

import (
	"crypto/rand"
	"encoding/hex"
	"strings"

	"github.com/gin-gonic/gin"
)

// Context keys.
const (
	CtxRequestID = "request_id"
	CtxUserID    = "user_id"    // int64, set by AuthRequired
	CtxAdminUser = "admin_user" // string username
	CtxAdminRole = "admin_role" // string role
)

// RequestID assigns a request id and echoes it in the X-Request-Id header.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader("X-Request-Id")
		if id == "" {
			id = "req_" + randHex(12)
		}
		c.Set(CtxRequestID, id)
		c.Header("X-Request-Id", id)
		c.Next()
	}
}

// Recovery turns panics into a clean 500 envelope.
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				AbortFail(c, ErrInternal)
			}
		}()
		c.Next()
	}
}

// CORS allows the configured origins.
func CORS(allowed []string) gin.HandlerFunc {
	allowAll := len(allowed) == 1 && allowed[0] == "*"
	set := map[string]bool{}
	for _, o := range allowed {
		set[o] = true
	}
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if allowAll {
			c.Header("Access-Control-Allow-Origin", "*")
		} else if origin != "" && set[origin] {
			c.Header("Access-Control-Allow-Origin", origin)
		}
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization,Content-Type,X-Device-Id,X-App-Version,X-Platform,X-Request-Id,X-Idempotency-Key")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}

// UserID returns the authenticated user id (0 if absent).
func UserID(c *gin.Context) int64 {
	if v, ok := c.Get(CtxUserID); ok {
		if id, ok := v.(int64); ok {
			return id
		}
	}
	return 0
}

// BearerToken extracts the token from the Authorization header.
func BearerToken(c *gin.Context) string {
	h := c.GetHeader("Authorization")
	if strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}
	return ""
}

func randHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
