import { useEffect, useState } from 'react'
import { Row, Col, Card, Statistic, Spin } from 'antd'
import { getDashboard, type DashboardData } from '../api'

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getDashboard()
      .then(setData)
      .catch(() => undefined)
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <Spin style={{ display: 'block', marginTop: 80 }} />

  const cards: { title: string; value: number }[] = [
    { title: '总用户数', value: data?.total_users ?? 0 },
    { title: '今日新增用户', value: data?.new_users_today ?? 0 },
    { title: '活跃订阅', value: data?.active_subscriptions ?? 0 },
    { title: '今日生成故事', value: data?.stories_generated_today ?? 0 },
  ]

  return (
    <Row gutter={[16, 16]}>
      {cards.map((c) => (
        <Col xs={24} sm={12} md={6} key={c.title}>
          <Card>
            <Statistic title={c.title} value={c.value} />
          </Card>
        </Col>
      ))}
    </Row>
  )
}
