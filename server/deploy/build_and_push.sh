#!/usr/bin/env bash
# 构建镜像并推送到阿里云容器镜像服务（ACR）。
# 在本机（装了 docker 且能访问外网）执行；推送前需先 docker login 到 ACR。
#
# 用法：
#   ACR_REGISTRY=registry.cn-hangzhou.aliyuncs.com \
#   ACR_NAMESPACE=your-namespace \
#   IMAGE_TAG=v1.0.0 \
#   ./deploy/build_and_push.sh
#
# 首次推送前登录（个人版 ACR，用户名/密码在 ACR 控制台“访问凭证”里设置）：
#   docker login --username=<你的阿里云账号> registry.cn-hangzhou.aliyuncs.com
set -euo pipefail

# 镜像仓库地址，默认杭州地域。换地域时同步改这里。
ACR_REGISTRY="${ACR_REGISTRY:-registry.cn-hangzhou.aliyuncs.com}"
ACR_NAMESPACE="${ACR_NAMESPACE:?请设置 ACR_NAMESPACE（ACR 命名空间）}"
IMAGE_NAME="${IMAGE_NAME:-socialstory-server}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"

FULL_IMAGE="${ACR_REGISTRY}/${ACR_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"

# 脚本所在目录的上级 = 项目根（Dockerfile 所在处）。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ">> 构建 ${FULL_IMAGE}"
# 显式指定 linux/amd64：ECS 通常是 x86_64，避免在 Apple Silicon 上构出 arm64 镜像。
docker build --platform linux/amd64 \
  -t "${FULL_IMAGE}" \
  "${ROOT_DIR}"

echo ">> 推送 ${FULL_IMAGE}"
docker push "${FULL_IMAGE}"

echo ">> 完成。在 ECS 上用这个镜像地址部署："
echo "   ${FULL_IMAGE}"
