package device

import (
	"github.com/gin-gonic/gin"

	"github.com/alitrip/socialstory-server/internal/platform/httpx"
)

// DeviceRequired reads the X-Device-Id header, looks up the user in the DB,
// and stores the user id in the gin context under httpx.CtxUserID.
// Aborts with 401 if the header is missing/short or the device is unknown/banned.
func (h *Handler) DeviceRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		deviceID := c.GetHeader("X-Device-Id")
		if len(deviceID) < 8 {
			httpx.AbortFail(c, httpx.ErrUnauthorized)
			return
		}
		uid, err := h.repo.userIDByDevice(c.Request.Context(), deviceID)
		if err != nil || uid == 0 {
			httpx.AbortFail(c, httpx.ErrUnauthorized)
			return
		}
		c.Set(httpx.CtxUserID, uid)
		c.Next()
	}
}
