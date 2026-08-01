import { useState, type FormEvent, type ReactNode } from 'react'
import AdminShell from './features/admin/AdminShell'
import { roleFromSession } from './features/auth/auth'
import { ApiError, login, logout, sessionStore, type Session } from './lib/api'
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
  return <main className="login-page"><section className="login-card">
    <div className="login-mark">LR</div><p className="eyebrow">LingoRoad Content Operations</p>
    <h1>Đăng nhập Admin</h1><p>Quản trị lesson, item, kỹ năng và analytics trong một vùng được bảo vệ.</p>
    <form onSubmit={(event) => void submit(event)}>
      <Field label="Email"><input name="email" type="email" autoComplete="username" required /></Field>
      <Field label="Mật khẩu"><input name="password" type="password" autoComplete="current-password" required /></Field>
      {error && <p className="login-error" role="alert">Đăng nhập thất bại: {error}</p>}
      <button className="primary" disabled={busy} type="submit">{busy ? 'Đang xác thực…' : 'Đăng nhập'}</button>
    </form><small>Quyền Admin được kiểm tra lại trên từng API request.</small>
  </section></main>
}

function App(): ReactNode {
  const [session, setSession] = useState<Session | null>(() => sessionStore.load())
  const role = roleFromSession(session)
  if (!session) return <LoginScreen onAuthenticated={setSession} />
  if (role !== 'Admin') return <main className="forbidden"><section className="state-card error">
    <h1>Không có quyền truy cập</h1><p>Tài khoản hiện tại không có role Admin.</p>
    <button type="button" onClick={() => { sessionStore.clear(); setSession(null) }}>Quay lại đăng nhập</button>
  </section></main>
  return <AdminShell onLogout={async () => { await logout(); setSession(null) }} />
}

export default App
