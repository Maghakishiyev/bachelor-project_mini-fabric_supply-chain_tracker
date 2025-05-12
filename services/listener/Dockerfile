FROM golang:1.24 AS builder
WORKDIR /listener

# Copy only Go modules files first and vendor dependencies for an offline build
COPY go.mod go.sum ./
RUN go mod tidy && go mod vendor

# Now copy the rest of the source code
COPY . .

# Build the listener binary using the vendor directory
RUN go build -mod=vendor -o listener
RUN ls -la

FROM alpine:3.19
RUN apk add --no-cache ca-certificates libc6-compat
WORKDIR /app
COPY --from=builder /listener/listener .
RUN chmod +x /app/listener
RUN ls -la

# Default environment variables...
ENV MSP_ID=ManufacturerMSP
ENV CERT_PATH=/crypto/signcerts/Admin@manufacturer.example.com-cert.pem
ENV KEY_PATH=/crypto/keystore/priv_sk
ENV PEER_ENDPOINT=peer0.manufacturer.example.com:7051
ENV TLS_CA=/crypto/ca.pem
ENV WS_PORT=3001

EXPOSE 3001
ENTRYPOINT ["/app/listener"]