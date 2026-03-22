#!/bin/sh

set -e

echo "Migrating with Alembic"

alembic upgrade head

echo "Migrated successfully"

uvicorn main:app --host 0.0.0.0 --port 1000
