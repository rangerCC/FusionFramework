import { useEffect, useState, useCallback } from 'react'
import { Table, Card, Space, Input, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import { listAuditLogs, type AuditRow } from '../api'

const { Text } = Typography

export default function AuditLogsPage() {
  const [rows, setRows] = useState<AuditRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [actor, setActor] = useState('')
  const [action, setAction] = useState('')
  const [target, setTarget] = useState('')
  const [loading, setLoading] = useState(false)

  const load = useCallback(() => {
    setLoading(true)
    listAuditLogs({ actor, action, target, page, page_size: pageSize })
      .then((d) => { setRows(d.items || []); setTotal(d.total || 0) })
      .catch(() => undefined)
      .finally(() => setLoading(false))
  }, [actor, action, target, page, pageSize])

  useEffect(() => { load() }, [load])

  const columns: ColumnsType<AuditRow> = [
    { title: '操作人', dataIndex: 'actor', width: 140 },
    { title: '动作', dataIndex: 'action', width: 160 },
    { title: '对象', dataIndex: 'target', width: 200, render: (v) => (v ? <Text copyable>{v}</Text> : '-') },
    {
      title: '详情', dataIndex: 'detail',
      render: (v) => <Text code style={{ fontSize: 12 }}>{v ? JSON.stringify(v) : '-'}</Text>,
    },
    { title: '时间', dataIndex: 'created_at', width: 180, render: (v) => new Date(v).toLocaleString() },
  ]

  return (
    <Card>
      <Space style={{ marginBottom: 16 }} wrap>
        <Input placeholder="操作人" allowClear style={{ width: 160 }} onChange={(e) => setActor(e.target.value)} onPressEnter={() => { setPage(1); load() }} />
        <Input placeholder="动作（如 quota.adjust）" allowClear style={{ width: 200 }} onChange={(e) => setAction(e.target.value)} onPressEnter={() => { setPage(1); load() }} />
        <Input.Search placeholder="对象（用户ID）" allowClear style={{ width: 220 }} onSearch={(v) => { setTarget(v); setPage(1) }} />
      </Space>
      <Table
        rowKey={(r) => `${r.actor}-${r.action}-${r.created_at}`}
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
