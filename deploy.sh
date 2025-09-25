#!/usr/bin/env bash
set -euo pipefail

# === Config ===
AWS_REGION="eu-west-1"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REPO="react-web"
IMAGE_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE="${IMAGE_REGISTRY}/${ECR_REPO}"
ECS_CLUSTER="react-web-cluster"
ECS_SERVICE="react-web-svc"

# Valfritt: byggkatalogen där Dockerfile finns (ändra vid behov)
BUILD_DIR="app"

# === Pre-flight checks ===
command -v aws >/dev/null || { echo "aws CLI saknas"; exit 1; }
command -v docker >/dev/null || { echo "Docker saknas"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker daemon ej igång"; exit 1; }

# Kolla att Dockerfile finns
if [ ! -f "${BUILD_DIR}/Dockerfile" ]; then
  echo "Hittar ingen Dockerfile i ${BUILD_DIR}/"
  exit 1
fi

echo "ℹ️  Konto: ${ACCOUNT_ID}, Region: ${AWS_REGION}"
echo "ℹ️  Image: ${IMAGE}:latest"
echo "ℹ️  Cluster/Service: ${ECS_CLUSTER}/${ECS_SERVICE}"
echo

# === Login till ECR ===
echo "🔐 Loggar in till ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${IMAGE_REGISTRY}"

# === Build (linux/amd64 för Fargate X86_64) ===
SHORT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo manual)"
TAG="${SHORT_SHA}"

echo "🏗️  Bygger image (linux/amd64)..."
docker buildx build --platform linux/amd64 -t "${IMAGE}:latest" -t "${IMAGE}:${TAG}" "${BUILD_DIR}"

# === Push ===
echo "🚀 Pushar ${IMAGE}:${TAG} och :latest..."
docker push "${IMAGE}:${TAG}"
docker push "${IMAGE}:latest"

# === Force new deployment på ECS ===
echo "♻️  Force new deployment på ECS service..."
aws ecs update-service \
  --cluster "${ECS_CLUSTER}" \
  --service "${ECS_SERVICE}" \
  --force-new-deployment \
  --region "${AWS_REGION}" >/dev/null

echo "Klart! Ny image rullas ut. Kolla ALB-DNS i browsern inom ~1–2 min."