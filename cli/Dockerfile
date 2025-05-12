# Use the base Fabric tools image
FROM hyperledger/fabric-tools:2.5.8

# Install Go 1.22.3
ARG GO_VERSION=1.22.3
ARG ARCH=arm64 # Assuming arm64 based on your previous logs. Change to amd64 if needed.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        'amd64') GO_ARCH='amd64' ; GO_SHA256='24a74853f81f2d3922c0039c45343b50032868e03930c84d2f8af5e06529e597' ;; \
        'arm64') GO_ARCH='arm64' ; GO_SHA256='101d65a0762782d026768c2f042e62a89438b722370816829141885e3123c7c7' ;; \
        *) echo >&2 "unsupported architecture: $arch"; exit 1 ;; \
    esac; \
    \
    wget -O go.tgz "https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"; \
    echo "${GO_SHA256} go.tgz" | sha256sum -c -; \
    tar -C /usr/local -xzf go.tgz; \
    rm go.tgz; \
    \
    export PATH="/usr/local/go/bin:$PATH"; \
    go version

# Set GOPATH and update PATH
ENV GOPATH=/opt/gopath
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Set the working directory
WORKDIR /opt/gopath/src/github.com/hyperledger/fabric/peer