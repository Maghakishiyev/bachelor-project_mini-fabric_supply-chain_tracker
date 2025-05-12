package main

import (
	"crypto/tls"
	"crypto/x509"
	"io/ioutil"
	"log"

	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-gateway/pkg/identity"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

func newGateway(mspID, certPath, keyPath, peerEndpoint string, tlsCACert []byte) *client.Gateway {
	// Load client identity certificate and private key
	idCert, err := ioutil.ReadFile(certPath)
	if err != nil {
		log.Fatalf("failed to read identity cert: %v", err)
	}

	keyPem, err := ioutil.ReadFile(keyPath)
	if err != nil {
		log.Fatalf("failed to read private key: %v", err)
	}

	// Parse X.509 certificate
	cert, err := identity.CertificateFromPEM(idCert)
	if err != nil {
		log.Fatalf("failed to parse certificate: %v", err)
	}

	// Create identity from certificate
	id, err := identity.NewX509Identity(mspID, cert)
	if err != nil {
		log.Fatalf("failed to create identity: %v", err)
	}

	// Create a signing object from the private key
	privateKey, err := identity.PrivateKeyFromPEM(keyPem)
	if err != nil {
		log.Fatalf("failed to parse private key: %v", err)
	}
	
	sign, err := identity.NewPrivateKeySign(privateKey)
	if err != nil {
		log.Fatalf("failed to create private key sign: %v", err)
	}

	// Create a TLS configuration with the CA certificate
	certPool := x509.NewCertPool()
	if !certPool.AppendCertsFromPEM(tlsCACert) {
		log.Fatalf("failed to append CA cert to cert pool")
	}

	tlsConfig := &tls.Config{
		RootCAs: certPool,
	}
	tlsCredentials := credentials.NewTLS(tlsConfig)

	// Connect to the peer using gRPC
	grpcConn, err := grpc.Dial(peerEndpoint, grpc.WithTransportCredentials(tlsCredentials))
	if err != nil {
		log.Fatalf("Failed to connect to peer: %v", err)
	}

	// Create a gateway connection
	gw, err := client.Connect(id, client.WithSign(sign), client.WithClientConnection(grpcConn))
	if err != nil {
		grpcConn.Close()
		log.Fatalf("failed to connect to gateway: %v", err)
	}

	return gw
}