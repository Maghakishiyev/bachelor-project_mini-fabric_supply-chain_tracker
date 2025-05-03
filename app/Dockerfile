FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json yarn.lock* ./
RUN yarn install --frozen-lockfile

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN yarn build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

# Default environment variables
ENV NEXT_PUBLIC_WS_URL=ws://localhost:3001/ws
ENV MSP_ID=RetailerMSP
ENV PEER_ENDPOINT=grpcs://peer0.retailer.example.com:10051
ENV CRYPTO_PATH=/crypto

EXPOSE 3000
CMD ["node", "server.js"]