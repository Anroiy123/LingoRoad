import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from 'react'
import { api, ApiError } from '../../lib/api'
import type { Analytics, AuditEvent, Item, Lesson, Skill } from './types'

type Section = 'overview' | 'skills' | 'items' | 'lessons' | 'import' | 'audit'
interface AdminShellProps { onLogout: () => Promise<void> }
interface QueryState<T> { data?: T; error?: string; loading: boolean; reload: () => Promise<void> }

function useQuery<T>(path: string): QueryState<T> {
  const [data, setData] = useState<T>()
  const [error, setError] = useState<string>()
  const [loading, setLoading] = useState(true)
  const reload = useCallback(async () => {
    setLoading(true); setError(undefined)
    try { setData(await api<T>(path)) }
    catch (reason) { setError(reason instanceof ApiError ? reason.code : 'unexpected_error') }
    finally { setLoading(false) }
  }, [path])
  useEffect(() => void reload(), [reload])
  return { data, error, loading, reload }
}

const StatePanel = ({ query, children }: { query: QueryState<unknown>; children: ReactNode }) => <div aria-live="polite">
  {query.loading && <div className="state-card">Đang tải dữ liệu…</div>}
  {query.error && <div className="state-card error">Không thể tải dữ liệu ({query.error}).
    <button type="button" onClick={() => void query.reload()}>Thử lại</button></div>}
  {!query.loading && !query.error && children}
</div>
const Field = ({ label, children }: { label: string; children: ReactNode }) =>
  <label className="field"><span>{label}</span>{children}</label>
const Page = ({ title, description, children }: { title: string; description: string; children: ReactNode }) => <>
  <header className="page-header"><div><p className="eyebrow">LingoRoad / Admin</p><h1>{title}</h1><p>{description}</p></div>
    <span className="environment">Protected · Admin</span></header><div className="page-content">{children}</div></>
const Metric = ({ label, value, hint }: { label: string; value: string | number; hint?: string }) =>
  <article className="metric"><span>{label}</span><strong>{value}</strong>{hint && <small>{hint}</small>}</article>
const Editor = ({ title, message, children }: { title: string; message?: string; children: ReactNode }) =>
  <section className="card editor"><div className="card-heading"><h2>{title}</h2>{message && <p role="status">{message}</p>}</div>{children}</section>
const DataTable = ({ empty, children }: { empty: boolean; children: ReactNode }) =>
  empty ? <div className="state-card">Chưa có dữ liệu.</div> : <div className="table-wrap"><table>{children}</table></div>
const CefrSelect = ({ value }: { value?: string }) => <select name="cefrLevel" defaultValue={value ?? 'A1'}>
  {['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].map((level) => <option key={level}>{level}</option>)}</select>
const FormActions = ({ editing, onCancel }: { editing: boolean; onCancel: () => void }) =>
  <div className="form-actions"><button className="primary" type="submit">{editing ? 'Lưu thay đổi' : 'Tạo mới'}</button>
    {editing && <button type="button" onClick={onCancel}>Hủy</button>}</div>

function OverviewPanel(): ReactNode {
  const query = useQuery<Analytics>('/admin/analytics/overview'); const data = query.data
  return <Page title="Tổng quan" description="Sức khỏe nội dung và hoạt động học tập theo dữ liệu thật.">
    <StatePanel query={query}>{data && <><div className="metric-grid">
      <Metric label="Người học" value={data.learners} /><Metric label="Active 30 ngày" value={data.activeLearners} />
      <Metric label="Bài hoàn thành" value={data.completedLessons} /><Metric label="Độ chính xác" value={`${Math.round(data.correctness * 100)}%`} />
      <Metric label="Thẻ cần ôn" value={data.dueReviews} /><Metric label="Nội dung" value={`${data.content.lessons}/${data.content.items}`} hint="lesson/item" />
    </div><section className="card"><h2>Mastery theo nhóm kỹ năng</h2>
      {data.mastery.length === 0 ? <p className="muted">Chưa có dữ liệu mastery.</p> : data.mastery.map((row) =>
        <div className="progress-row" key={row.category}><span>{row.category}</span><progress value={row.average} max="1" />
          <strong>{Math.round(row.average * 100)}%</strong></div>)}</section></>}</StatePanel></Page>
}

function SkillsPanel(): ReactNode {
  const query = useQuery<Skill[]>('/admin/skills'); const [editing, setEditing] = useState<Skill>(); const [message, setMessage] = useState<string>()
  const submit = async (event: FormEvent<HTMLFormElement>): Promise<void> => {
    event.preventDefault(); setMessage(undefined); const form = event.currentTarget; const values = new FormData(form); const parent = String(values.get('parentId') ?? '')
    const body = { code:String(values.get('code')), name:String(values.get('name')), nameVi:String(values.get('nameVi')),
      category:String(values.get('category')), cefrLevel:String(values.get('cefrLevel')), parentId:parent ? Number(parent) : null }
    try { await api(editing ? `/admin/skills/${editing.id}` : '/admin/skills', { method:editing ? 'PUT' : 'POST', body:JSON.stringify(body) })
      setEditing(undefined); form.reset(); setMessage('Đã lưu kỹ năng.'); await query.reload() }
    catch (reason) { setMessage(`Không thể lưu: ${reason instanceof ApiError ? reason.code : 'unexpected_error'}`) }
  }
  const remove = async (row: Skill): Promise<void> => { if (!window.confirm(`Xóa mềm ${row.code}?`)) return
    try { await api(`/admin/skills/${row.id}`, { method:'DELETE' }); await query.reload() }
    catch (reason) { setMessage(`Không thể xóa: ${reason instanceof ApiError ? reason.code : 'unexpected_error'}`) } }
  return <Page title="Kỹ năng" description="Quản lý taxonomy; skill đang được tham chiếu sẽ không thể xóa.">
    <Editor title={editing ? `Sửa ${editing.code}` : 'Tạo kỹ năng'} message={message}><form className="form-grid" onSubmit={(event) => void submit(event)} key={editing?.id ?? 'new'}>
      <Field label="Code"><input name="code" required defaultValue={editing?.code} /></Field><Field label="Tên"><input name="name" required defaultValue={editing?.name} /></Field>
      <Field label="Tên tiếng Việt"><input name="nameVi" required defaultValue={editing?.nameVi} /></Field><Field label="Nhóm"><input name="category" required defaultValue={editing?.category ?? 'grammar'} /></Field>
      <Field label="CEFR"><CefrSelect value={editing?.cefrLevel} /></Field><Field label="Kỹ năng cha"><select name="parentId" defaultValue={editing?.parentId ?? ''}><option value="">Không có</option>
        {query.data?.filter((row) => row.id !== editing?.id).map((row) => <option value={row.id} key={row.id}>{row.code}</option>)}</select></Field>
      <FormActions editing={Boolean(editing)} onCancel={() => setEditing(undefined)} /></form></Editor>
    <StatePanel query={query}><DataTable empty={!query.data?.length}><thead><tr><th>Code</th><th>Tên</th><th>Nhóm</th><th>CEFR</th><th /></tr></thead><tbody>
      {query.data?.map((row) => <tr key={row.id}><td><code>{row.code}</code></td><td>{row.nameVi}<small>{row.name}</small></td><td>{row.category}</td><td>{row.cefrLevel}</td>
        <td className="actions"><button type="button" onClick={() => setEditing(row)}>Sửa</button><button className="danger" type="button" onClick={() => void remove(row)}>Xóa</button></td></tr>)}</tbody></DataTable></StatePanel></Page>
}

function ItemsPanel(): ReactNode {
  const query = useQuery<Item[]>('/admin/items'); const skills = useQuery<Skill[]>('/admin/skills'); const [editing, setEditing] = useState<Item>(); const [message, setMessage] = useState<string>()
  const submit = async (event: FormEvent<HTMLFormElement>): Promise<void> => { event.preventDefault(); const form = event.currentTarget; const values = new FormData(form)
    const options = String(values.get('options')).split('\n').map((x) => x.trim()).filter(Boolean)
    const body = { stableId:String(values.get('stableId')), skillId:Number(values.get('skillId')), cefrLevel:String(values.get('cefrLevel')), type:String(values.get('type')),
      stem:String(values.get('stem')), options, correctAnswer:String(values.get('correctAnswer')), explanationVi:String(values.get('explanationVi')), source:String(values.get('source')),
      license:'Proprietary', reviewer:'Admin CMS', contentVersion:'admin-v1', a:1, b:0, c:options.length ? 1/options.length : 0 }
    try { await api(editing ? `/admin/items/${editing.id}` : '/admin/items', { method:editing ? 'PUT' : 'POST', body:JSON.stringify(body) })
      setEditing(undefined); form.reset(); setMessage('Đã lưu item.'); await query.reload() }
    catch (reason) { setMessage(`Không thể lưu: ${reason instanceof ApiError ? reason.code : 'unexpected_error'}`) } }
  const remove = async (row: Item): Promise<void> => { if (!window.confirm(`Xóa mềm ${row.stableId ?? row.id}?`)) return
    try { await api(`/admin/items/${row.id}`, { method:'DELETE' }); await query.reload() }
    catch (reason) { setMessage(`Không thể xóa: ${reason instanceof ApiError ? reason.code : 'unexpected_error'}`) } }
  return <Page title="Items" description="Đáp án đúng chỉ xuất hiện trong vùng Admin được bảo vệ.">
    <Editor title={editing ? `Sửa ${editing.stableId}` : 'Tạo item'} message={message}><form className="form-grid" onSubmit={(event) => void submit(event)} key={editing?.id ?? 'new'}>
      <Field label="Stable ID"><input name="stableId" required defaultValue={editing?.stableId ?? ''} /></Field><Field label="Kỹ năng"><select name="skillId" required defaultValue={editing?.skillId ?? ''}><option value="" disabled>Chọn kỹ năng</option>
        {skills.data?.map((row) => <option value={row.id} key={row.id}>{row.code}</option>)}</select></Field><Field label="CEFR"><CefrSelect value={editing?.cefrLevel} /></Field>
      <Field label="Loại"><select name="type" defaultValue={editing?.type ?? 'mcq'}>{['mcq','cloze','reorder','listening_mcq'].map((type) => <option key={type}>{type}</option>)}</select></Field>
      <Field label="Câu hỏi"><textarea name="stem" required defaultValue={editing?.stem} /></Field><Field label="Lựa chọn (mỗi dòng)"><textarea name="options" defaultValue={editing?.options.join('\n')} /></Field>
      <Field label="Đáp án"><input name="correctAnswer" required defaultValue={editing?.correctAnswer} /></Field><Field label="Giải thích"><textarea name="explanationVi" defaultValue={editing?.explanationVi ?? ''} /></Field>
      <Field label="Nguồn"><input name="source" required defaultValue={editing?.source ?? 'Admin CMS'} /></Field><FormActions editing={Boolean(editing)} onCancel={() => setEditing(undefined)} /></form></Editor>
    <StatePanel query={query}><DataTable empty={!query.data?.length}><thead><tr><th>Stable ID</th><th>Câu hỏi</th><th>Skill</th><th>Loại</th><th /></tr></thead><tbody>
      {query.data?.map((row) => <tr key={row.id}><td><code>{row.stableId}</code></td><td className="wide">{row.stem}<small>Đáp án: {row.correctAnswer}</small></td><td>{row.skillCode}</td><td>{row.type}</td>
        <td className="actions"><button type="button" onClick={() => setEditing(row)}>Sửa</button><button className="danger" type="button" onClick={() => void remove(row)}>Xóa</button></td></tr>)}</tbody></DataTable></StatePanel></Page>
}

function LessonsPanel(): ReactNode {
  const query = useQuery<Lesson[]>('/admin/lessons'); const skills = useQuery<Skill[]>('/admin/skills'); const items = useQuery<Item[]>('/admin/items')
  const [editing, setEditing] = useState<Lesson>(); const [message, setMessage] = useState<string>()
  const submit = async (event: FormEvent<HTMLFormElement>): Promise<void> => { event.preventDefault(); const form = event.currentTarget; const values = new FormData(form)
    const body = { stableId:String(values.get('stableId')), slug:String(values.get('slug')), title:String(values.get('title')), titleVi:String(values.get('titleVi')),
      descriptionVi:String(values.get('descriptionVi')), skillId:Number(values.get('skillId')), cefrLevel:String(values.get('cefrLevel')), order:Number(values.get('order')),
      isPublished:values.get('isPublished') === 'on', itemIds:String(values.get('itemIds')).split('\n').map((x) => x.trim()).filter(Boolean),
      source:'Admin CMS', license:'Proprietary', reviewer:'Admin CMS', contentVersion:'admin-v1' }
    try { await api(editing ? `/admin/lessons/${editing.id}` : '/admin/lessons', { method:editing ? 'PUT' : 'POST', body:JSON.stringify(body) })
      setEditing(undefined); form.reset(); setMessage('Đã lưu lesson.'); await query.reload() }
    catch (reason) { setMessage(`Không thể lưu: ${reason instanceof ApiError ? reason.code : 'unexpected_error'}`) } }
  const remove = async (row: Lesson): Promise<void> => { if (!window.confirm(`Xóa mềm ${row.slug}?`)) return
    try { await api(`/admin/lessons/${row.id}`, { method:'DELETE' }); await query.reload() }
    catch (reason) { setMessage(`Không thể xóa: ${reason instanceof ApiError ? reason.code : 'unexpected_error'}`) } }
  return <Page title="Lessons" description="Draft/published, thứ tự và liên kết item được kiểm tra phía server.">
    <Editor title={editing ? `Sửa ${editing.slug}` : 'Tạo lesson'} message={message}><form className="form-grid" onSubmit={(event) => void submit(event)} key={editing?.id ?? 'new'}>
      <Field label="Stable ID"><input name="stableId" required defaultValue={editing?.stableId} /></Field><Field label="Slug"><input name="slug" required defaultValue={editing?.slug} /></Field>
      <Field label="Tiêu đề"><input name="title" required defaultValue={editing?.title} /></Field><Field label="Tiêu đề Việt"><input name="titleVi" required defaultValue={editing?.titleVi} /></Field>
      <Field label="Mô tả"><textarea name="descriptionVi" defaultValue={editing?.descriptionVi ?? ''} /></Field><Field label="Kỹ năng"><select name="skillId" required defaultValue={editing?.skillId ?? ''}><option value="" disabled>Chọn kỹ năng</option>
        {skills.data?.map((row) => <option value={row.id} key={row.id}>{row.code}</option>)}</select></Field><Field label="CEFR"><CefrSelect value={editing?.cefrLevel} /></Field>
      <Field label="Thứ tự"><input name="order" type="number" required defaultValue={editing?.order ?? 1} /></Field><Field label="Item IDs (mỗi dòng)"><textarea name="itemIds" required defaultValue={editing?.itemIds.join('\n')}
        placeholder={items.data?.slice(0,2).map((item) => item.id).join('\n')} /></Field><label className="check"><input name="isPublished" type="checkbox" defaultChecked={editing?.isPublished} /> Published</label>
      <FormActions editing={Boolean(editing)} onCancel={() => setEditing(undefined)} /></form></Editor>
    <StatePanel query={query}><DataTable empty={!query.data?.length}><thead><tr><th>Thứ tự</th><th>Lesson</th><th>Skill</th><th>Trạng thái</th><th /></tr></thead><tbody>
      {query.data?.map((row) => <tr key={row.id}><td>{row.order}</td><td className="wide">{row.titleVi}<small><code>{row.slug}</code> · {row.itemIds.length} items</small></td><td>{row.skillCode}</td>
        <td><span className={`badge ${row.isPublished ? 'live' : ''}`}>{row.isPublished ? 'Published' : 'Draft'}</span></td><td className="actions"><button type="button" onClick={() => setEditing(row)}>Sửa</button>
          <button className="danger" type="button" onClick={() => void remove(row)}>Xóa</button></td></tr>)}</tbody></DataTable></StatePanel></Page>
}

const importTemplate = JSON.stringify({ version:'2026.08.01-admin-v1', source:'LingoRoad Admin CMS', license:'Proprietary', reviewer:'Content reviewer', skills:[], items:[], lessons:[] }, null, 2)
function ImportPanel(): ReactNode {
  const [payload, setPayload] = useState(importTemplate); const [result, setResult] = useState<string>(); const [busy, setBusy] = useState(false)
  const run = async (apply: boolean): Promise<void> => { setBusy(true); setResult(undefined)
    try { const body: unknown = JSON.parse(payload); const response = await api<unknown>(apply ? '/admin/imports' : '/admin/imports/validate', { method:'POST', body:JSON.stringify(body) }); setResult(JSON.stringify(response,null,2)) }
    catch (reason) { setResult(`Lỗi: ${reason instanceof Error ? reason.message : 'invalid_json'}`) } finally { setBusy(false) } }
  return <Page title="Import nội dung" description="Bước 1 chỉ validate/preview; Apply chạy transaction và idempotent theo version/checksum."><section className="card import-card">
    <textarea aria-label="Content bundle JSON" value={payload} onChange={(event) => setPayload(event.target.value)} /><div className="form-actions">
      <button disabled={busy} type="button" onClick={() => void run(false)}>Validate / Preview</button><button disabled={busy} className="primary" type="button" onClick={() => void run(true)}>Apply</button></div>
    {result && <pre>{result}</pre>}</section></Page>
}
function AuditPanel(): ReactNode {
  const query = useQuery<AuditEvent[]>('/admin/audit?limit=100')
  return <Page title="Audit log" description="Mọi mutation nội dung đều lưu actor, action, entity và thời điểm."><StatePanel query={query}><DataTable empty={!query.data?.length}>
    <thead><tr><th>Thời điểm</th><th>Hành động</th><th>Entity</th><th>ID</th></tr></thead><tbody>{query.data?.map((row) => <tr key={row.id}>
      <td>{new Date(row.createdAt).toLocaleString('vi-VN')}</td><td>{row.action}</td><td>{row.entityType}</td><td><code>{row.entityId}</code></td></tr>)}</tbody></DataTable></StatePanel></Page>
}

export function AdminShell({ onLogout }: AdminShellProps): ReactNode {
  const [section, setSection] = useState<Section>('overview')
  const panels: Record<Section, ReactNode> = { overview:<OverviewPanel />, skills:<SkillsPanel />, items:<ItemsPanel />, lessons:<LessonsPanel />, import:<ImportPanel />, audit:<AuditPanel /> }
  const labels: Record<Section,string> = { overview:'Tổng quan', skills:'Kỹ năng', items:'Items', lessons:'Lessons', import:'Import', audit:'Audit log' }
  return <div className="admin-layout"><aside><div className="brand"><span>LR</span><div><strong>LingoRoad</strong><small>Content Admin</small></div></div>
    <nav>{(Object.keys(labels) as Section[]).map((key) => <button type="button" key={key} className={section === key ? 'active' : ''} onClick={() => setSection(key)}>{labels[key]}</button>)}</nav>
    <button className="logout" type="button" onClick={() => void onLogout()}>Đăng xuất</button></aside><main>{panels[section]}</main></div>
}
export default AdminShell
