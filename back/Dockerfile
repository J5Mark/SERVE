FROM python:3.13-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

WORKDIR /app

COPY pyproject.toml uv.lock* ./
RUN uv pip install --system .

COPY . /app
COPY alembic.ini /app/
RUN chmod +x /app/entrypoint.sh

ENV PYTHONBUFFERED=1
EXPOSE 1000
ENTRYPOINT ["/app/entrypoint.sh"]
