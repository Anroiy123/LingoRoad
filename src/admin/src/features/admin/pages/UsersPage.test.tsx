import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { sessionStore } from '../../../lib/api'
import { UsersPanel } from './UsersPage'

const json = (body: unknown) => new Response(JSON.stringify(body), { status:200, headers:{ 'Content-Type':'application/json' } })
const user = { id:'user-1', email:'learner@example.test', name:'Learner One', role:'Learner', targetCefr:'B1', createdAt:'2026-08-09T00:00:00Z' }

describe('Users server pagination', () => {
  beforeEach(() => { vi.restoreAllMocks(); sessionStore.save({ token:'admin-token', refreshToken:'refresh-token' }) })

  it('gửi limit/offset theo page size và reset khi search/filter đổi', async () => {
    const requested: string[] = []
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
      const url = new URL(String(input)); requested.push(`${url.pathname}${url.search}`)
      if (url.pathname === '/admin/analytics/overview') return json({ activeLearners:2 })
      const limit = Number(url.searchParams.get('limit')); return json({ total:30, users:limit === 1 ? [] : [user] })
    })
    render(<MemoryRouter><UsersPanel /></MemoryRouter>); expect(await screen.findByText('Learner One')).toBeVisible()
    expect(requested.some((url) => url.includes('limit=10&offset=0'))).toBe(true)
    fireEvent.click(screen.getByRole('button', { name:'Trang 2' })); await waitFor(() => expect(requested.some((url) => url.includes('limit=10&offset=10'))).toBe(true))
    fireEvent.change(screen.getByLabelText('Số dòng mỗi trang'), { target:{ value:'20' } }); await waitFor(() => expect(requested.some((url) => url.includes('limit=20&offset=0'))).toBe(true))
    fireEvent.change(screen.getByPlaceholderText('Tên, email hoặc ID…'), { target:{ value:'learner' } }); await waitFor(() => expect(requested.some((url) => url.includes('limit=20&offset=0') && url.includes('search=learner'))).toBe(true), { timeout:1000 })
    fireEvent.change(screen.getByLabelText('Vai trò'), { target:{ value:'Admin' } }); await waitFor(() => expect(requested.some((url) => url.includes('limit=20&offset=0') && url.includes('role=Admin'))).toBe(true))
  })
})
