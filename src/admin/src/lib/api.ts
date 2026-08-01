export interface Session {
  token: string
  refreshToken: string
}

export class ApiError extends Error {
  readonly status: number
  readonly code: string

  constructor(status: number, code: string) {
    super(code)
    this.status = status
    this.code = code
  }
}

const baseUrl = (import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5000').replace(/\/$/, '')
const sessionKey = 'lingoroad.admin.session'
let refreshPromise: Promise<boolean> | undefined

export const sessionStore = {
  load(): Session | null {
    try {
      const value = sessionStorage.getItem(sessionKey)
      return value ? (JSON.parse(value) as Session) : null
    } catch {
      return null
    }
  },
  save(session: Session): void {
    sessionStorage.setItem(sessionKey, JSON.stringify(session))
  },
  clear(): void {
    sessionStorage.removeItem(sessionKey)
  },
}

const refresh = async (): Promise<boolean> => {
  const session = sessionStore.load()
  if (!session?.refreshToken) return false
  const response = await fetch(`${baseUrl}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: session.refreshToken }),
  })
  if (!response.ok) {
    sessionStore.clear()
    return false
  }
  const next = (await response.json()) as Session
  sessionStore.save(next)
  return true
}

export async function api<T>(path: string, init: RequestInit = {}, retry = true): Promise<T> {
  const session = sessionStore.load()
  const headers = new Headers(init.headers)
  if (init.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json')
  if (session?.token) headers.set('Authorization', `Bearer ${session.token}`)
  const response = await fetch(`${baseUrl}${path}`, { ...init, headers })
  if (response.status === 401 && retry && session?.refreshToken) {
    refreshPromise ??= refresh().finally(() => {
      refreshPromise = undefined
    })
    if (await refreshPromise) return api<T>(path, init, false)
  }
  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as { error?: string }
    throw new ApiError(response.status, body.error ?? `http_${response.status}`)
  }
  if (response.status === 204) return undefined as T
  return response.json() as Promise<T>
}

export async function login(email: string, password: string): Promise<Session> {
  const session = await api<Session>('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  })
  sessionStore.save(session)
  return session
}

export async function logout(): Promise<void> {
  const session = sessionStore.load()
  try {
    if (session?.refreshToken) {
      await api('/auth/logout', {
        method: 'POST',
        body: JSON.stringify({ refreshToken: session.refreshToken }),
      })
    }
  } finally {
    sessionStore.clear()
  }
}
