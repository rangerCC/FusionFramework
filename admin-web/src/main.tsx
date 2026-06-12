import React from 'react'
import ReactDOM from 'react-dom/client'
import { createHashRouter, RouterProvider, Navigate } from 'react-router-dom'
import { ConfigProvider } from 'antd'
import zhCN from 'antd/locale/zh_CN'

import { isLoggedIn } from './auth'
import AppLayout from './components/AppLayout'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import UsersPage from './pages/UsersPage'
import SubscriptionsPage from './pages/SubscriptionsPage'
import FeaturedPage from './pages/FeaturedPage'
import AuditLogsPage from './pages/AuditLogsPage'

// Gate: redirect to /login when no admin token is present.
function RequireAuth({ children }: { children: React.ReactNode }) {
  return isLoggedIn() ? <>{children}</> : <Navigate to="/login" replace />
}

const router = createHashRouter([
  { path: '/login', element: <LoginPage /> },
  {
    path: '/',
    element: (
      <RequireAuth>
        <AppLayout />
      </RequireAuth>
    ),
    children: [
      { index: true, element: <Navigate to="/dashboard" replace /> },
      { path: 'dashboard', element: <DashboardPage /> },
      { path: 'users', element: <UsersPage /> },
      { path: 'subscriptions', element: <SubscriptionsPage /> },
      { path: 'featured', element: <FeaturedPage /> },
      { path: 'audit-logs', element: <AuditLogsPage /> },
    ],
  },
])

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ConfigProvider locale={zhCN}>
      <RouterProvider router={router} />
    </ConfigProvider>
  </React.StrictMode>,
)
