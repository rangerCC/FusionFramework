#!/usr/bin/env bash
# 在阿里云 ECS 上拉取最新镜像并滚动替换正在运行的容器。
# 前置：ECS 已装 docker、已 docker login 到 ACR、已准备好 /etc/socialstory/.env.prod
# 和 /etc/socialstory/AuthKey.p8（权限 600）。
#
# 用法（在 ECS 上执行）：
#   IMAGE=registry.cn-hangzhou.aliyuncs.com/your-ns/socialstory-server:v1.0.0 \
#   ./deploy.sh
set -euo pipefail

IMAGE="${IMAGE:?请设置 IMAGE（完整镜像地址含 tag）}"
CONTAINER_NAME="${CONTAINER_NAME:-socialstory-server}"
HOST_PORT="${HOST_PORT:-8080}"        # SLB/ALB 后端转发到这个端口
CONFIG_DIR="${CONFIG_DIR:-/etc/socialstory}"
ENV_FILE="${CONFIG_DIR}/.env.prod"

# 配置与密钥必须就位，否则容器起来也是错的。
[ -f "${ENV_FILE}" ] || { echo "缺少 ${ENV_FILE}"; exit 1; }

echo ">> 拉取镜像 ${IMAGE}"
docker pull "${IMAGE}"

echo ">> 停止并移除旧容器（若存在）"
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

echo ">> 启动新容器"
# --env-file 注入所有生产配置；挂载 CONFIG_DIR 只读，让容器读到 AuthKey.p8。
# --restart=always 让容器随 docker 守护进程自启。
docker run -d \
  --name "${CONTAINER_NAME}" \
  --env-file "${ENV_FILE}" \
  -p "${HOST_PORT}:8080" \
  -v "${CONFIG_DIR}:${CONFIG_DIR}:ro" \
  --restart=always \
  --health-cmd='wget -qO- http://127.0.0.1:8080/healthz || exit 1' \
  --health-interval=30s --health-timeout=3s --health-retries=3 \
  "${IMAGE}"

echo ">> 等待健康检查..."
sleep 5
docker ps --filter "name=${CONTAINER_NAME}"
echo ">> 最近日志："
docker logs --tail 30 "${CONTAINER_NAME}"

echo ">> 本机健康检查："
curl -fsS "http://127.0.0.1:${HOST_PORT}/healthz" && echo " OK" || echo " 健康检查失败，查看上面的日志"
