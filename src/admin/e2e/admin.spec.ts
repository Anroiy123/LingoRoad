import { expect, test, type Page } from '@playwright/test'
import AxeBuilder from '@axe-core/playwright'

const token = (role: string): string => {
  const claims = Buffer.from(JSON.stringify({ role })).toString('base64url')
  return `header.${claims}.signature`
}

const installVisualMocks = async (page: Page): Promise<void> => {
  await page.addInitScript((session) => window.sessionStorage.setItem('lingoroad.admin.session', JSON.stringify(session)), { token:token('Admin'), refreshToken:'visual-refresh' })
  await page.route('http://localhost:5000/**', async (route) => {
    const url = new URL(route.request().url()); const path = url.pathname
    if (path === '/admin/analytics/overview') { await route.fulfill({ json:{ learners:128, activeLearners:74, completedLessons:912, answers:3840, correctAnswers:2940, correctness:.766, dueReviews:236, content:{ skills:176, lessons:20, publishedLessons:18, items:112 }, mastery:[{ category:'grammar', average:.71 },{ category:'vocabulary', average:.64 },{ category:'reading', average:.79 },{ category:'listening', average:.58 }], itemUsage:[{ itemId:'grammar.present.001', attempts:86, correctness:.78 },{ itemId:'vocabulary.travel.004', attempts:72, correctness:.63 },{ itemId:'reading.work.002', attempts:65, correctness:.82 }] } }); return }
    if (path === '/admin/analytics/learning-quality') { await route.fulfill({ json:{ generatedAt:'2026-08-08T03:00:00Z', minimumSampleSize:30, calibration:{ samples:340,status:'sufficient',meanPredicted:.72,observedCorrectness:.75,brierScore:.184 }, byCefr:[{ key:'A1',samples:120,status:'sufficient',correctness:.82 },{ key:'A2',samples:94,status:'sufficient',correctness:.76 },{ key:'B1',samples:78,status:'sufficient',correctness:.69 },{ key:'B2',samples:18,status:'insufficient_sample',correctness:null }], bySkill:[{ key:'1',samples:95,status:'sufficient',correctness:.76 }], byItem:[{ key:'item-1',samples:86,status:'sufficient',correctness:.78 }], byLesson:[{ key:'lesson-1',samples:72,status:'sufficient',correctness:.74 }], drift:{ recentSamples:190,baselineSamples:150,status:'sufficient',recentCorrectness:.76,baselineCorrectness:.73,delta:.03 }, fairness:{ samples:0,status:'insufficient_sample',reason:'Chưa có thuộc tính nhân khẩu học đã được consent.' } } }); return }
    if (path === '/admin/users') { const role = url.searchParams.get('role'); const learnerRows = [{ id:'learner-1', email:'lan@example.test', name:'Nguyễn Lan', role:'Learner', targetCefr:'B1', createdAt:'2026-08-02T00:00:00Z' },{ id:'learner-2', email:'minh@example.test', name:'Trần Minh', role:'Learner', targetCefr:'A2', createdAt:'2026-08-03T00:00:00Z' }]; const adminRows = [{ id:'admin-1', email:'admin@lingoroad.dev', name:'Quản trị viên', role:'Admin', targetCefr:null, createdAt:'2026-08-01T00:00:00Z' }]; const users = role === 'Admin' ? adminRows : role === 'Learner' ? learnerRows : [...learnerRows,...adminRows]; await route.fulfill({ json:{ total:users.length, users } }); return }
    if (path === '/admin/skills') { await route.fulfill({ json:[{ id:1, code:'grammar.present', name:'Present tense', nameVi:'Thì hiện tại', category:'grammar', parentId:null, cefrLevel:'A1' },{ id:2, code:'vocabulary.travel', name:'Travel', nameVi:'Du lịch', category:'vocabulary', parentId:null, cefrLevel:'A2' }] }); return }
    if (path === '/admin/items') { await route.fulfill({ json:[{ id:'item-1', stableId:'grammar.present.001', skillId:1, skillCode:'grammar.present', cefrLevel:'A1', type:'mcq', stem:'Choose the correct present tense form.', options:['go','goes'], correctAnswer:'goes', explanationVi:'Ngôi thứ ba số ít.', source:'LingoRoad', license:'Proprietary', reviewer:'Reviewer', contentVersion:'v1', a:1, b:0, c:.5, audioUrl:null }] }); return }
    if (path === '/admin/lessons') { await route.fulfill({ json:[{ id:'lesson-1', stableId:'lesson.present.01', slug:'present-simple', title:'Present Simple', titleVi:'Thì hiện tại đơn', descriptionVi:'Nền tảng ngữ pháp A1', skillId:1, skillCode:'grammar.present', cefrLevel:'A1', order:1, isPublished:true, itemIds:['item-1'], contentVersion:'v1', source:'LingoRoad', license:'Proprietary', reviewer:'Reviewer', updatedAt:'2026-08-08T00:00:00Z' },{ id:'lesson-2', stableId:'lesson.travel.01', slug:'travel-basics', title:'Travel Basics', titleVi:'Từ vựng du lịch', descriptionVi:'Từ vựng thiết yếu', skillId:2, skillCode:'vocabulary.travel', cefrLevel:'A2', order:2, isPublished:false, itemIds:[], contentVersion:'v1', source:'LingoRoad', license:'Proprietary', reviewer:'Reviewer', updatedAt:'2026-08-08T00:00:00Z' }] }); return }
    if (path === '/admin/audit') { await route.fulfill({ json:[{ id:1, action:'update', entityType:'lesson', entityId:'lesson-1', createdAt:'2026-08-08T02:00:00Z', adminUserId:'admin-1', detail:'Published lesson' },{ id:2, action:'create', entityType:'item', entityId:'item-1', createdAt:'2026-08-08T01:00:00Z', adminUserId:'admin-1', detail:'Created item' }] }); return }
    await route.fulfill({ json:[] })
  })
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
    if (path === '/admin/audit') { await route.fulfill({ json: [] }); return }
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

  await page.getByRole('link', { name: 'Kỹ năng' }).click()
  await page.getByRole('button', { name: 'Tạo kỹ năng' }).click()
  await page.getByLabel('Code').fill('grammar.browser')
  await page.getByLabel('Tên', { exact: true }).fill('Browser grammar')
  await page.getByLabel('Tên tiếng Việt').fill('Ngữ pháp browser')
  await page.getByRole('button', { name: 'Tạo mới' }).click()
  await expect(page.getByRole('status')).toContainText('Đã lưu kỹ năng.')
  await expect(page.getByRole('cell', { name: 'grammar.browser' })).toBeVisible()

  await page.getByRole('link', { name: 'Import' }).click()
  await page.getByRole('button', { name: 'Validate / Preview' }).click()
  await expect(page.locator('pre')).toContainText('content_required')
})

test('route Users debounce, phân trang và detail 404 dùng API thật', async ({ page }) => {
  await page.addInitScript((session) => window.sessionStorage.setItem('lingoroad.admin.session', JSON.stringify(session)), { token:token('Admin'), refreshToken:'refresh' })
  const userRequests: string[] = []
  await page.route('http://localhost:5000/**', async (route) => {
    const url = new URL(route.request().url()); const path = url.pathname
    if (path === '/admin/users') { userRequests.push(url.search); const second = url.searchParams.get('offset') === '50'; await route.fulfill({ json:{ total:51, users:[{ id:second ? '22222222-2222-2222-2222-222222222222' : '11111111-1111-1111-1111-111111111111', email:second ? 'admin@example.test' : 'lan@example.test', name:second ? 'Admin' : 'Lan', role:second ? 'Admin' : 'Learner', targetCefr:'B1', createdAt:'2026-08-01T00:00:00Z' }] } }); return }
    if (path.endsWith('22222222-2222-2222-2222-222222222222')) { await route.fulfill({ json:{ id:'22222222-2222-2222-2222-222222222222', email:'admin@example.test', name:'Admin', role:'Admin', targetCefr:'B2', createdAt:'2026-08-01T00:00:00Z', mastery:[], activity:{ lessonsCompleted:2, exercisesAnswered:4, exercisesCorrect:3, dueReviews:1, lastActiveAt:null } } }); return }
    if (path.startsWith('/admin/users/')) { await route.fulfill({ status:404, json:{ error:'not_found' } }); return }
    await route.fulfill({ json:[] })
  })
  await page.goto('/users'); await expect(page.getByRole('heading', { name:'User Management' })).toBeVisible()
  await page.getByPlaceholder('Tên, email hoặc ID…').fill('lan')
  await expect.poll(() => userRequests.some((query) => query.includes('search=lan') && query.includes('limit=50') && query.includes('offset=0'))).toBeTruthy()
  await page.getByLabel('Vai trò').selectOption('Admin'); await expect.poll(() => userRequests.some((query) => query.includes('role=Admin'))).toBeTruthy(); await page.getByRole('button', { name:'Sau' }).click(); await expect.poll(() => userRequests.some((query) => query.includes('offset=50'))).toBeTruthy()
  await page.getByRole('link', { name:'Xem chi tiết' }).click(); await expect(page.getByRole('heading', { level:1, name:'Admin' })).toBeVisible(); await page.goto('/users/33333333-3333-3333-3333-333333333333'); await expect(page.getByRole('heading', { name:'Không tìm thấy người dùng' })).toBeVisible()
})

test('mobile drawer điều hướng đến Analytics', async ({ page }) => {
  await page.setViewportSize({ width:390, height:844 })
  await page.addInitScript((session) => window.sessionStorage.setItem('lingoroad.admin.session', JSON.stringify(session)), { token:token('Admin'), refreshToken:'refresh' })
  await page.route('http://localhost:5000/**', async (route) => { const path = new URL(route.request().url()).pathname; if (path === '/admin/analytics/overview') await route.fulfill({ json:{ learners:0, activeLearners:0, completedLessons:0, answers:0, correctAnswers:0, correctness:0, dueReviews:0, content:{ skills:0, lessons:0, publishedLessons:0, items:0 }, mastery:[], itemUsage:[] } }); else if (path === '/admin/analytics/learning-quality') await route.fulfill({ json:{ generatedAt:'2026-08-05T00:00:00Z', minimumSampleSize:30, calibration:{ samples:0,status:'insufficient_sample',meanPredicted:null,observedCorrectness:null,brierScore:null }, byCefr:[],bySkill:[],byItem:[],byLesson:[],drift:{ recentSamples:0,baselineSamples:0,status:'insufficient_sample',recentCorrectness:null,baselineCorrectness:null,delta:null },fairness:{ samples:0,status:'insufficient_sample',reason:'No consented demographic attributes.' } } }); else await route.fulfill({ json:[] }) })
  await page.goto('/overview'); const opener = page.getByRole('button', { name:'Mở menu' }); await opener.click(); await expect(page.getByRole('button', { name:'Đóng menu' }).last()).toBeFocused(); await page.keyboard.press('Escape'); await expect(opener).toBeFocused(); await opener.click(); await page.getByRole('link', { name:'Phân tích' }).click()
  const heading = page.getByRole('heading', { name:'Analytics & Reports' }); await expect(heading).toBeVisible(); await expect(heading).toBeFocused(); await expect(page.getByText('Chưa đủ mẫu').first()).toBeVisible()
  const violations = (await new AxeBuilder({ page }).withTags(['wcag2a','wcag2aa']).analyze()).violations.filter((row) => row.impact === 'serious' || row.impact === 'critical')
  expect(violations).toEqual([])
})

test('bảng desktop hiển thị đủ cột, không tạo vùng cuộn ngang hoặc hở tiêu đề', async ({ page }) => {
  await page.setViewportSize({ width:1440, height:900 }); await installVisualMocks(page)
  for (const path of ['/users','/skills','/items','/lessons','/audit']) {
    await page.goto(path); const wrap = page.locator('.table-wrap').first(); await expect(wrap).toBeVisible()
    const size = await wrap.evaluate((element) => ({ clientWidth:element.clientWidth, scrollWidth:element.scrollWidth })); expect(size.scrollWidth).toBeLessThanOrEqual(size.clientWidth + 1)
    const wrapBox = await wrap.boundingBox(); const lastHeading = await wrap.locator('thead th').last().boundingBox(); expect(wrapBox).not.toBeNull(); expect(lastHeading).not.toBeNull(); expect(Math.abs((lastHeading!.x + lastHeading!.width) - (wrapBox!.x + wrapBox!.width))).toBeLessThanOrEqual(2)
    if (await wrap.evaluate((element) => element.classList.contains('table-wrap-actions'))) { const actions = await wrap.locator('tbody .table-actions').first().boundingBox(); expect(actions).not.toBeNull(); const headingCenter = lastHeading!.x + lastHeading!.width / 2; const actionsCenter = actions!.x + actions!.width / 2; expect(Math.abs(headingCenter - actionsCenter)).toBeLessThanOrEqual(2) }
    if (path === '/items') { const stem = page.getByTitle('Choose the correct present tense form.'); await stem.hover(); await expect(stem).toHaveAttribute('title', 'Choose the correct present tense form.') }
  }
})

test('bảng mobile giữ cột thao tác trong vùng nhìn thấy khi cuộn ngang', async ({ page }) => {
  await page.setViewportSize({ width:390, height:844 }); await page.addInitScript((session) => window.sessionStorage.setItem('lingoroad.admin.session', JSON.stringify(session)), { token:token('Admin'), refreshToken:'refresh' }); const items = Array.from({ length:45 }, (_, index) => ({ id:`item-${index + 1}`, stableId:`grammar.present.${String(index + 1).padStart(3, '0')}`, skillId:1, skillCode:'grammar.present', cefrLevel:'A1', type:index % 2 ? 'cloze' : 'mcq', stem:`Câu hỏi ${index + 1}`, options:['a','b'], correctAnswer:'a', explanationVi:'', source:'LingoRoad', license:'Proprietary', reviewer:'Reviewer', contentVersion:'v1', a:1, b:0, c:.5, audioUrl:null })); await page.route('http://localhost:5000/**', async (route) => { const path = new URL(route.request().url()).pathname; if (path === '/admin/items') await route.fulfill({ json:items }); else if (path === '/admin/skills') await route.fulfill({ json:[] }); else await route.fulfill({ json:[] }) }); await page.goto('/items')
  const table = page.locator('.table-wrap-actions'); await expect(table).toBeVisible()
  const overflow = await table.evaluate((element) => ({ clientWidth:element.clientWidth, scrollWidth:element.scrollWidth })); expect(overflow.scrollWidth).toBeGreaterThan(overflow.clientWidth)
  const row = table.locator('tbody tr').first(); const typeCell = row.locator('.table-pin-secondary'); const actionCell = row.locator('td').last(); const assertPinned = async (): Promise<void> => { const wrapBox = await table.boundingBox(); const typeBox = await typeCell.boundingBox(); const actionBox = await actionCell.boundingBox(); expect(wrapBox).not.toBeNull(); expect(typeBox).not.toBeNull(); expect(actionBox).not.toBeNull(); expect(actionBox!.x + actionBox!.width).toBeLessThanOrEqual(wrapBox!.x + wrapBox!.width + 1); expect(typeBox!.x).toBeGreaterThanOrEqual(wrapBox!.x - 1); expect(typeBox!.x + typeBox!.width).toBeLessThanOrEqual(actionBox!.x + 1) }
  await assertPinned(); await table.evaluate((element) => { element.scrollLeft = element.scrollWidth }); await assertPinned()
  await expect(typeCell).toContainText('mcq'); await expect(actionCell.getByRole('button', { name:'Sửa' })).toBeVisible(); await expect(actionCell.getByRole('button', { name:'Xóa' })).toBeVisible(); await expect(page.getByText('Hiển thị 1–20 / 45')).toBeVisible(); await page.getByRole('button', { name:'Sau' }).click(); await expect(page.getByText('Hiển thị 21–40 / 45')).toBeVisible(); await expect(page.getByText('Câu hỏi 21')).toBeVisible()
})

test('AI item xử lý validation, rate limit, unavailable, success và không gửi trùng', async ({ page }) => {
  await page.addInitScript((session) => window.sessionStorage.setItem('lingoroad.admin.session', JSON.stringify(session)), { token:token('Admin'), refreshToken:'refresh' })
  let generation = 0; let itemReads = 0
  await page.route('http://localhost:5000/**', async (route) => {
    const request = route.request(); const path = new URL(request.url()).pathname
    if (path === '/admin/skills') { await route.fulfill({ json:[{ id:1, code:'grammar.present', name:'Present', nameVi:'Hiện tại', category:'grammar', parentId:null, cefrLevel:'A1' }] }); return }
    if (path === '/admin/items' && request.method() === 'GET') { itemReads++; await route.fulfill({ json:[] }); return }
    if (path === '/admin/items/generate') { generation++; await new Promise((resolve) => setTimeout(resolve, generation === 4 ? 400 : 80)); if (generation === 1) await route.fulfill({ status:400, json:{ error:'validation_failed', errors:['unknown_skill'] } }); else if (generation === 2) await route.fulfill({ status:429, json:{ error:'rate_limited' } }); else if (generation === 3) await route.fulfill({ status:503, json:{ error:'ml_unavailable' } }); else await route.fulfill({ status:201, json:{ generated:1, items:[] } }); return }
    await route.fulfill({ json:[] })
  })
  await page.goto('/items')
  const run = async (expected: string): Promise<void> => { await page.getByRole('button', { name:'Tạo bằng AI' }).click(); await page.getByLabel('Kỹ năng').last().selectOption('grammar.present'); await page.getByRole('button', { name:'Xác nhận tạo' }).click(); await expect(page.getByRole('alert')).toContainText(expected); await page.getByRole('button', { name:'Hủy' }).click() }
  await run('unknown_skill'); await run('vượt giới hạn'); await run('tạm gián đoạn')
  await page.getByRole('button', { name:'Tạo bằng AI' }).click(); await page.getByLabel('Kỹ năng').last().selectOption('grammar.present'); await page.getByRole('button', { name:'Xác nhận tạo' }).click(); await expect(page.getByRole('button', { name:'Đang tạo…' })).toBeDisabled(); await expect(page.getByRole('status')).toContainText('Đã tạo 1 item')
  expect(generation).toBe(4); expect(itemReads).toBeGreaterThan(1)
})

test('delete và import chỉ mutation sau confirmation dialog', async ({ page }) => {
  await page.addInitScript((session) => window.sessionStorage.setItem('lingoroad.admin.session', JSON.stringify(session)), { token:token('Admin'), refreshToken:'refresh' })
  let deletes = 0; let applies = 0
  await page.route('http://localhost:5000/**', async (route) => {
    const request = route.request(); const path = new URL(request.url()).pathname
    if (path === '/admin/skills' && request.method() === 'GET') { await route.fulfill({ json:[{ id:1, code:'grammar.delete', name:'Delete', nameVi:'Xóa', category:'grammar', parentId:null, cefrLevel:'A1' }] }); return }
    if (path === '/admin/skills/1' && request.method() === 'DELETE') { deletes++; await route.fulfill({ status:204 }); return }
    if (path === '/admin/imports/validate') { await route.fulfill({ json:{ valid:true, checksum:'abc123', counts:{ skills:0,items:0,lessons:0 }, errors:[] } }); return }
    if (path === '/admin/imports') { applies++; await route.fulfill({ json:{ replay:false, checksum:'abc123' } }); return }
    await route.fulfill({ json:[] })
  })
  await page.goto('/skills'); await page.getByRole('button', { name:'Xóa' }).click(); await expect(page.getByRole('dialog')).toBeVisible(); await page.getByRole('button', { name:'Hủy' }).click(); expect(deletes).toBe(0)
  await page.getByRole('button', { name:'Xóa' }).click(); await page.getByRole('button', { name:'Xóa kỹ năng' }).click(); await expect.poll(() => deletes).toBe(1)
  await page.getByRole('link', { name:'Import' }).click(); const apply = page.getByRole('button', { name:'Apply' }); const validate = page.getByRole('button', { name:'Validate / Preview' }); await expect(apply).toBeDisabled(); await validate.click(); await expect(apply).toBeEnabled(); const editor = page.getByLabel('Content bundle JSON'); await editor.fill(`${await editor.inputValue()} `); await expect(apply).toBeDisabled(); await validate.click(); await expect(apply).toBeEnabled(); await apply.click(); expect(applies).toBe(0); await expect(page.getByRole('dialog')).toContainText('abc123'); await page.getByRole('button', { name:'Xác nhận Apply' }).click(); await expect.poll(() => applies).toBe(1)
})

test('visual regression bốn màn Stitch desktop', async ({ page }) => {
  await page.setViewportSize({ width:1440, height:900 }); await installVisualMocks(page)
  const screens = [
    { path:'/overview', heading:'Dashboard Overview', snapshot:'stitch-overview.png' },
    { path:'/users', heading:'User Management', snapshot:'stitch-users.png' },
    { path:'/lessons', heading:'Lesson Management', snapshot:'stitch-lessons.png' },
    { path:'/analytics', heading:'Analytics & Reports', snapshot:'stitch-analytics.png' },
  ]
  for (const screen of screens) {
    await page.goto(screen.path); await expect(page.getByRole('heading', { level:1, name:screen.heading })).toBeVisible()
    if (screen.path === '/overview') {
      const metrics = await page.locator('.content-metrics').boundingBox(); const nextSection = await page.locator('.overview-grid').first().boundingBox()
      expect(metrics).not.toBeNull(); expect(nextSection).not.toBeNull(); expect(nextSection!.y - (metrics!.y + metrics!.height)).toBeGreaterThanOrEqual(16)
    }
    if (screen.path === '/lessons') {
      const row = await page.locator('tbody tr').first().boundingBox(); const actionCell = await page.locator('tbody tr').first().locator('td').last().boundingBox(); const edit = await page.locator('tbody tr').first().getByRole('button', { name:'Sửa' }).boundingBox()
      expect(row).not.toBeNull(); expect(actionCell).not.toBeNull(); expect(edit).not.toBeNull(); expect(actionCell!.height).toBeCloseTo(row!.height, 0); expect(Math.abs((edit!.y + edit!.height / 2) - (row!.y + row!.height / 2))).toBeLessThan(1)
    }
    await expect(page).toHaveScreenshot(screen.snapshot, { fullPage:true, animations:'disabled' })
  }
})

test('visual regression navigation mobile', async ({ page }) => {
  await page.setViewportSize({ width:390, height:844 }); await installVisualMocks(page); await page.goto('/overview'); await page.getByRole('button', { name:'Mở menu' }).click(); await expect(page.getByRole('navigation', { name:'Điều hướng chính' })).toBeVisible(); await expect(page).toHaveScreenshot('stitch-mobile-navigation.png', { fullPage:true, animations:'disabled' })
})
