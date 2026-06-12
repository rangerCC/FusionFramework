import axios, { AxiosError } from 'axios'
import { message } from 'antd'
import { clearAuth, getToken } from '../auth'

// Single axios instance. Base URL from env; Authorization injected per request;
// the {code,message,data} envelope is unwrapped so callers get `data` directly.
const http = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || 'http://localhost:8080',
  timeout: 20000,
})

http.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

http.interceptors.response.use(
  (resp) => {
    const body = resp.data
    // Endpoints that return 304 / empty (none here) fall through untouched.
    if (body && typeof body === 'object' && 'code' in body) {
      if (body.code === 0) {
        return body.data
      }
      // 9001: admin token invalid/expired → back to login.
      if (body.code === 9001) {
        clearAuth()
        if (location.hash !== '#/login') location.hash = '#/login'
      }
      message.error(body.message || `请求失败 (${body.code})`)
      return Promise.reject(new Error(body.message || `code ${body.code}`))
    }
    return body
  },
  (err: AxiosError) => {
    const status = err.response?.status
    const body = err.response?.data as { code?: number; message?: string } | undefined

    // The server returns the {code,message} envelope even on non-2xx statuses
    // (e.g. login failure is HTTP 401 + code 9001). Prefer the business message
    // over a generic "network error".
    if (body && typeof body === 'object' && typeof body.code === 'number') {
      // Token invalid/expired on an already-authenticated request → re-login.
      // (A failed login attempt also yields 9001, but there's no token to clear
      // and we're already on /login, so this is harmless there.)
      if (body.code === 9001 && getToken()) {
        clearAuth()
        if (location.hash !== '#/login') location.hash = '#/login'
      }
      message.error(body.message || `请求失败 (${body.code})`)
      return Promise.reject(new Error(body.message || `code ${body.code}`))
    }

    if (status === 401) {
      clearAuth()
      if (location.hash !== '#/login') location.hash = '#/login'
    }
    message.error(`网络错误${status ? ` (${status})` : ''}`)
    return Promise.reject(err)
  },
)

export default http
