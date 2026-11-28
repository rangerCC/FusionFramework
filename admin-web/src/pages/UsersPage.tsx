import { useEffect, useState, useCallback } from 'react'
import {
  Table, Input, Button, Tag, Space, Drawer, Descriptions,
  message, Card, Typography, Popconfirm,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import {
  listUsers, getUserDetail, setUserStatus,
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

  const [detailOpen, setDetailOpen] = useState(false)
  const [detail, setDetail] = useState<UserDetail | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)

  const canBan = hasRole('super')

  const load = useCallback(() => {
    setLoading(true)
    listUsers({ keyword, page, page_size: pageSize })
      .then((d) => { setRows(d.items || []); setTotal(d.total || 0) })
      .catch(() => undefined)
      .finally(() => setLoading(false))
  }, [keyword, page, pageSize])

  useEffect(() => { load() }, [load])

  const openDetail = (u: UserRow) => {
    setDetailOpen(true)
    setDetail(null)
    setDetailLoading(true)
    getUserDetail(u.user_id)
      .then(setDetail)
      .catch(() => undefined)
      .finally(() => setDetailLoading(false))
  }

  const toggleBan = async (u: UserRow) => {
    const next = u.status === 1 ? 0 : 1
    await setUserStatus(u.user_id, next, next === 0 ? '后台封禁' : '后台解封')
    message.success(next === 0 ? '已封禁' : '已解封')
    load()
  }

  const columns: ColumnsType<UserRow> = [
    { title: '用户ID', dataIndex: 'user_id', width: 200, render: (v) => <Text copyable>{v}</Text> },
    { title: '设备ID', dataIndex: 'device_id', ellipsis: true, render: (v) => <Text copyable>{v}</Text> },
    { title: '状态', dataIndex: 'status', render: statusTag, width: 90 },
    { title: '买断', dataIndex: 'is_subscribed', width: 80, render: (v: boolean) => (v ? <Tag color="gold">已买断</Tag> : '-') },
    { title: '注册时间', dataIndex: 'created_at', width: 180, render: (v) => new Date(v).toLocaleString() },
    {
      title: '操作', width: 160,
      render: (_, u) => (
        <Space>
          <Button size="small" onClick={() => openDetail(u)}>详情</Button>
          {canBan && (
            <Popconfirm
              title={u.status === 1 ? '确定封禁该设备？' : '确定解封该设备？'}
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
          placeholder="搜索设备ID / 用户ID"
          allowClear style={{ width: 300 }}
          onSearch={(v) => { setKeyword(v); setPage(1) }}
        />
      </Space>
      <Table
        rowKey="user_id"
        loading={loading}
        columns={columns}
        dataSource={rows}
        pagination={{
          current: page, pageSize, total, showSizeChanger: true,
          onChange: (p, ps) => { setPage(p); setPageSize(ps) },
        }}
      />

      <Drawer title="设备详情" width={480} open={detailOpen} onClose={() => setDetailOpen(false)} loading={detailLoading}>
        {detail && (
          <Space direction="vertical" style={{ width: '100%' }} size="large">
            <Descriptions title="设备信息" column={1} bordered size="small">
              <Descriptions.Item label="用户ID">{String(detail.profile.user_id ?? '')}</Descriptions.Item>
              <Descriptions.Item label="设备ID">{String(detail.profile.device_id ?? '')}</Descriptions.Item>
              <Descriptions.Item label="状态">{statusTag(Number(detail.profile.status ?? -1))}</Descriptions.Item>
              <Descriptions.Item label="注册时间">{new Date(String(detail.profile.created_at ?? '')).toLocaleString()}</Descriptions.Item>
            </Descriptions>
            <Descriptions title="买断状态" column={1} bordered size="small">
              {detail.subscription ? (
                <>
                  <Descriptions.Item label="产品">{String(detail.subscription.product_id ?? '')}</Descriptions.Item>
                  <Descriptions.Item label="状态">{String(detail.subscription.status ?? '')}</Descriptions.Item>
                  <Descriptions.Item label="到期">{detail.subscription.expires_at ? String(detail.subscription.expires_at) : '永久有效'}</Descriptions.Item>
                </>
              ) : (
                <Descriptions.Item label="-">未买断</Descriptions.Item>
              )}
            </Descriptions>
          </Space>
        )}
      </Drawer>

    </Card>
  )
}
