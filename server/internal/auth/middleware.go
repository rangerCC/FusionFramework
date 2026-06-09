package auth

import (
	"github.com/gin-gonic/gin"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
	"github.com/alitrip/socialstory-server/internal/platform/jwtx"
)

// AuthRequired returns middleware that validates the access token and stores the
// internal user id in the context. The token's subject is the numeric user id.
func AuthRequired(jwt *jwtx.Manager) gin.HandlerFunc {
	return func(c *gin.Context) {
		tok := httpx.BearerToken(c)
		if tok == "" {
			httpx.AbortFail(c, httpx.ErrUnauthorized)
			return
		}
		uid, err := jwt.Verify(tok)
		if err != nil || uid == 0 {
			httpx.AbortFail(c, httpx.ErrUnauthorized)
			return
		}
		c.Set(httpx.CtxUserID, uid)
		c.Next()
	}
}
