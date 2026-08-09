import { useEffect, useId, useRef, type KeyboardEvent, type ReactNode } from 'react'
import { AlertTriangle, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, Inbox, LoaderCircle, X, type LucideIcon } from 'lucide-react'
import type { QueryState } from './query'

export const StatePanel = ({ query, children }: { query: QueryState<unknown>; children: ReactNode }): ReactNode => <div className="state-panel" aria-live="polite">{query.loading && <div className="state-card state-loading"><LoaderCircle aria-hidden="true" /> <div><strong>Đang tải dữ liệu</strong><span>Vui lòng chờ trong giây lát…</span></div></div>}{query.error && <div className="state-card error"><AlertTriangle aria-hidden="true" /><div><strong>Không thể tải dữ liệu</strong><span>Mã lỗi: {query.error.code}</span></div><button type="button" onClick={() => void query.reload()}>Thử lại</button></div>}{!query.loading && !query.error && children}</div>
export const Field = ({ label, children }: { label: string; children: ReactNode }): ReactNode => <label className="field"><span>{label}</span>{children}</label>
export const Page = ({ title, description, actions, children }: { title: string; description: string; actions?: ReactNode; children: ReactNode }): ReactNode => <div className="admin-page"><header className="page-header"><div><p className="eyebrow">LingoRoad Admin</p><h1 tabIndex={-1}>{title}</h1><p>{description}</p></div>{actions && <div className="page-header-actions">{actions}</div>}</header><div className="page-content">{children}</div></div>
export const Metric = ({ label, value, hint, icon: Icon, tone = 'primary' }: { label: string; value: string | number; hint?: string; icon?: LucideIcon; tone?: 'primary' | 'neutral' | 'success' | 'warning' }): ReactNode => <article className={`metric metric-${tone}`}><div className="metric-top"><span>{label}</span>{Icon && <span className="metric-icon"><Icon aria-hidden="true" /></span>}</div><strong>{value}</strong>{hint && <small>{hint}</small>}</article>
export const Editor = ({ title, message, children }: { title: string; message?: string; children: ReactNode }): ReactNode => <section className="card editor"><div className="card-heading"><h2>{title}</h2>{message && <p role="status">{message}</p>}</div>{children}</section>
export const DataTable = ({ empty, children, stickyActions = false, layout }: { empty: boolean; children: ReactNode; stickyActions?: boolean; layout?: 'users' | 'skills' | 'items' | 'lessons' | 'audit' }): ReactNode => empty ? <div className="state-card empty-state"><Inbox aria-hidden="true" /><div><strong>Chưa có dữ liệu</strong><span>Hãy thay đổi bộ lọc hoặc tạo nội dung mới.</span></div></div> : <div className={`table-wrap${stickyActions ? ' table-wrap-actions' : ''}`} tabIndex={0} aria-label="Bảng dữ liệu có thể cuộn ngang"><table className={`data-table${layout ? ` table-layout-${layout}` : ''}`}>{children}</table></div>
export const OverflowText = ({ text, lines = 1, tone = 'default' }: { text: string; lines?: 1 | 2; tone?: 'default' | 'primary' | 'secondary' | 'code' }): ReactNode => <span className={`overflow-text overflow-text-${lines} overflow-text-${tone}`} title={text}>{text}</span>
type PageToken = number | 'ellipsis-start' | 'ellipsis-end'
const paginationTokens = (page: number, pageCount: number): PageToken[] => {
  if (pageCount <= 7) return Array.from({ length:pageCount }, (_, index) => index)
  if (page <= 3) return [0, 1, 2, 3, 4, 'ellipsis-end', pageCount - 1]
  if (page >= pageCount - 4) return [0, 'ellipsis-start', pageCount - 5, pageCount - 4, pageCount - 3, pageCount - 2, pageCount - 1]
  return [0, 'ellipsis-start', page - 1, page, page + 1, 'ellipsis-end', pageCount - 1]
}
export const Pagination = ({ page, pageSize, total, onPageChange, onPageSizeChange, pageSizeOptions = [10,20,50] }: { page: number; pageSize: number; total: number; onPageChange: (page: number) => void; onPageSizeChange: (pageSize: number) => void; pageSizeOptions?: number[] }): ReactNode => {
  if (!total) return null
  const pageCount = Math.max(1, Math.ceil(total / pageSize)); const current = Math.min(Math.max(page, 0), pageCount - 1); const start = current * pageSize + 1; const end = Math.min((current + 1) * pageSize, total)
  return <nav className="pagination" aria-label="Phân trang bảng">
    <div className="pagination-size"><label htmlFor="pagination-page-size">Mỗi trang:</label><select id="pagination-page-size" aria-label="Số dòng mỗi trang" value={pageSize} onChange={(event) => onPageSizeChange(Number(event.target.value))}>{pageSizeOptions.map((size) => <option key={size} value={size}>{size}</option>)}</select></div>
    <span className="pagination-summary">Hiển thị {start}–{end} / {total}</span>
    <div className="pagination-controls">
      <button className="pagination-icon" type="button" aria-label="Trang đầu" title="Trang đầu" disabled={current === 0} onClick={() => onPageChange(0)}><ChevronsLeft aria-hidden="true" /></button>
      <button className="pagination-icon" type="button" aria-label="Trang trước" title="Trang trước" disabled={current === 0} onClick={() => onPageChange(current - 1)}><ChevronLeft aria-hidden="true" /></button>
      <div className="pagination-pages">{paginationTokens(current, pageCount).map((token) => typeof token === 'number' ? <button className={token === current ? 'active' : ''} type="button" key={token} aria-label={`Trang ${token + 1}`} aria-current={token === current ? 'page' : undefined} onClick={() => onPageChange(token)}>{token + 1}</button> : <span aria-hidden="true" key={token}>…</span>)}</div>
      <button className="pagination-icon" type="button" aria-label="Trang sau" title="Trang sau" disabled={current + 1 >= pageCount} onClick={() => onPageChange(current + 1)}><ChevronRight aria-hidden="true" /></button>
      <button className="pagination-icon" type="button" aria-label="Trang cuối" title="Trang cuối" disabled={current + 1 >= pageCount} onClick={() => onPageChange(pageCount - 1)}><ChevronsRight aria-hidden="true" /></button>
    </div>
  </nav>
}
export const CefrSelect = ({ value }: { value?: string }): ReactNode => <select name="cefrLevel" defaultValue={value ?? 'A1'}>{['A1','A2','B1','B2','C1','C2'].map((level) => <option key={level}>{level}</option>)}</select>
export const FormActions = ({ editing, onCancel }: { editing: boolean; onCancel: () => void }): ReactNode => <div className="form-actions dialog-actions"><button className="primary" type="submit">{editing ? 'Lưu thay đổi' : 'Tạo mới'}</button>{editing && <button type="button" onClick={onCancel}>Hủy</button>}</div>
export function Dialog({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }): ReactNode {
  const panel = useRef<HTMLDivElement>(null); const restore = useRef(document.activeElement as HTMLElement | null); const titleId = useId()
  useEffect(() => { const restoreTarget = restore.current; panel.current?.querySelector<HTMLElement>('input,select,button,textarea')?.focus(); return () => restoreTarget?.focus() }, [])
  const trap = (event: KeyboardEvent<HTMLDivElement>): void => { if (event.key === 'Escape') { event.preventDefault(); onClose(); return } if (event.key !== 'Tab') return; const nodes = [...(panel.current?.querySelectorAll<HTMLElement>('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),a[href]') ?? [])]; if (!nodes.length) return; const first = nodes[0]; const last = nodes[nodes.length - 1]; if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() } if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() } }
  return <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}><div className="dialog" role="dialog" aria-modal="true" aria-labelledby={titleId} ref={panel} onKeyDown={trap}><header><h2 id={titleId}>{title}</h2><button className="icon-button" type="button" aria-label="Đóng hộp thoại" onClick={onClose}><X /></button></header>{children}</div></div>
}

export function ConfirmDialog({ title, description, confirmLabel = 'Xác nhận', busy = false, danger = false, onCancel, onConfirm }: { title: string; description: ReactNode; confirmLabel?: string; busy?: boolean; danger?: boolean; onCancel: () => void; onConfirm: () => void }): ReactNode {
  return <Dialog title={title} onClose={() => { if (!busy) onCancel() }}><div className="confirm-copy">{description}</div><div className="form-actions dialog-actions"><button type="button" disabled={busy} onClick={onCancel}>Hủy</button><button autoFocus className={danger ? 'danger' : 'primary'} type="button" disabled={busy} onClick={onConfirm}>{busy ? 'Đang xử lý…' : confirmLabel}</button></div></Dialog>
}
