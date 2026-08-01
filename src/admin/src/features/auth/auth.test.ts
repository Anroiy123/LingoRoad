import { describe, expect, it } from 'vitest'
import { roleFromSession } from './auth'

const token = (claims: object): string => `header.${btoa(JSON.stringify(claims))}.signature`

describe('roleFromSession', () => {
  it('đọc role claim ngắn và claim URI của .NET', () => {
    expect(roleFromSession({ token: token({ role: 'Admin' }), refreshToken: 'r' })).toBe('Admin')
    expect(roleFromSession({
      token: token({ 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': 'Learner' }),
      refreshToken: 'r',
    })).toBe('Learner')
  })

  it('fail closed với token sai', () => {
    expect(roleFromSession({ token: 'invalid', refreshToken: 'r' })).toBeNull()
    expect(roleFromSession(null)).toBeNull()
  })
})
