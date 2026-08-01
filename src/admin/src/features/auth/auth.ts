import type { Session } from '../../lib/api'

interface Claims {
  role?: string
  'http://schemas.microsoft.com/ws/2008/06/identity/claims/role'?: string
}

export function roleFromSession(session: Session | null): string | null {
  if (!session?.token) return null
  try {
    const payload = session.token.split('.')[1]
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/')
    const claims = JSON.parse(atob(base64)) as Claims
    return claims.role ?? claims['http://schemas.microsoft.com/ws/2008/06/identity/claims/role'] ?? null
  } catch {
    return null
  }
}
