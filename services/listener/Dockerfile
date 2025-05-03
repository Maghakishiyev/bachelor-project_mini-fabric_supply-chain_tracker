FROM golang:1.24 AS builder
WORKDIR /listener
COPY . .
RUN go mod tidy && go build -o listener

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /listener/listener .

# Default environment variables (can be overridden at runtime)
ENV MSP_ID=ManufacturerMSP
ENV CERT_PATH=/crypto/admin-cert.pem
ENV KEY_PATH=/crypto/admin-key.pem
ENV PEER_ENDPOINT=grpcs://peer0.manufacturer.example.com:7051
ENV TLS_CA=/crypto/ca.pem
ENV WS_PORT=3001

EXPOSE 3001
CMD ["./listener"]