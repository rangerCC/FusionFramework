import { Layout, Menu, Button, Typography, Tag, Space } from 'antd'
import {
  DashboardOutlined,
  TeamOutlined,
  CreditCardOutlined,
  StarOutlined,
  FileSearchOutlined,
  LogoutOutlined,
} from '@ant-design/icons'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { clearAuth, getName, getRole } from '../auth'

const { Header, Sider, Content } = Layout
const { Text } = Typography

const MENU = [
  { key: '/dashboard', icon: <DashboardOutlined />, label: '数据看板' },
  { key: '/users', icon: <TeamOutlined />, label: '用户管理' },
  { key: '/subscriptions', icon: <CreditCardOutlined />, label: '订阅管理' },
  { key: '/featured', icon: <StarOutlined />, label: '精选故事' },
  { key: '/audit-logs', icon: <FileSearchOutlined />, label: '审计日志' },
]

const ROLE_LABEL: Record<string, string> = {
  super: '超级管理员',
  support: '客服',
  viewer: '只读',
}

export default function AppLayout() {
  const location = useLocation()
  const navigate = useNavigate()
  const role = getRole() || 'viewer'

  const onLogout = () => {
    clearAuth()
    navigate('/login', { replace: true })
  }

  // Highlight the menu item matching the current path prefix.
  const selected = MENU.find((m) => location.pathname.startsWith(m.key))?.key || '/dashboard'

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider theme="dark" breakpoint="lg" collapsedWidth="0">
        <div style={{ color: '#fff', fontWeight: 700, fontSize: 16, padding: '16px 20px' }}>
          社交故事 · 后台
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[selected]}
          items={MENU}
          onClick={({ key }) => navigate(key)}
        />
      </Sider>
      <Layout>
        <Header style={{ background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'flex-end', paddingInline: 24 }}>
          <Space>
            <Text strong>{getName()}</Text>
            <Tag color="blue">{ROLE_LABEL[role] || role}</Tag>
            <Button icon={<LogoutOutlined />} onClick={onLogout}>
              退出
            </Button>
          </Space>
        </Header>
        <Content style={{ margin: 24 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}
