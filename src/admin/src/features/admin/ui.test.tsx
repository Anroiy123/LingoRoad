import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { useState } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { ConfirmDialog, DataTable, Dialog, OverflowText, Pagination, StatePanel } from './ui'

const DialogHarness = () => { const [open, setOpen] = useState(false); return <><button type="button" onClick={() => setOpen(true)}>Mở dialog</button>{open && <Dialog title="Dialog test" onClose={() => setOpen(false)}><button type="button">Nút cuối</button></Dialog>}</> }

describe('Dialog accessibility', () => {
  it('trap Tab, đóng bằng Escape và trả focus cho trigger', async () => {
    render(<DialogHarness />); const opener = screen.getByRole('button', { name:'Mở dialog' }); opener.focus(); fireEvent.click(opener)
    const dialog = screen.getByRole('dialog'); const close = screen.getByRole('button', { name:'Đóng hộp thoại' }); const last = screen.getByRole('button', { name:'Nút cuối' })
    await waitFor(() => expect(close).toHaveFocus()); fireEvent.keyDown(dialog, { key:'Tab', shiftKey:true }); expect(last).toHaveFocus(); fireEvent.keyDown(dialog, { key:'Tab' }); expect(close).toHaveFocus(); fireEvent.keyDown(dialog, { key:'Escape' }); await waitFor(() => expect(opener).toHaveFocus())
  })

  it('ConfirmDialog dùng cùng Escape/focus restore và chỉ confirm khi chọn', async () => {
    const confirm = vi.fn(); const Harness = () => { const [open, setOpen] = useState(false); return <><button onClick={() => setOpen(true)}>Xóa record</button>{open && <ConfirmDialog title="Xác nhận xóa" description="Không thể hoàn tác" danger onCancel={() => setOpen(false)} onConfirm={confirm} />}</> }
    render(<Harness />); const opener = screen.getByRole('button', { name:'Xóa record' }); opener.focus(); fireEvent.click(opener); fireEvent.keyDown(screen.getByRole('dialog'), { key:'Escape' }); await waitFor(() => expect(opener).toHaveFocus()); expect(confirm).not.toHaveBeenCalled()
  })
})

describe('StatePanel layout', () => {
  it('giữ wrapper dùng chung để các section có nhịp dọc nhất quán', () => {
    const { container } = render(<StatePanel query={{ loading:false, reload:vi.fn(async () => undefined) }}><section>Khối một</section><section>Khối hai</section></StatePanel>)
    expect(container.querySelector('.state-panel')).toBeInTheDocument()
    expect(screen.getByText('Khối một')).toBeVisible(); expect(screen.getByText('Khối hai')).toBeVisible()
  })
})

describe('DataTable layout', () => {
  it('đánh dấu bảng có cột thao tác cố định và vùng cuộn truy cập được bằng bàn phím', () => {
    render(<DataTable empty={false} stickyActions layout="items"><thead><tr><th>Tên</th><th>Thao tác</th></tr></thead><tbody><tr><td>Mục mẫu</td><td><button type="button">Sửa</button></td></tr></tbody></DataTable>)
    const region = screen.getByLabelText('Bảng dữ liệu có thể cuộn ngang')
    expect(region).toHaveClass('table-wrap-actions')
    expect(region).toHaveAttribute('tabindex', '0')
    expect(region.querySelector('table')).toHaveClass('table-layout-items')
    expect(screen.getByRole('button', { name:'Sửa' })).toBeVisible()
  })

  it('hiển thị số trang, ellipsis, giới hạn và đổi kích thước trang', () => {
    const changePage = vi.fn(); const changeSize = vi.fn(); render(<Pagination page={4} pageSize={10} total={100} onPageChange={changePage} onPageSizeChange={changeSize} />)
    expect(screen.getByText('Hiển thị 41–50 / 100')).toBeVisible(); expect(screen.getByRole('button', { name:'Trang 5' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getAllByText('…')).toHaveLength(2); fireEvent.click(screen.getByRole('button', { name:'Trang sau' })); expect(changePage).toHaveBeenCalledWith(5)
    fireEvent.click(screen.getByRole('button', { name:'Trang cuối' })); expect(changePage).toHaveBeenCalledWith(9)
    fireEvent.change(screen.getByLabelText('Số dòng mỗi trang'), { target:{ value:'20' } }); expect(changeSize).toHaveBeenCalledWith(20)
  })

  it('vô hiệu hóa đúng nút biên và tạo token trang ổn định', () => {
    const noop = vi.fn(); render(<Pagination page={0} pageSize={10} total={71} onPageChange={noop} onPageSizeChange={noop} />)
    expect(screen.getByRole('button', { name:'Trang đầu' })).toBeDisabled(); expect(screen.getByRole('button', { name:'Trang trước' })).toBeDisabled()
    expect(screen.getByRole('button', { name:'Trang 1' })).toHaveAttribute('aria-current', 'page'); expect(screen.getByText('…')).toBeVisible()
  })

  it('giữ toàn bộ nội dung dài trong tooltip hover', () => {
    const value = 'Nội dung rất dài cần được hiển thị đầy đủ khi rê chuột'
    render(<OverflowText text={value} lines={2} tone="primary" />)
    const text = screen.getByText(value); expect(text).toHaveAttribute('title', value); expect(text).toHaveClass('overflow-text-2', 'overflow-text-primary')
  })
})
