#!/bin/bash
# Generate a WireGuard client and display QR code

FOLDER="wireguard-client"
CLIENT_ADDRESS="10.0.0.2/24"
DNS="10.0.0.1"
ALLOWED_IPS="0.0.0.0/0, ::/0"
SERVER_ENDPOINT="CHANGE_ME:51820"
SERVER_PUBLIC_KEY="GET_ME_FROM_SERVER"

mkdir $FOLDER
PRIVATE_KEY=$(wg genkey)

cat <<EOT > ./$FOLDER/client.conf
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $CLIENT_ADDRESS
DNS = $DNS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = $ALLOWED_IPS
Endpoint = $SERVER_ENDPOINT
EOT

PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)
echo "$PUBLIC_KEY" > ./$FOLDER/publickey

qrencode -t ansiutf8 < ./$FOLDER/client.conf
echo "Add public key to server peers: $PUBLIC_KEY"
