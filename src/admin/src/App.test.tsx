import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'
import { sessionExpiredEvent, sessionStore } from './lib/api'

const token = (role: string): string => `header.${btoa(JSON.stringify({ role }))}.signature`

describe('Admin app guard và trạng thái API', () => {
  beforeEach(() => {
    sessionStore.clear()
    window.history.replaceState(null, '', '/')
    vi.restoreAllMocks()
  })

  it('chặn session không có role Admin trước khi tải dữ liệu', () => {
    sessionStore.save({ token: token('Learner'), refreshToken: 'refresh' })
    const fetchMock = vi.spyOn(globalThis, 'fetch')
    render(<App />)
    expect(screen.getByText('Không có quyền truy cập')).toBeTruthy()
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('hiển thị lỗi đăng nhập và cho phép thử lại', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(
      JSON.stringify({ error: 'invalid_credentials' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    ))
    render(<App />)
    expect(screen.getByRole('img', { name: 'LingoRoad' })).toBeTruthy()
    fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'admin@example.test' } })
    fireEvent.change(screen.getByLabelText('Mật khẩu'), { target: { value: 'wrong-password' } })
    fireEvent.click(screen.getByRole('button', { name: 'Đăng nhập' }))
    await waitFor(() => expect(screen.getByRole('alert').textContent).toContain('invalid_credentials'))
    expect(screen.getByRole('button', { name: 'Đăng nhập' })).toBeTruthy()
  })

  it('render analytics thật cho Admin và có empty mastery state', async () => {
    sessionStore.save({ token: token('Admin'), refreshToken: 'refresh' })
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({
      learners: 10, activeLearners: 4, completedLessons: 7, answers: 20,
      correctAnswers: 15, correctness: .75, dueReviews: 3,
      content: { skills: 174, lessons: 20, publishedLessons: 20, items: 100 },
      mastery: [], itemUsage: [],
    }), { status: 200, headers: { 'Content-Type': 'application/json' } }))
    render(<App />)
    await waitFor(() => expect(screen.getByText('75%')).toBeTruthy())
    expect(screen.getByRole('img', { name: 'LingoRoad' })).toBeTruthy()
    expect(screen.getByText('Chưa có dữ liệu mastery.')).toBeTruthy()
    expect(screen.getByText('Vùng bảo vệ')).toBeTruthy()
  })

  it('tạo skill rồi reset form mà không rơi vào unexpected_error', async () => {
    sessionStore.save({ token: token('Admin'), refreshToken: 'refresh' })
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      const url = String(input)
      if (url.endsWith('/admin/analytics/overview')) return new Response(JSON.stringify({
        learners: 0, activeLearners: 0, completedLessons: 0, answers: 0,
        correctAnswers: 0, correctness: 0, dueReviews: 0,
        content: { skills: 0, lessons: 0, publishedLessons: 0, items: 0 }, mastery: [], itemUsage: [],
      }), { status: 200, headers: { 'Content-Type': 'application/json' } })
      if (url.endsWith('/admin/skills') && init?.method === 'POST') return new Response(
        JSON.stringify({ id: 1 }), { status: 201, headers: { 'Content-Type': 'application/json' } },
      )
      if (url.endsWith('/admin/skills')) return new Response(JSON.stringify([]),
        { status: 200, headers: { 'Content-Type': 'application/json' } })
      throw new Error(`Unexpected request: ${url}`)
    })
    render(<App />)
    fireEvent.click(await screen.findByRole('link', { name: 'Kỹ năng' }))
    fireEvent.click(await screen.findByRole('button', { name: 'Tạo kỹ năng' }))
    fireEvent.change(await screen.findByLabelText('Code'), { target: { value: 'grammar.test' } })
    fireEvent.change(screen.getByLabelText('Tên', { exact: true }), { target: { value: 'Test' } })
    fireEvent.change(screen.getByLabelText('Tên tiếng Việt'), { target: { value: 'Kiểm thử' } })
    fireEvent.click(screen.getByRole('button', { name: 'Tạo mới' }))
    await waitFor(() => expect(screen.getByRole('status').textContent).toContain('Đã lưu kỹ năng.'))
  })

  it('đưa React session về login khi nhận sự kiện hết hạn', async () => {
    sessionStore.save({ token: token('Admin'), refreshToken: 'refresh' })
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({ learners:0, activeLearners:0, completedLessons:0, answers:0, correctAnswers:0, correctness:0, dueReviews:0, content:{ skills:0, lessons:0, publishedLessons:0, items:0 }, mastery:[], itemUsage:[] }), { status:200, headers:{ 'Content-Type':'application/json' } }))
    render(<App />); window.dispatchEvent(new Event(sessionExpiredEvent))
    expect(await screen.findByRole('heading', { name:'Chào mừng trở lại' })).toBeTruthy()
    expect(screen.getByRole('alert').textContent).toContain('hết hạn')
  })

  it('đăng xuất UI kể cả API logout trả 500', async () => {
    sessionStore.save({ token: token('Admin'), refreshToken: 'refresh' })
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
      const path = new URL(String(input)).pathname
      if (path === '/auth/logout') return new Response(JSON.stringify({ error:'server_error' }), { status:500, headers:{ 'Content-Type':'application/json' } })
      if (path === '/admin/audit') return new Response(JSON.stringify([]), { status:200, headers:{ 'Content-Type':'application/json' } })
      return new Response(JSON.stringify({ learners:0, activeLearners:0, completedLessons:0, answers:0, correctAnswers:0, correctness:0, dueReviews:0, content:{ skills:0, lessons:0, publishedLessons:0, items:0 }, mastery:[], itemUsage:[] }), { status:200, headers:{ 'Content-Type':'application/json' } })
    })
    render(<App />); fireEvent.click(await screen.findByRole('button', { name:'Đăng xuất' }))
    expect(await screen.findByRole('heading', { name:'Chào mừng trở lại' })).toBeTruthy(); expect(sessionStore.load()).toBeNull()
  })
})
