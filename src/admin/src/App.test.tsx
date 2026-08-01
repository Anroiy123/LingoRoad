import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import App from './App'
import { sessionStore } from './lib/api'

const token = (role: string): string => `header.${btoa(JSON.stringify({ role }))}.signature`

describe('Admin app guard và trạng thái API', () => {
  beforeEach(() => {
    sessionStore.clear()
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
      mastery: [],
    }), { status: 200, headers: { 'Content-Type': 'application/json' } }))
    render(<App />)
    await waitFor(() => expect(screen.getByText('75%')).toBeTruthy())
    expect(screen.getByText('Chưa có dữ liệu mastery.')).toBeTruthy()
    expect(screen.getByText('Protected · Admin')).toBeTruthy()
  })

  it('tạo skill rồi reset form mà không rơi vào unexpected_error', async () => {
    sessionStore.save({ token: token('Admin'), refreshToken: 'refresh' })
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      const url = String(input)
      if (url.endsWith('/admin/analytics/overview')) return new Response(JSON.stringify({
        learners: 0, activeLearners: 0, completedLessons: 0, answers: 0,
        correctAnswers: 0, correctness: 0, dueReviews: 0,
        content: { skills: 0, lessons: 0, publishedLessons: 0, items: 0 }, mastery: [],
      }), { status: 200, headers: { 'Content-Type': 'application/json' } })
      if (url.endsWith('/admin/skills') && init?.method === 'POST') return new Response(
        JSON.stringify({ id: 1 }), { status: 201, headers: { 'Content-Type': 'application/json' } },
      )
      if (url.endsWith('/admin/skills')) return new Response(JSON.stringify([]),
        { status: 200, headers: { 'Content-Type': 'application/json' } })
      throw new Error(`Unexpected request: ${url}`)
    })
    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'Kỹ năng' }))
    fireEvent.change(await screen.findByLabelText('Code'), { target: { value: 'grammar.test' } })
    fireEvent.change(screen.getByLabelText('Tên', { exact: true }), { target: { value: 'Test' } })
    fireEvent.change(screen.getByLabelText('Tên tiếng Việt'), { target: { value: 'Kiểm thử' } })
    fireEvent.click(screen.getByRole('button', { name: 'Tạo mới' }))
    await waitFor(() => expect(screen.getByRole('status').textContent).toContain('Đã lưu kỹ năng.'))
  })
})
