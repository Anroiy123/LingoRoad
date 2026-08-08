import { useEffect, useState, type FormEvent, type ReactNode } from 'react'
import { BarChart3, CheckCircle2, ShieldCheck } from 'lucide-react'
import { BrowserRouter } from 'react-router-dom'
import logo from './assets/logo.png'
import AdminShell from './features/admin/AdminShell'
import { roleFromSession } from './features/auth/auth'
import { ApiError, login, logout, sessionExpiredEvent, sessionStore, type Session } from './lib/api'
import './App.css'

const Field = ({ label, children }: { label: string; children: ReactNode }) =>
  <label className="field"><span>{label}</span>{children}</label>

function LoginScreen({ onAuthenticated }: { onAuthenticated: (session: Session) => void }): ReactNode {
  const [error, setError] = useState<string>()
  const [busy, setBusy] = useState(false)
  const submit = async (event: FormEvent<HTMLFormElement>): Promise<void> => {
    event.preventDefault(); setBusy(true); setError(undefined)
    const values = new FormData(event.currentTarget)
    try { onAuthenticated(await login(String(values.get('email')), String(values.get('password')))) }
    catch (reason) { setError(reason instanceof ApiError ? reason.code : 'unexpected_error') }
    finally { setBusy(false) }
  }
  return <main className="login-page"><section className="login-shell">
    <div className="login-visual"><div className="login-brand"><img src={logo} alt="LingoRoad" /><span>Admin Portal</span></div><div className="login-intro"><p className="eyebrow">Content operations</p><h2>Điều hành trải nghiệm học tập từ một nơi.</h2><p>Theo dõi chất lượng nội dung, hoạt động người học và vận hành hệ thống bằng dữ liệu thật.</p></div><ul className="login-benefits"><li><BarChart3 aria-hidden="true" /><span><strong>Insight tập trung</strong><small>Analytics và learning quality rõ ràng.</small></span></li><li><ShieldCheck aria-hidden="true" /><span><strong>Truy cập được bảo vệ</strong><small>Role Admin được xác minh trên mọi request.</small></span></li></ul></div>
    <div className="login-form-panel"><div className="login-card"><span className="login-kicker"><CheckCircle2 aria-hidden="true" /> Khu vực quản trị an toàn</span><h1>Chào mừng trở lại</h1><p>Đăng nhập để tiếp tục quản trị LingoRoad.</p>
      <form onSubmit={(event) => void submit(event)}>
        <Field label="Email"><input name="email" type="email" autoComplete="username" placeholder="admin@lingoroad.dev" required /></Field>
        <Field label="Mật khẩu"><input name="password" type="password" autoComplete="current-password" placeholder="Nhập mật khẩu" required /></Field>
        {error && <p className="login-error" role="alert">Đăng nhập thất bại: {error}</p>}
        <button className="primary" disabled={busy} type="submit">{busy ? 'Đang xác thực…' : 'Đăng nhập'}</button>
      </form><small>Thông tin phiên được lưu cục bộ và tự làm mới an toàn.</small></div></div>
  </section></main>
}

function App(): ReactNode {
  const [session, setSession] = useState<Session | null>(() => sessionStore.load())
  const [expired, setExpired] = useState(false)
  useEffect(() => {
    const clear = (): void => { setSession(null); setExpired(true) }
    window.addEventListener(sessionExpiredEvent, clear)
    return () => window.removeEventListener(sessionExpiredEvent, clear)
  }, [])
  const role = roleFromSession(session)
  if (!session) return <>{expired && <div className="session-banner" role="alert">Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.</div>}<LoginScreen onAuthenticated={(next) => { setExpired(false); setSession(next) }} /></>
  if (role !== 'Admin') return <main className="forbidden"><section className="state-card error">
    <h1>Không có quyền truy cập</h1><p>Tài khoản hiện tại không có role Admin.</p>
    <button type="button" onClick={() => { sessionStore.clear(); setSession(null) }}>Quay lại đăng nhập</button>
  </section></main>
  return <BrowserRouter><AdminShell onLogout={async () => { try { await logout() } catch { /* Local session must still close. */ } finally { setSession(null) } }} /></BrowserRouter>
}

export default App
