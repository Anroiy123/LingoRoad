import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ItemsPanel } from './ItemsPage'
import { LessonsPanel } from './LessonsPage'

const json = (value: unknown, status = 200): Response => new Response(JSON.stringify(value), { status, headers:{ 'Content-Type':'application/json' } })
const skill = { id:7, code:'grammar.present', name:'Present', nameVi:'Hiện tại', category:'grammar', parentId:null, cefrLevel:'A1' }
const item = { id:'11111111-1111-1111-1111-111111111111', stableId:null, skillId:7, skillCode:'grammar.present', cefrLevel:'A1', type:'mcq', stem:'Old stem', options:['A','B'], correctAnswer:'A', explanationVi:null, source:'AI generated (model-x)', license:null, reviewer:null, contentVersion:null, a:1.7, b:-0.35, c:0.42, audioUrl:'https://cdn.example/audio.mp3' }
const lesson = { id:'22222222-2222-2222-2222-222222222222', stableId:'lesson-1', slug:'lesson-one', title:'Lesson One', titleVi:'Bài một', descriptionVi:null, skillId:7, skillCode:'grammar.present', cefrLevel:'A1', order:1, isPublished:false, itemIds:[item.id], source:'Imported source', license:null, reviewer:null, contentVersion:null, updatedAt:'2026-08-05T00:00:00Z' }

describe('bảo toàn metadata khi edit', () => {
  beforeEach(() => vi.restoreAllMocks())

  it('Item PUT giữ nullable metadata và IRT/audio fields', async () => {
    let payload: Record<string, unknown> | undefined
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => { const path = new URL(String(input)).pathname; if (path === '/admin/skills') return json([skill]); if (path === `/admin/items/${item.id}` && init?.method === 'PUT') { payload = JSON.parse(String(init.body)) as Record<string, unknown>; return new Response(null, { status:204 }) } if (path === '/admin/items') return json([item]); throw new Error(path) })
    render(<ItemsPanel />); fireEvent.click(await screen.findByRole('button', { name:'Sửa' })); fireEvent.change(screen.getByLabelText('Câu hỏi'), { target:{ value:'Updated stem' } }); fireEvent.click(screen.getByRole('button', { name:'Lưu thay đổi' }))
    await waitFor(() => expect(payload).toBeDefined()); expect(payload).toMatchObject({ stableId:null, source:item.source, license:null, reviewer:null, contentVersion:null, a:1.7, b:-0.35, c:0.42, audioUrl:item.audioUrl, stem:'Updated stem' })
  })

  it('Lesson PUT giữ source và nullable import metadata', async () => {
    let payload: Record<string, unknown> | undefined
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => { const path = new URL(String(input)).pathname; if (path === '/admin/skills') return json([skill]); if (path === '/admin/items') return json([item]); if (path === `/admin/lessons/${lesson.id}` && init?.method === 'PUT') { payload = JSON.parse(String(init.body)) as Record<string, unknown>; return new Response(null, { status:204 }) } if (path === '/admin/lessons') return json([lesson]); throw new Error(path) })
    render(<LessonsPanel />); fireEvent.click(await screen.findByRole('button', { name:'Sửa' })); fireEvent.change(screen.getByLabelText('Tiêu đề Việt'), { target:{ value:'Bài một mới' } }); fireEvent.click(screen.getByRole('button', { name:'Lưu thay đổi' }))
    await waitFor(() => expect(payload).toBeDefined()); expect(payload).toMatchObject({ source:lesson.source, license:null, reviewer:null, contentVersion:null, titleVi:'Bài một mới' })
  })
})
