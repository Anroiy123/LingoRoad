import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { sessionStore } from '../../../lib/api'
import { importCsvExample } from '../importCsv'
import { ImportPanel } from './OperationsPages'

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers:{ 'Content-Type':'application/json' } })
const preview = { valid:true, checksum:'csv-checksum', counts:{ skills:1, items:1, lessons:1 }, errors:[] }
const deferred = <T,>() => { let resolve!: (value: T) => void; let reject!: (reason?: unknown) => void; const promise = new Promise<T>((success, failure) => { resolve = success; reject = failure }); return { promise, resolve, reject } }
const pendingFile = (name: string, text: Promise<string>): File => ({ name, text:vi.fn(() => text) }) as unknown as File

describe('Content Import JSON và CSV', () => {
  beforeEach(() => { vi.restoreAllMocks(); sessionStore.save({ token:'admin-token', refreshToken:'refresh-token' }) })

  it('giữ luồng JSON validate và vô hiệu Apply khi payload đổi', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockResolvedValue(response({ ...preview, counts:{ skills:0, items:0, lessons:0 } }))
    render(<ImportPanel />); fireEvent.click(screen.getByRole('button', { name:'Validate / Preview' }))
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1)); expect(String(fetchMock.mock.calls[0][0])).toContain('/admin/imports/validate')
    expect(screen.getByRole('button', { name:'Apply' })).toBeEnabled()
    fireEvent.change(screen.getByLabelText('Content bundle JSON'), { target:{ value:'{}' } }); expect(screen.getByRole('button', { name:'Apply' })).toBeDisabled()
  })

  it('chuyển CSV sang JSON, preview, confirm và chỉ apply một lần', async () => {
    let applyResolve!: (value: Response) => void
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => String(input).endsWith('/admin/imports/validate') ? response(preview) : new Promise((resolve) => { applyResolve = resolve }))
    render(<ImportPanel />); fireEvent.click(screen.getByRole('button', { name:'CSV' })); fireEvent.change(screen.getByLabelText('Content bundle CSV'), { target:{ value:importCsvExample } }); fireEvent.click(screen.getByRole('button', { name:'Validate / Preview' }))
    await waitFor(() => expect(screen.getByRole('status').textContent).toContain('csv-checksum')); const validateBody = JSON.parse(String(fetchMock.mock.calls[0][1]?.body))
    expect(validateBody.skills[0].code).toBe('grammar.example'); expect(validateBody.items[0].options).toEqual(['Answer A','Answer B'])
    fireEvent.click(screen.getByRole('button', { name:'Apply' })); const confirm = screen.getByRole('button', { name:'Xác nhận Apply' }); fireEvent.click(confirm)
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2)); expect(String(fetchMock.mock.calls[1][0])).toMatch(/\/admin\/imports$/); expect(screen.queryByRole('button', { name:'Xác nhận Apply' })).not.toBeInTheDocument()
    applyResolve(response({ applied:true })); await waitFor(() => expect(screen.getByText(/"applied": true/)).toBeVisible()); expect(fetchMock).toHaveBeenCalledTimes(2)
  })

  it('hiển thị lỗi CSV cụ thể trước khi gọi API', async () => {
    const fetchMock = vi.spyOn(globalThis, 'fetch'); render(<ImportPanel />); fireEvent.click(screen.getByRole('button', { name:'CSV' })); fireEvent.change(screen.getByLabelText('Content bundle CSV'), { target:{ value:'kind,version\ninvalid,v1' } }); fireEvent.click(screen.getByRole('button', { name:'Validate / Preview' }))
    expect(await screen.findByText(/Header CSV không hợp lệ/)).toBeVisible(); expect(fetchMock).not.toHaveBeenCalled()
  })

  it('chỉ dùng kết quả của file được chọn mới nhất', async () => {
    const first = deferred<string>(); const second = deferred<string>(); render(<ImportPanel />); fireEvent.click(screen.getByRole('button', { name:'CSV' })); const input = screen.getByLabelText('Chọn file CSV')
    fireEvent.change(input, { target:{ files:[pendingFile('a.csv', first.promise)] } }); expect(screen.getByText('Đã chọn: a.csv')).toBeVisible()
    fireEvent.change(input, { target:{ files:[pendingFile('b.csv', second.promise)] } }); expect(screen.getByText('Đã chọn: b.csv')).toBeVisible()
    await act(async () => { first.resolve('nội dung A'); await first.promise }); expect(screen.getByText('Đã chọn: b.csv')).toBeVisible(); expect(screen.getByLabelText('Content bundle CSV')).not.toHaveValue('nội dung A')
    await act(async () => { second.resolve('nội dung B'); await second.promise }); expect(screen.getByLabelText('Content bundle CSV')).toHaveValue('nội dung B'); expect(screen.getByText('Đã chọn: b.csv')).toBeVisible()
  })

  it('bỏ qua file đang đọc khi đổi format', async () => {
    const pending = deferred<string>(); render(<ImportPanel />); fireEvent.click(screen.getByRole('button', { name:'CSV' })); fireEvent.change(screen.getByLabelText('Chọn file CSV'), { target:{ files:[pendingFile('late.csv', pending.promise)] } }); fireEvent.click(screen.getByRole('button', { name:'JSON' }))
    const jsonEditor = screen.getByLabelText('Content bundle JSON'); const jsonTemplate = (jsonEditor as HTMLTextAreaElement).value; expect(screen.queryByText('Đã chọn: late.csv')).not.toBeInTheDocument()
    await act(async () => { pending.resolve('CSV đến trễ'); await pending.promise }); expect(jsonEditor).toHaveValue(jsonTemplate); expect(screen.queryByText('Đã chọn: late.csv')).not.toBeInTheDocument()
  })

  it('hiển thị lỗi đọc file chỉ cho lựa chọn hiện tại', async () => {
    const pending = deferred<string>(); render(<ImportPanel />); fireEvent.click(screen.getByRole('button', { name:'CSV' })); fireEvent.change(screen.getByLabelText('Chọn file CSV'), { target:{ files:[pendingFile('broken.csv', pending.promise)] } })
    await act(async () => { pending.reject(new Error('disk error')); try { await pending.promise } catch { /* component converts this to a localized error */ } })
    expect(screen.getByRole('status')).toHaveTextContent('Không thể đọc file "broken.csv"'); expect(screen.getByText('Đã chọn: broken.csv')).toBeVisible()
  })
})
