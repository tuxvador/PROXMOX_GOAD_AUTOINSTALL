#!/bin/bash

# Define the path for the configuration and certificate files
CONFIG_FILE="files/openvpn/openssl.cnf"
CA_KEY_FILE="files/openvpn/certs/ca-key.pem"
CA_CERT_FILE="files/openvpn/certs/ca-cert.pem"
GOAD_KEY_FILE="files/openvpn/certs/goad-key.pem"
GOAD_CSR_FILE="files/openvpn/certs/goad-csr.pem"
GOAD_CERT_FILE="files/openvpn/certs/goad-cert.pem"
USER_KEY_FILE="files/openvpn/certs/user-key.pem"
USER_CSR_FILE="files/openvpn/certs/user-csr.pem"
USER_CERT_FILE="files/openvpn/certs/user-cert.pem"

# Create the OpenSSL configuration file
cat > $CONFIG_FILE << EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[ req_distinguished_name ]
C  = US
ST = New York
L  = New York
O  = $(grep CERT_ORG goad.conf | cut -d '=' -f2)
OU = $(grep CERT_OU goad.conf | cut -d '=' -f2)
CN = $(grep CERT_CN=PENTEST goad.conf | cut -d '=' -f2)
emailAddress = admin@goad.lab

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = vpn.goad.lab
DNS.2 = www.vpn.goad.lab

[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints       = critical, CA:true
keyUsage               = critical, cRLSign, keyCertSign

[ v3_req ]
basicConstraints       = CA:FALSE
keyUsage               = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth, clientAuth
subjectAltName         = @alt_names
EOF

# Generate a 2048-bit private key for the CA
openssl genpkey -algorithm RSA -out $CA_KEY_FILE -pkeyopt rsa_keygen_bits:2048

# Generate the CSR for the CA
openssl req -new -key $CA_KEY_FILE -out ${CA_CERT_FILE%.pem}.csr -config $CONFIG_FILE -extensions v3_ca

# Generate the CA certificate
openssl x509 -req -days 3650 -in ${CA_CERT_FILE%.pem}.csr -signkey $CA_KEY_FILE -out $CA_CERT_FILE -extensions v3_ca -extfile $CONFIG_FILE

# Generate a private key for the server
openssl genpkey -algorithm RSA -out $GOAD_KEY_FILE -pkeyopt rsa_keygen_bits:2048

# Create a certificate signing request (CSR) for the server
openssl req -new -key $GOAD_KEY_FILE -out $GOAD_CSR_FILE -config $CONFIG_FILE -extensions req_ext

# Generate the server certificate using the CA
openssl x509 -req -in $GOAD_CSR_FILE -CA $CA_CERT_FILE -CAkey $CA_KEY_FILE -CAcreateserial -out $GOAD_CERT_FILE -days 365 -sha256 -extfile $CONFIG_FILE -extensions v3_req

# Generate a private key for the user
openssl genpkey -algorithm RSA -out $USER_KEY_FILE -pkeyopt rsa_keygen_bits:2048

# Create a certificate signing request (CSR) for the user
openssl req -new -key $USER_KEY_FILE -out $USER_CSR_FILE -config $CONFIG_FILE -extensions req_ext

# Generate the user certificate using the CA
openssl x509 -req -in $USER_CSR_FILE -CA $CA_CERT_FILE -CAkey $CA_KEY_FILE -CAcreateserial -out $USER_CERT_FILE -days 365 -sha256 -extfile $CONFIG_FILE -extensions v3_req

# Extract the CA certificate and key without the headers
sed -n '/^-----BEGIN CERTIFICATE-----$/,/^-----END CERTIFICATE-----$/p' $CA_CERT_FILE | tr -d '\n' > files/openvpn/certs/cacert.pem
sed -n '/^-----BEGIN PRIVATE KEY-----$/,/^-----END PRIVATE KEY-----$/p' $CA_KEY_FILE | tr -d '\n' > files/openvpn/certs/cakey.pem

echo "CA key and certificate have been generated:"
echo "Private Key: $CA_KEY_FILE"
echo "Certificate: $CA_CERT_FILE"
