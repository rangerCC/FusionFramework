import http from './http'

// ---- shared types ----
export interface Page<T> {
  items: T[]
  total: number
  page: number
  page_size: number
}

export interface UserRow {
  user_id: string
  nickname: string
  phone_masked: string | null
  status: number
  is_subscribed: boolean
  children_count: number
  created_at: string
}

export interface UserDetail {
  profile: Record<string, unknown>
  bindings: { provider: string; identifier: string }[]
  children: Record<string, unknown>[]
  subscription: Record<string, unknown> | null
  usage: { period: string; used: number; quota: number | null }
}

export interface SubRow {
  user_id: string
  nickname: string
  product_id: string
  status: string
  expires_at: string | null
  auto_renew: boolean
  environment: string
  updated_at: string
}

export interface AuditRow {
  actor: string
  action: string
  target: string
  detail: unknown
  created_at: string
}

export interface FeaturedRow {
  story_id: string
  title: string
  image_url: string
  word_count: number
  sort: number
  created_at: string
  raw: unknown
}

export interface DashboardData {
  total_users: number
  new_users_today: number
  active_subscriptions: number
  revenue_estimate_month: number
  stories_generated_today: number
}

// ---- auth ----
export function login(username: string, password: string) {
  return http.post('/v1/admin/login', { username, password }) as Promise<{
    access_token: string
    expires_in: number
    role: string
  }>
}

// ---- dashboard ----
export function getDashboard() {
  return http.get('/v1/admin/dashboard') as Promise<DashboardData>
}

// ---- users ----
export function listUsers(params: { keyword?: string; page: number; page_size: number }) {
  return http.get('/v1/admin/users', { params }) as Promise<Page<UserRow>>
}
export function getUserDetail(userId: string) {
  return http.get(`/v1/admin/users/${userId}`) as Promise<UserDetail>
}
export function adjustQuota(userId: string, delta: number, reason: string) {
  return http.post(`/v1/admin/users/${userId}/quota`, { delta, reason })
}
export function setUserStatus(userId: string, status: number, reason: string) {
  return http.post(`/v1/admin/users/${userId}/status`, { status, reason })
}

// ---- subscriptions ----
export function listSubscriptions(params: {
  status?: string
  environment?: string
  keyword?: string
  page: number
  page_size: number
}) {
  return http.get('/v1/admin/subscriptions', { params }) as Promise<Page<SubRow>>
}

// ---- audit logs ----
export function listAuditLogs(params: {
  actor?: string
  action?: string
  target?: string
  page: number
  page_size: number
}) {
  return http.get('/v1/admin/audit-logs', { params }) as Promise<Page<AuditRow>>
}

// ---- featured stories ----
export function listFeatured() {
  return http.get('/v1/admin/featured-stories') as Promise<{ items: FeaturedRow[]; total: number }>
}
export function createFeatured(raw: unknown, sort: number) {
  return http.post('/v1/admin/featured-stories', { raw, sort })
}
export function deleteFeatured(storyId: string) {
  return http.delete(`/v1/admin/featured-stories/${storyId}`)
}
