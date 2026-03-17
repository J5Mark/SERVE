FROM python:3.13-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

WORKDIR /app

COPY pyproject.toml uv.lock* ./
RUN uv pip install --system -r pyproject.toml

COPY . /app

ENV PYTHONBUFFERED=1
EXPOSE 3000
CMD ["python", "-m", "main"]
