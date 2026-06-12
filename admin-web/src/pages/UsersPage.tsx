import { useEffect, useState, useCallback } from 'react'
import {
  Table, Input, Button, Tag, Space, Drawer, Descriptions, Modal, InputNumber,
  Form, message, Card, Typography, Popconfirm,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import {
  listUsers, getUserDetail, adjustQuota, setUserStatus,
  type UserRow, type UserDetail,
} from '../api'
import { hasRole } from '../auth'

const { Text } = Typography

function statusTag(status: number) {
  if (status === 1) return <Tag color="green">正常</Tag>
  if (status === 0) return <Tag color="red">已封禁</Tag>
  return <Tag>已注销</Tag>
}

export default function UsersPage() {
  const [rows, setRows] = useState<UserRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [keyword, setKeyword] = useState('')
  const [loading, setLoading] = useState(false)

  // Detail drawer
  const [detailOpen, setDetailOpen] = useState(false)
  const [detail, setDetail] = useState<UserDetail | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)

  // Quota modal
  const [quotaUser, setQuotaUser] = useState<UserRow | null>(null)
  const [quotaForm] = Form.useForm()

  const canQuota = hasRole('super', 'support')
  const canBan = hasRole('super')

  const load = useCallback(() => {
    setLoading(true)
    listUsers({ keyword, page, page_size: pageSize })
      .then((d) => {
        setRows(d.items || [])
        setTotal(d.total || 0)
      })
      .catch(() => undefined)
      .finally(() => setLoading(false))
  }, [keyword, page, pageSize])

  useEffect(() => {
    load()
  }, [load])

  const openDetail = (u: UserRow) => {
    setDetailOpen(true)
    setDetail(null)
    setDetailLoading(true)
    getUserDetail(u.user_id)
      .then(setDetail)
      .catch(() => undefined)
      .finally(() => setDetailLoading(false))
  }

  const submitQuota = async () => {
    const v = await quotaForm.validateFields()
    if (!quotaUser) return
    await adjustQuota(quotaUser.user_id, v.delta, v.reason)
    message.success('额度已调整')
    setQuotaUser(null)
    quotaForm.resetFields()
    load()
  }

  const toggleBan = async (u: UserRow) => {
    const next = u.status === 1 ? 0 : 1
    await setUserStatus(u.user_id, next, next === 0 ? '后台封禁' : '后台解封')
    message.success(next === 0 ? '已封禁' : '已解封')
    load()
  }

  const columns: ColumnsType<UserRow> = [
    { title: '用户ID', dataIndex: 'user_id', width: 180, render: (v) => <Text copyable>{v}</Text> },
    { title: '昵称', dataIndex: 'nickname' },
    { title: '手机号', dataIndex: 'phone_masked', render: (v) => v || '-' },
    { title: '状态', dataIndex: 'status', render: statusTag, width: 90 },
    { title: '会员', dataIndex: 'is_subscribed', width: 80, render: (v: boolean) => (v ? <Tag color="gold">会员</Tag> : '-') },
    { title: '孩子数', dataIndex: 'children_count', width: 80 },
    { title: '注册时间', dataIndex: 'created_at', width: 180, render: (v) => new Date(v).toLocaleString() },
    {
      title: '操作',
      width: 220,
      render: (_, u) => (
        <Space>
          <Button size="small" onClick={() => openDetail(u)}>详情</Button>
          {canQuota && (
            <Button size="small" onClick={() => { setQuotaUser(u); quotaForm.resetFields() }}>调额度</Button>
          )}
          {canBan && (
            <Popconfirm
              title={u.status === 1 ? '确定封禁该用户？' : '确定解封该用户？'}
              onConfirm={() => toggleBan(u)}
            >
              <Button size="small" danger={u.status === 1}>
                {u.status === 1 ? '封禁' : '解封'}
              </Button>
            </Popconfirm>
          )}
        </Space>
      ),
    },
  ]

  return (
    <Card>
      <Space style={{ marginBottom: 16 }}>
        <Input.Search
          placeholder="搜索昵称 / 手机号"
          allowClear
          style={{ width: 260 }}
          onSearch={(v) => { setKeyword(v); setPage(1) }}
        />
      </Space>
      <Table
        rowKey="user_id"
        loading={loading}
        columns={columns}
        dataSource={rows}
        pagination={{
          current: page,
          pageSize,
          total,
          showSizeChanger: true,
          onChange: (p, ps) => { setPage(p); setPageSize(ps) },
        }}
      />

      <Drawer title="用户详情" width={520} open={detailOpen} onClose={() => setDetailOpen(false)} loading={detailLoading}>
        {detail && (
          <Space direction="vertical" style={{ width: '100%' }} size="large">
            <Descriptions title="资料" column={1} bordered size="small">
              <Descriptions.Item label="用户ID">{String(detail.profile.user_id ?? '')}</Descriptions.Item>
              <Descriptions.Item label="昵称">{String(detail.profile.nickname ?? '')}</Descriptions.Item>
              <Descriptions.Item label="状态">{statusTag(Number(detail.profile.status ?? -1))}</Descriptions.Item>
            </Descriptions>
            <Descriptions title="登录绑定" column={1} bordered size="small">
              {detail.bindings.length === 0 && <Descriptions.Item label="-">无</Descriptions.Item>}
              {detail.bindings.map((b) => (
                <Descriptions.Item key={b.provider} label={b.provider}>{b.identifier}</Descriptions.Item>
              ))}
            </Descriptions>
            <Descriptions title="订阅" column={1} bordered size="small">
              {detail.subscription ? (
                <>
                  <Descriptions.Item label="产品">{String(detail.subscription.product_id ?? '')}</Descriptions.Item>
                  <Descriptions.Item label="状态">{String(detail.subscription.status ?? '')}</Descriptions.Item>
                  <Descriptions.Item label="到期">{String(detail.subscription.expires_at ?? '-')}</Descriptions.Item>
                </>
              ) : (
                <Descriptions.Item label="-">无订阅</Descriptions.Item>
              )}
            </Descriptions>
            <Descriptions title="本月额度" column={1} bordered size="small">
              <Descriptions.Item label="周期">{detail.usage.period}</Descriptions.Item>
              <Descriptions.Item label="已用 / 配额">
                {detail.usage.used} / {detail.usage.quota ?? '默认'}
              </Descriptions.Item>
            </Descriptions>
            <div>
              <Text strong>孩子（{detail.children.length}）</Text>
              <Table
                rowKey={(r) => String((r as Record<string, unknown>).child_id)}
                size="small"
                style={{ marginTop: 8 }}
                pagination={false}
                dataSource={detail.children}
                columns={[
                  { title: '姓名', dataIndex: 'name' },
                  { title: '性别', dataIndex: 'gender' },
                  { title: '生日', dataIndex: 'birthday' },
                  { title: '默认', dataIndex: 'is_default', render: (v: boolean) => (v ? '✓' : '') },
                ]}
              />
            </div>
          </Space>
        )}
      </Drawer>

      <Modal
        title={`调整额度 · ${quotaUser?.nickname ?? ''}`}
        open={!!quotaUser}
        onCancel={() => setQuotaUser(null)}
        onOk={submitQuota}
        okText="提交"
      >
        <Form form={quotaForm} layout="vertical">
          <Form.Item name="delta" label="增减次数（正数=多给，负数=扣减）" rules={[{ required: true, message: '请输入数值' }]}>
            <InputNumber style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item name="reason" label="原因" rules={[{ required: true, message: '请填写原因' }]}>
            <Input placeholder="如：客诉补偿" />
          </Form.Item>
        </Form>
      </Modal>
    </Card>
  )
}
