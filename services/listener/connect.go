package main

import (
	"crypto/x509"
	"io/ioutil"
	"log"

	gateway "github.com/hyperledger/fabric-gateway/pkg/client"
)

func newGateway(mspID, certPath, keyPath, peerEndpoint string, tlsCACert []byte) *gateway.Gateway {
	idCert, err := ioutil.ReadFile(certPath)
	if err != nil {
		log.Fatalf("failed to read identity cert: %v", err)
	}
	id, err := gateway.NewX509Identity(mspID, idCert)
	if err != nil {
		log.Fatalf("failed to create identity: %v", err)
	}

	keyPem, err := ioutil.ReadFile(keyPath)
	if err != nil {
		log.Fatalf("failed to read private key: %v", err)
	}
	key, err := gateway.NewPrivateKeyFromPEM(keyPem)
	if err != nil {
		log.Fatalf("failed to create private key: %v", err)
	}

	certPool := x509.NewCertPool()
	if !certPool.AppendCertsFromPEM(tlsCACert) {
		log.Fatalf("failed to append CA cert to cert pool")
	}

	conn, err := gateway.Connect(
		peerEndpoint,
		gateway.WithTLSCertPool(certPool),
		gateway.WithIdentity(id),
		gateway.WithSign(key),
	)
	if err != nil {
		log.Fatalf("failed to connect to gateway: %v", err)
	}

	return conn
}