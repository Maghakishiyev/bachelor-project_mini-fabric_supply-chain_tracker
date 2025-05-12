FROM golang:1.24 AS builder
WORKDIR /listener
COPY . .
RUN go mod tidy && go build -o listener
RUN ls -la

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=builder /listener/listener .
RUN ls -la

# Default environment variables (can be overridden at runtime)
ENV MSP_ID=ManufacturerMSP
ENV CERT_PATH=/crypto/signcerts/Admin@manufacturer.example.com-cert.pem
ENV KEY_PATH=/crypto/keystore/priv_sk
ENV PEER_ENDPOINT=peer0.manufacturer.example.com:7051
ENV TLS_CA=/crypto/ca.pem
ENV WS_PORT=3001

EXPOSE 3001
CMD ["/app/listener"]