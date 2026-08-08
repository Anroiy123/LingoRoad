import { beforeEach, describe, expect, it, vi } from 'vitest'
import { api, ApiError, sessionExpiredEvent, sessionStore } from './api'

describe('Admin API client', () => {
  beforeEach(() => { sessionStore.clear(); vi.restoreAllMocks() })

  it('giữ error và errors[] từ validation response', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({ error:'validation_failed', errors:['invalid_cefr','unknown_skill'] }), { status:400, headers:{ 'Content-Type':'application/json' } }))
    const reason = await api('/admin/items/generate').catch((error: unknown) => error)
    expect(reason).toBeInstanceOf(ApiError)
    expect(reason).toMatchObject({ status:400, code:'validation_failed', error:'validation_failed', errors:['invalid_cefr','unknown_skill'] })
  })

  it('xóa session và phát event khi refresh thất bại', async () => {
    sessionStore.save({ token:'expired', refreshToken:'refresh' }); const listener = vi.fn(); window.addEventListener(sessionExpiredEvent, listener)
    vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(new Response(null, { status:401 })).mockResolvedValueOnce(new Response(null, { status:401 }))
    await expect(api('/admin/users')).rejects.toMatchObject({ status:401 })
    expect(sessionStore.load()).toBeNull(); expect(listener).toHaveBeenCalledOnce(); window.removeEventListener(sessionExpiredEvent, listener)
  })
})
