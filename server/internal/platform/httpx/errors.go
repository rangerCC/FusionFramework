package httpx

import "net/http"

// Business error codes — mirror Doc/api/99-error-codes.md.
var (
	// Common 1xxx
	ErrBadParam    = NewError(1000, http.StatusBadRequest, "参数错误")
	ErrBadJSON     = NewError(1001, http.StatusBadRequest, "请求体格式错误")
	ErrRateLimited = NewError(1002, http.StatusTooManyRequests, "请求过于频繁，请稍后再试")
	ErrInternal    = NewError(1003, http.StatusInternalServerError, "服务器开小差了")
	ErrNotFound    = NewError(1004, http.StatusNotFound, "资源不存在")

	// Auth 2xxx
	ErrUnauthorized   = NewError(2001, http.StatusUnauthorized, "登录已失效，请重新登录")
	ErrBadPhone       = NewError(2002, http.StatusBadRequest, "手机号格式不正确")
	ErrBadCode        = NewError(2003, http.StatusBadRequest, "验证码错误")
	ErrCodeExpired    = NewError(2004, http.StatusBadRequest, "验证码已过期，请重新获取")
	ErrSMSTooFrequent = NewError(2005, http.StatusTooManyRequests, "验证码发送过于频繁")
	ErrCodeTooMany    = NewError(2006, http.StatusBadRequest, "验证码错误次数过多，请重新获取")
	ErrRefreshInvalid = NewError(2007, http.StatusUnauthorized, "刷新令牌无效或已过期")
	ErrRefreshReplay  = NewError(2008, http.StatusUnauthorized, "登录状态异常，请重新登录")

	// Account 3xxx
	ErrWechatBound  = NewError(3001, http.StatusConflict, "该微信已被其他账号绑定")
	ErrAlreadyBound = NewError(3002, http.StatusConflict, "已绑定该登录方式")
	ErrLastIdentity = NewError(3003, http.StatusBadRequest, "不能解绑唯一的登录方式")
	ErrNotOwner     = NewError(3004, http.StatusForbidden, "无权操作该账户")
	ErrBadNickname  = NewError(3005, http.StatusBadRequest, "昵称不合法")

	// Children 4xxx
	ErrChildNotFound   = NewError(4001, http.StatusNotFound, "孩子档案不存在")
	ErrChildNotOwner   = NewError(4002, http.StatusForbidden, "无权操作该档案")
	ErrChildIncomplete = NewError(4003, http.StatusBadRequest, "孩子信息不完整")
	ErrChildTooMany    = NewError(4004, http.StatusBadRequest, "超出孩子数量上限")

	// Subscription 5xxx
	ErrTxVerify   = NewError(5001, http.StatusBadRequest, "交易校验失败")
	ErrTxNotOwned = NewError(5002, http.StatusBadRequest, "交易不属于当前账户")
	ErrSubSync    = NewError(5003, http.StatusInternalServerError, "订阅状态同步失败")

	// Usage 6xxx
	ErrQuotaExhausted = NewError(6001, http.StatusForbidden, "本月免费次数已用完")

	// Admin 9xxx
	ErrAdminUnauth    = NewError(9001, http.StatusUnauthorized, "管理员未登录")
	ErrAdminForbidden = NewError(9002, http.StatusForbidden, "权限不足")

	// Not implemented this phase (wechat/apple)
	ErrNotEnabled = NewError(1004, http.StatusNotFound, "该功能暂未开放")
)
