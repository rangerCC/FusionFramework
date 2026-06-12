import { useEffect, useState, useCallback } from 'react'
import { Table, Card, Space, Select, Input, Tag, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import { listSubscriptions, type SubRow } from '../api'

const { Text } = Typography

const STATUS_COLOR: Record<string, string> = {
  active: 'green', expired: 'default', grace: 'orange', billing_retry: 'gold', revoked: 'red',
}

export default function SubscriptionsPage() {
  const [rows, setRows] = useState<SubRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [status, setStatus] = useState<string>('')
  const [environment, setEnvironment] = useState<string>('')
  const [keyword, setKeyword] = useState('')
  const [loading, setLoading] = useState(false)

  const load = useCallback(() => {
    setLoading(true)
    listSubscriptions({ status, environment, keyword, page, page_size: pageSize })
      .then((d) => { setRows(d.items || []); setTotal(d.total || 0) })
      .catch(() => undefined)
      .finally(() => setLoading(false))
  }, [status, environment, keyword, page, pageSize])

  useEffect(() => { load() }, [load])

  const columns: ColumnsType<SubRow> = [
    { title: '用户ID', dataIndex: 'user_id', width: 180, render: (v) => <Text copyable>{v}</Text> },
    { title: '昵称', dataIndex: 'nickname' },
    { title: '产品', dataIndex: 'product_id' },
    { title: '状态', dataIndex: 'status', width: 110, render: (v: string) => <Tag color={STATUS_COLOR[v] || 'default'}>{v}</Tag> },
    { title: '到期', dataIndex: 'expires_at', width: 180, render: (v) => (v ? new Date(v).toLocaleString() : '-') },
    { title: '自动续费', dataIndex: 'auto_renew', width: 90, render: (v: boolean) => (v ? '是' : '否') },
    { title: '环境', dataIndex: 'environment', width: 110 },
    { title: '更新时间', dataIndex: 'updated_at', width: 180, render: (v) => new Date(v).toLocaleString() },
  ]

  return (
    <Card>
      <Space style={{ marginBottom: 16 }} wrap>
        <Select
          allowClear placeholder="状态" style={{ width: 140 }}
          value={status || undefined}
          onChange={(v) => { setStatus(v || ''); setPage(1) }}
          options={['active', 'expired', 'grace', 'billing_retry', 'revoked'].map((s) => ({ value: s, label: s }))}
        />
        <Select
          allowClear placeholder="环境" style={{ width: 140 }}
          value={environment || undefined}
          onChange={(v) => { setEnvironment(v || ''); setPage(1) }}
          options={[{ value: 'Production', label: 'Production' }, { value: 'Sandbox', label: 'Sandbox' }]}
        />
        <Input.Search
          placeholder="搜索昵称 / 手机号" allowClear style={{ width: 240 }}
          onSearch={(v) => { setKeyword(v); setPage(1) }}
        />
      </Space>
      <Table
        rowKey={(r) => `${r.user_id}-${r.product_id}-${r.updated_at}`}
        loading={loading}
        columns={columns}
        dataSource={rows}
        pagination={{
          current: page, pageSize, total, showSizeChanger: true,
          onChange: (p, ps) => { setPage(p); setPageSize(ps) },
        }}
      />
    </Card>
  )
}
