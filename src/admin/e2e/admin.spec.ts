import { expect, test } from '@playwright/test'

const token = (role: string): string => {
  const claims = Buffer.from(JSON.stringify({ role })).toString('base64url')
  return `header.${claims}.signature`
}

test('chặn learner trước khi gọi Admin API', async ({ page }) => {
  await page.addInitScript((session) => {
    window.sessionStorage.setItem('lingoroad.admin.session', JSON.stringify(session))
  }, { token: token('Learner'), refreshToken: 'learner-refresh' })

  const requests: string[] = []
  page.on('request', (request) => {
    if (request.url().startsWith('http://localhost:5000')) requests.push(request.url())
  })
  await page.goto('/')

  await expect(page.getByRole('heading', { name: 'Không có quyền truy cập' })).toBeVisible()
  expect(requests).toEqual([])
})

test('đăng nhập, xem analytics, tạo skill và preview import lỗi', async ({ page }) => {
  const adminToken = token('Admin')
  const skills: Array<Record<string, unknown>> = []
  await page.route('http://localhost:5000/**', async (route) => {
    const request = route.request()
    const path = new URL(request.url()).pathname
    if (path === '/auth/login' && request.method() === 'POST') {
      await route.fulfill({ json: { token: adminToken, accessToken: adminToken, refreshToken: 'admin-refresh' } })
      return
    }
    if (path === '/admin/analytics/overview') {
      await route.fulfill({ json: {
        learners: 12, activeLearners: 5, completedLessons: 8, answers: 20,
        correctAnswers: 15, correctness: .75, dueReviews: 3,
        content: { skills: 174, lessons: 20, publishedLessons: 20, items: 100 },
        mastery: [], itemUsage: [],
      } })
      return
    }
    if (path === '/admin/skills' && request.method() === 'POST') {
      const body = request.postDataJSON() as Record<string, unknown>
      skills.push({ id: 501, parentId: null, ...body })
      await route.fulfill({ status: 201, json: { id: 501 } })
      return
    }
    if (path === '/admin/skills') {
      await route.fulfill({ json: skills })
      return
    }
    if (path === '/admin/imports/validate') {
      await route.fulfill({ json: {
        valid: false, checksum: 'test-checksum', counts: { skills: 0, items: 0, lessons: 0 },
        errors: ['content_required'],
      } })
      return
    }
    await route.fulfill({ status: 404, json: { error: `unhandled_${path}` } })
  })

  await page.goto('/')
  await page.getByLabel('Email').fill('admin@example.test')
  await page.getByLabel('Mật khẩu').fill('AdminPassword123')
  await page.getByRole('button', { name: 'Đăng nhập' }).click()
  await expect(page.getByText('75%')).toBeVisible()

  await page.getByRole('button', { name: 'Kỹ năng' }).click()
  await page.getByLabel('Code').fill('grammar.browser')
  await page.getByLabel('Tên', { exact: true }).fill('Browser grammar')
  await page.getByLabel('Tên tiếng Việt').fill('Ngữ pháp browser')
  await page.getByRole('button', { name: 'Tạo mới' }).click()
  await expect(page.getByRole('status')).toContainText('Đã lưu kỹ năng.')
  await expect(page.getByRole('cell', { name: 'grammar.browser' })).toBeVisible()

  await page.getByRole('button', { name: 'Import' }).click()
  await page.getByRole('button', { name: 'Validate / Preview' }).click()
  await expect(page.locator('pre')).toContainText('content_required')
})
