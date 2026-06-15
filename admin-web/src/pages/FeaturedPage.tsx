import { useEffect, useState, useCallback } from 'react'
import {
  Table, Card, Button, Modal, Input, InputNumber, Form, message, Image, Popconfirm, Typography,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import { listFeatured, createFeatured, deleteFeatured, type FeaturedRow } from '../api'
import { hasRole } from '../auth'

const { TextArea } = Input
const { Text } = Typography

export default function FeaturedPage() {
  const [rows, setRows] = useState<FeaturedRow[]>([])
  const [loading, setLoading] = useState(false)
  const [addOpen, setAddOpen] = useState(false)
  const [detail, setDetail] = useState<FeaturedRow | null>(null)
  const [form] = Form.useForm()
  const canManage = hasRole('super', 'support')

  const load = useCallback(() => {
    setLoading(true)
    listFeatured()
      .then((d) => setRows(d.items || []))
      .catch(() => undefined)
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { load() }, [load])

  const submitAdd = async () => {
    const v = await form.validateFields()
    let raw: unknown
    try {
      raw = JSON.parse(v.raw)
    } catch {
      message.error('故事 JSON 格式不正确')
      return
    }
    await createFeatured(raw, v.sort ?? 0)
    message.success('已新增精选故事')
    setAddOpen(false)
    form.resetFields()
    load()
  }

  const remove = async (r: FeaturedRow) => {
    await deleteFeatured(r.story_id)
    message.success('已删除')
    load()
  }

  const detailText = detail
    ? (() => {
        try {
          return JSON.stringify(detail.raw, null, 2)
        } catch {
          return String(detail.raw)
        }
      })()
    : ''

  const columns: ColumnsType<FeaturedRow> = [
    {
      title: '封面', dataIndex: 'image_url', width: 90,
      render: (v: string) => (v ? <Image src={v} width={56} height={42} style={{ objectFit: 'cover' }} /> : '-'),
    },
    { title: '标题', dataIndex: 'title' },
    { title: '字数', dataIndex: 'word_count', width: 90 },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '故事ID', dataIndex: 'story_id', width: 200, render: (v) => <Text copyable>{v}</Text> },
    { title: '创建时间', dataIndex: 'created_at', width: 180, render: (v) => new Date(v).toLocaleString() },
    {
      title: '详情', width: 80,
      render: (_: unknown, r: FeaturedRow) => (
        <Button size="small" type="link" onClick={() => setDetail(r)}>详情</Button>
      ),
    },
    ...(canManage
      ? [{
          title: '操作', width: 100,
          render: (_: unknown, r: FeaturedRow) => (
            <Popconfirm title="确定删除该精选故事？" onConfirm={() => remove(r)}>
              <Button size="small" danger>删除</Button>
            </Popconfirm>
          ),
        } as ColumnsType<FeaturedRow>[number]]
      : []),
  ]

  return (
    <Card
      title="精选故事"
      extra={canManage && <Button type="primary" onClick={() => { form.resetFields(); setAddOpen(true) }}>新增</Button>}
    >
      <Table rowKey="story_id" loading={loading} columns={columns} dataSource={rows} pagination={false} />

      <Modal title="新增精选故事" open={addOpen} onCancel={() => setAddOpen(false)} onOk={submitAdd} okText="提交" width={680}>
        <Form form={form} layout="vertical">
          <Form.Item name="sort" label="排序（升序，越小越靠前）" initialValue={0}>
            <InputNumber style={{ width: '100%' }} />
          </Form.Item>
          <Form.Item
            name="raw"
            label="故事 JSON（粘贴完整的 coze 故事数据）"
            rules={[{ required: true, message: '请粘贴故事 JSON' }]}
          >
            <TextArea rows={14} placeholder='{ "story_title": "...", "pages": [ ... ], ... }' />
          </Form.Item>
        </Form>
      </Modal>

      <Modal
        title="故事详情"
        open={!!detail}
        onCancel={() => setDetail(null)}
        width={760}
        footer={[
          <Button
            key="copy"
            type="primary"
            onClick={() => {
              navigator.clipboard.writeText(detailText)
                .then(() => message.success('已复制故事原始数据'))
                .catch(() => message.error('复制失败，请手动选择复制'))
            }}
          >
            一键复制
          </Button>,
          <Button key="close" onClick={() => setDetail(null)}>关闭</Button>,
        ]}
      >
        <TextArea
          value={detailText}
          readOnly
          autoSize={{ minRows: 16, maxRows: 24 }}
          style={{ fontFamily: 'monospace', fontSize: 12 }}
        />
      </Modal>
    </Card>
  )
}
