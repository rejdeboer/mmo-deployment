#!/bin/bash

VAULT_ADDR=$1
KEY_FILE=$2

if [ -z "$VAULT_ADDR" ] || [ -z "$KEY_FILE" ]; then
    echo "❌ Usage: $0 <VAULT_ADDR> <KEY_OUTPUT_FILE>"
    exit 1
fi

echo "🔍 Checking Vault at $VAULT_ADDR..."

MAX_RETRIES=10
COUNT=0
while ! curl -s --output /dev/null --connect-timeout 2 "$VAULT_ADDR/v1/sys/health"; do
    echo "⏳ Waiting for Vault API... ($COUNT/$MAX_RETRIES)"
    sleep 3
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Timeout waiting for Vault."
        exit 1
    fi
done

IS_INIT=$(curl -s "$VAULT_ADDR/v1/sys/init" | jq -r .initialized)

if [ "$IS_INIT" == "true" ]; then
    echo "✅ Vault is already initialized."
    if [ ! -f "$KEY_FILE" ]; then
        echo "⚠️  WARNING: Vault is initialized but local '$KEY_FILE' is missing!"
        echo "    You will need to recover your keys manually."
    fi
    exit 0
fi

echo "⚙️  Initializing Vault (1 key share)..."
vault operator init \
    -address="$VAULT_ADDR" \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > "$KEY_FILE"

echo "✅ Success! Keys saved to $KEY_FILE"
