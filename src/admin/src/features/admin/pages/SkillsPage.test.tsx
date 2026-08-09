import { fireEvent, render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { sessionStore } from '../../../lib/api'
import { SkillsPanel } from './SkillsPage'

const rows = Array.from({ length:12 }, (_, index) => ({ id:index + 1, code:`skill.${index + 1}`, name:`Skill ${index + 1}`, nameVi:`Kỹ năng ${index + 1}`, category:index === 11 ? 'reading' : 'grammar', parentId:null, cefrLevel:'A1' }))

describe('Client table pagination', () => {
  beforeEach(() => { vi.restoreAllMocks(); sessionStore.save({ token:'admin-token', refreshToken:'refresh-token' }); vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify(rows), { status:200, headers:{ 'Content-Type':'application/json' } })) })

  it('slice đúng, đổi page size và reset trang khi search/filter', async () => {
    render(<SkillsPanel />); expect(await screen.findByText('Kỹ năng 1')).toBeVisible(); expect(screen.queryByText('Kỹ năng 11')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name:'Trang 2' })); expect(screen.getByText('Kỹ năng 11')).toBeVisible(); expect(screen.queryByText('Kỹ năng 1')).not.toBeInTheDocument()
    fireEvent.change(screen.getByLabelText('Tìm kỹ năng'), { target:{ value:'skill.1' } }); expect(screen.getByText('Kỹ năng 1')).toBeVisible(); expect(screen.getByRole('button', { name:'Trang 1' })).toHaveAttribute('aria-current', 'page')
    fireEvent.change(screen.getByLabelText('Tìm kỹ năng'), { target:{ value:'' } }); fireEvent.change(screen.getByLabelText('Nhóm'), { target:{ value:'reading' } }); expect(screen.getByText('Kỹ năng 12')).toBeVisible(); expect(screen.queryByText('Kỹ năng 1')).not.toBeInTheDocument()
    fireEvent.change(screen.getByLabelText('Nhóm'), { target:{ value:'' } }); fireEvent.change(screen.getByLabelText('Số dòng mỗi trang'), { target:{ value:'20' } }); expect(screen.getByText('Kỹ năng 12')).toBeVisible(); expect(screen.getByText('Hiển thị 1–12 / 12')).toBeVisible()
  })
})
