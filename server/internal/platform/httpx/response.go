package httpx

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Envelope is the uniform response shape: { code, message, data, request_id }.
type Envelope struct {
	Code      int         `json:"code"`
	Message   string      `json:"message"`
	Data      interface{} `json:"data"`
	RequestID string      `json:"request_id"`
}

// APIError is a business error carrying a numeric code, HTTP status and message.
type APIError struct {
	Code    int
	HTTP    int
	Message string
}

func (e *APIError) Error() string { return e.Message }

// NewError builds an APIError.
func NewError(code, httpStatus int, msg string) *APIError {
	return &APIError{Code: code, HTTP: httpStatus, Message: msg}
}

func requestID(c *gin.Context) string {
	if v, ok := c.Get(CtxRequestID); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// OK writes a success envelope.
func OK(c *gin.Context, data interface{}) {
	c.JSON(http.StatusOK, Envelope{
		Code: 0, Message: "ok", Data: data, RequestID: requestID(c),
	})
}

// Fail writes an error envelope. If err is an *APIError its fields are used;
// otherwise a generic 500 is returned (internal detail is not leaked).
func Fail(c *gin.Context, err error) {
	if ae, ok := err.(*APIError); ok {
		c.JSON(ae.HTTP, Envelope{
			Code: ae.Code, Message: ae.Message, Data: nil, RequestID: requestID(c),
		})
		return
	}
	c.JSON(http.StatusInternalServerError, Envelope{
		Code: ErrInternal.Code, Message: ErrInternal.Message, Data: nil, RequestID: requestID(c),
	})
}

// AbortFail writes the error and aborts the handler chain (for middleware).
func AbortFail(c *gin.Context, err error) {
	Fail(c, err)
	c.Abort()
}
