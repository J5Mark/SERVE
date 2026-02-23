#!/bin/bash

SERVICE=$1

echo "=== building ==="
docker compose build $SERVICE

echo "=== redeploy: $SERVICE ==="

IMAGE="neonstrings/serve-${SERVICE}:latest" # Think of where to store it

docker tag "cro/serve-${SERVICE}:latest" "$IMAGE"
docker push "$IMAGE"
echo "=== image pushed: $IMAGE ==="

# Deploy in k3s cluster
ssh cro-serv@192.168.1.6 "
  echo '=== deleting old deployment ==='
  kubectl delete deployment ${SERVICE} -n serve --ignore-not-found=true || true

  echo '=== applying new ==='
  kubectl apply -f ~/servetm/${SERVICE}.yaml -n serve

  echo '=== waiting ==='
  kubectl rollout status deployment/${SERVICE} --timeout=60s -n serve
"

echo "$SERVICE DEPLOYED FRESH"
