// Minimal auth state in localStorage: the admin JWT + role. Role drives which
// write actions the UI exposes (the server also enforces via requireRole).

const TOKEN_KEY = 'ss_admin_token'
const ROLE_KEY = 'ss_admin_role'
const NAME_KEY = 'ss_admin_name'

export type AdminRole = 'super' | 'support' | 'viewer'

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function getRole(): AdminRole | null {
  return (localStorage.getItem(ROLE_KEY) as AdminRole) || null
}

export function getName(): string {
  return localStorage.getItem(NAME_KEY) || 'admin'
}

export function isLoggedIn(): boolean {
  return !!getToken()
}

export function setAuth(token: string, role: string, name: string) {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(ROLE_KEY, role)
  localStorage.setItem(NAME_KEY, name)
}

export function clearAuth() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(ROLE_KEY)
  localStorage.removeItem(NAME_KEY)
}

/** True if the current role is allowed (any of the given roles). */
export function hasRole(...roles: AdminRole[]): boolean {
  const r = getRole()
  return !!r && roles.includes(r)
}
