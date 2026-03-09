FROM oven/bun:1-alpine AS base

WORKDIR /app

FROM base AS deps

COPY package.json bun.lockb* ./

RUN bun install --frozen-lockfile

# FROM deps AS migrations

# COPY drizzle.config.ts ./
# COPY src/db/schema ./src/db/schema

# RUN bunx drizzle-kit generate

FROM base AS production

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package.json ./package.json

COPY . .


EXPOSE 3000

CMD ["bun", "run", "src/index.ts"]


