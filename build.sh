#!/bin/bash

# 多架构 Docker 镜像构建脚本
# 
# 使用方法:
#   ./build.sh <仓库名>                   # 指定仓库，使用默认标签
#   ./build.sh <仓库名> <标签>            # 指定仓库和标签
#
# 示例:
#   ./build.sh dockerhub-user/alpine
#   ./build.sh dockerhub-user/alpine 3.22.1
#   ./build.sh registry.example.com/alpine latest
#

set -e

# 默认配置
DEFAULT_TAG="3.22.1"

# 检查帮助参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ -z "$1" ]; then
    echo "多架构 Docker 镜像构建脚本"
    echo ""
    echo "使用方法:"
    echo "  $0 <仓库名>                   # 指定仓库，使用默认标签 ($DEFAULT_TAG)"
    echo "  $0 <仓库名> <标签>            # 指定仓库和标签"
    echo ""
    echo "示例:"
    echo "  $0 myuser/alpine"
    echo "  $0 myuser/alpine 3.22.1"
    echo "  $0 registry.example.com/alpine latest"
    echo ""
    echo "支持的架构:"
    echo "  linux/amd64, linux/arm64, linux/arm/v6, linux/arm/v7"
    echo "  linux/ppc64le, linux/s390x, linux/riscv64, linux/loong64, linux/386"
    exit 0
fi

# 使用命令行参数
REPO="$1"
TAG="${2:-$DEFAULT_TAG}"
IMAGE="$REPO:$TAG"

# 显示构建信息
echo "构建多架构镜像: $IMAGE"
echo "镜像仓库: $REPO"
echo "镜像标签: $TAG"
echo "===================="

ARCHS=(
  "x86_64:linux/amd64:./x86_64"
  "aarch64:linux/arm64:./aarch64"
  "armhf:linux/arm/v6:./armhf"
  "armv7:linux/arm/v7:./armv7"
  "ppc64le:linux/ppc64le:./ppc64le"
  "s390x:linux/s390x:./s390x"
  "riscv64:linux/riscv64:./riscv64"
  "loongarch64:linux/loong64:./loongarch64"
  "x86:linux/386:./x86"
)

DIGESTS=()

for item in "${ARCHS[@]}"; do
  IFS=":" read -r name platform dir <<< "$item"
  echo "Building $platform from $dir ..."
  out=$(docker buildx build --platform "$platform" -t "$IMAGE" "$dir" --push 2>&1)
  
  # 尝试多种方式获取 digest
  digest=$(echo "$out" | grep -oE 'sha256:[a-f0-9]{32,}' | tail -1)
  if [ -z "$digest" ]; then
    # 尝试从 pushing manifest 行获取
    digest=$(echo "$out" | grep "pushing manifest" | grep -oE 'sha256:[a-f0-9]{32,}' | tail -1)
  fi
  
  if [ -n "$digest" ]; then
    echo "$platform digest: $digest"
    DIGESTS+=("$IMAGE@$digest")
  else
    echo "$platform build/push失败，未获取到digest，跳过。"
    echo "输出日志："
    echo "$out"
  fi
done

echo "Merging manifests ..."
docker buildx imagetools create -t "$IMAGE" "${DIGESTS[@]}"

echo "Done! 多架构镜像已合并: $IMAGE"
echo ""
echo "使用方法："
echo "  docker pull $IMAGE"
echo "  docker run --rm $IMAGE uname -m"
echo "  docker run --rm --platform linux/arm64 $IMAGE uname -m"