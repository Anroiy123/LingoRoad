import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from 'react'
import { Activity, BarChart3, BookOpen, Boxes, ClipboardList, FileUp, LayoutDashboard, LogOut, Menu, ShieldCheck, Users, X } from 'lucide-react'
import { Navigate, NavLink, Route, Routes, useLocation } from 'react-router-dom'
import logo from '../../assets/logo_black.png'
import { AnalyticsPanel } from './pages/AnalyticsPage'
import { ItemsPanel } from './pages/ItemsPage'
import { LessonsPanel } from './pages/LessonsPage'
import { AuditPanel, ImportPanel } from './pages/OperationsPages'
import { OverviewPanel } from './pages/OverviewPage'
import { SkillsPanel } from './pages/SkillsPage'
import { UserDetailPanel, UsersPanel } from './pages/UsersPage'

interface AdminShellProps { onLogout: () => Promise<void> }

const primaryNavigation = [
  { to:'/overview', label:'Tổng quan', icon:LayoutDashboard }, { to:'/users', label:'Người dùng', icon:Users },
  { to:'/lessons', label:'Bài học', icon:BookOpen }, { to:'/analytics', label:'Phân tích', icon:BarChart3 },
]
const contentNavigation = [
  { to:'/skills', label:'Kỹ năng', icon:Boxes }, { to:'/items', label:'Items', icon:ClipboardList },
  { to:'/imports', label:'Import', icon:FileUp }, { to:'/audit', label:'Audit log', icon:Activity },
]
const navigation = [...primaryNavigation, ...contentNavigation]

export function AdminShell({ onLogout }: AdminShellProps): ReactNode {
  const [drawerOpen, setDrawerOpen] = useState(false); const [mobile, setMobile] = useState(() => window.matchMedia?.('(max-width: 780px)').matches ?? false); const location = useLocation(); const drawer = useRef<HTMLElement>(null); const opener = useRef<HTMLButtonElement>(null); const main = useRef<HTMLElement>(null); const previousPath = useRef(location.pathname)
  useEffect(() => { if (!window.matchMedia) return; const media = window.matchMedia('(max-width: 780px)'); const update = (): void => setMobile(media.matches); update(); media.addEventListener('change', update); return () => media.removeEventListener('change', update) }, [])
  useEffect(() => { const changed = previousPath.current !== location.pathname; previousPath.current = location.pathname; if (!changed || !mobile || !drawerOpen) return; setDrawerOpen(false); window.requestAnimationFrame(() => main.current?.querySelector<HTMLElement>('h1')?.focus()) }, [drawerOpen, location.pathname, mobile])
  useEffect(() => { if (mobile && drawerOpen) drawer.current?.querySelector<HTMLElement>('a,button')?.focus() }, [drawerOpen, mobile])
  useEffect(() => { if (!mobile || !drawerOpen) return; const previous = document.body.style.overflow; document.body.style.overflow = 'hidden'; return () => { document.body.style.overflow = previous } }, [drawerOpen, mobile])
  const closeDrawer = (): void => { setDrawerOpen(false); window.requestAnimationFrame(() => opener.current?.focus()) }
  const trapDrawer = (event: KeyboardEvent<HTMLElement>): void => { if (!mobile || !drawerOpen) return; if (event.key === 'Escape') { event.preventDefault(); closeDrawer(); return } if (event.key !== 'Tab') return; const nodes = [...(drawer.current?.querySelectorAll<HTMLElement>('a[href],button:not(:disabled)') ?? [])]; const first = nodes[0]; const last = nodes[nodes.length - 1]; if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus() } else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() } }
  const activeLabel = navigation.find(({ to }) => location.pathname === to || (to === '/users' && location.pathname.startsWith('/users/')))?.label ?? 'Tổng quan'
  const renderLinks = (items: typeof navigation): ReactNode => items.map(({ to, label, icon:Icon }) => <NavLink key={to} to={to} className={({ isActive }) => isActive || (to === '/users' && location.pathname.startsWith('/users/')) ? 'active' : ''}><Icon size={20} aria-hidden="true" /><span>{label}</span></NavLink>)
  return <div className="admin-layout">
    {mobile && drawerOpen && <button className="drawer-scrim" aria-label="Đóng menu" onClick={closeDrawer} />}
    <aside id="admin-navigation" ref={drawer} className={drawerOpen ? 'open' : ''} aria-hidden={mobile && !drawerOpen ? true : undefined} inert={mobile && !drawerOpen ? true : undefined} onKeyDown={trapDrawer}>
      <div className="brand"><div className="brand-identity"><span className="brand-logo"><img src={logo} alt="LingoRoad" /></span><span className="brand-context">Admin Portal</span></div><button className="drawer-close icon-button" type="button" aria-label="Đóng menu" onClick={closeDrawer}><X /></button></div>
      <nav aria-label="Điều hướng chính"><p className="nav-label">Quản trị</p>{renderLinks(primaryNavigation)}<p className="nav-label">Nội dung & vận hành</p>{renderLinks(contentNavigation)}</nav>
      <div className="sidebar-footer"><div className="sidebar-security"><ShieldCheck aria-hidden="true" /><div><strong>Vùng bảo vệ</strong><small>Role Admin</small></div></div><button className="logout" type="button" onClick={() => void onLogout()}><LogOut size={19} aria-hidden="true" />Đăng xuất</button></div>
    </aside>
    <div className="admin-workspace"><header className="topbar"><div className="topbar-title"><button ref={opener} className="mobile-menu icon-button" type="button" aria-label="Mở menu" aria-expanded={drawerOpen} aria-controls="admin-navigation" onClick={() => setDrawerOpen(true)}><Menu /></button><div><span>Không gian quản trị</span><strong>{activeLabel}</strong></div></div><div className="admin-profile"><span className="admin-avatar">AD</span><div><strong>Quản trị viên</strong><small>Admin</small></div></div></header>
      <main ref={main}><Routes><Route path="/" element={<Navigate to="/overview" replace />} /><Route path="/overview" element={<OverviewPanel />} /><Route path="/users" element={<UsersPanel />} /><Route path="/users/:id" element={<UserDetailPanel />} /><Route path="/skills" element={<SkillsPanel />} /><Route path="/items" element={<ItemsPanel />} /><Route path="/lessons" element={<LessonsPanel />} /><Route path="/analytics" element={<AnalyticsPanel />} /><Route path="/imports" element={<ImportPanel />} /><Route path="/audit" element={<AuditPanel />} /><Route path="*" element={<Navigate to="/overview" replace />} /></Routes></main>
    </div>
  </div>
}
export default AdminShell
