import { useState } from 'react'
import { Card, Form, Input, Button, Typography, message } from 'antd'
import { useNavigate } from 'react-router-dom'
import { login } from '../api'
import { setAuth } from '../auth'

const { Title } = Typography

export default function LoginPage() {
  const navigate = useNavigate()
  const [loading, setLoading] = useState(false)

  const onFinish = async (v: { username: string; password: string }) => {
    setLoading(true)
    try {
      const res = await login(v.username, v.password)
      setAuth(res.access_token, res.role, v.username)
      message.success('登录成功')
      navigate('/dashboard', { replace: true })
    } catch {
      // http interceptor already surfaced the error message.
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#f0f2f5' }}>
      <Card style={{ width: 360 }}>
        <Title level={3} style={{ textAlign: 'center', marginBottom: 24 }}>
          社交故事 · 管理后台
        </Title>
        <Form layout="vertical" onFinish={onFinish} requiredMark={false}>
          <Form.Item name="username" label="用户名" rules={[{ required: true, message: '请输入用户名' }]}>
            <Input autoFocus placeholder="admin" />
          </Form.Item>
          <Form.Item name="password" label="密码" rules={[{ required: true, message: '请输入密码' }]}>
            <Input.Password placeholder="密码" onPressEnter={() => undefined} />
          </Form.Item>
          <Form.Item style={{ marginBottom: 0 }}>
            <Button type="primary" htmlType="submit" block loading={loading}>
              登录
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  )
}
