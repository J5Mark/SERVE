#!/bin/bash

# Usage: ./migrate_backend.sh "migration message"

set -e

echo "Starting database port forward..."
ssh -L 5433:localhost:5432 cro-serv@192.168.1.6 \
  -t "kubectl port-forward svc/postgres-service 5432:5432 -n serve" &
SSH_PID=$!

sleep 15

cleanup() {
  echo "Cleaning up..."
  kill $SSH_PID 2>/dev/null || true
}
trap cleanup EXIT

echo "Done!"
